"""
Phase lifecycle service.

Right now the only thing this module owns is closing a phase's material
plans when the phase itself transitions to `completed`. Policy A from the
design discussion:

    - Every active PhaseMaterialPlan row on the phase is marked `closed`.
    - `leftover_quantity` captures (planned - used) at close time so we
      can later render "3 plywood returned to inventory" without having
      to recompute history.
    - Inventory (`InventoryItem.quantity`) is NOT touched — a plan is a
      reservation, not a physical transfer, so leftovers are already in
      stock and are implicitly freed for re-assignment.
    - Idempotent: calling this on a phase that is already closed (or has
      no active plans) is a no-op.

The supervisor serializer excludes `closed` plans from its assigned/
remaining math, so closing a phase naturally drops the material counts
on the supervisor's inventory and phase views to zero.
"""

from django.db import transaction
from django.db.models import Sum
from django.utils import timezone

from app import models as app_models


@transaction.atomic
def close_phase_material_plans(*, phase):
    """
    Close every active `PhaseMaterialPlan` on `phase`.

    Returns a list of summary dicts so the caller can present a
    "leftovers" dialog:

        [
            {
                'plan_id': 1,
                'inventory_item_id': 64,
                'inventory_item_name': 'Plywood',
                'unit_of_measure': 'sheet',
                'assigned': 10,
                'used':      7,
                'leftover':  3,
            },
            ...
        ]
    """
    active_plans = (
        app_models.PhaseMaterialPlan.objects
        .select_for_update()
        .filter(phase=phase, status=app_models.PhaseMaterialPlan.STATUS_ACTIVE)
        .select_related('inventory_item')
    )

    if not active_plans.exists():
        return []

    # Sum used quantity per (phase, inventory_item) up front so we don't
    # fire N queries inside the loop.
    used_rows = (
        app_models.InventoryUsage.objects
        .filter(
            phase=phase,
            inventory_item__in=active_plans.values_list('inventory_item_id', flat=True),
        )
        .values('inventory_item_id')
        .annotate(total_used=Sum('quantity_used'))
    )
    used_by_item = {r['inventory_item_id']: int(r['total_used'] or 0) for r in used_rows}

    now = timezone.now()
    summaries = []
    for plan in active_plans:
        planned = int(plan.planned_quantity or 0)
        used = used_by_item.get(plan.inventory_item_id, 0)
        leftover = max(0, planned - used)

        plan.status = app_models.PhaseMaterialPlan.STATUS_CLOSED
        plan.leftover_quantity = leftover
        plan.closed_at = now
        plan.save(update_fields=['status', 'leftover_quantity', 'closed_at', 'updated_at'])

        summaries.append({
            'plan_id': plan.plan_id,
            'inventory_item_id': plan.inventory_item_id,
            'inventory_item_name': plan.inventory_item.name,
            'unit_of_measure': plan.inventory_item.unit_of_measure or 'pcs',
            'assigned': planned,
            'used': used,
            'leftover': leftover,
        })

    return summaries
