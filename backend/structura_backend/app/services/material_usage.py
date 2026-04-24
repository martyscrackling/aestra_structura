"""
Material usage service — the single source of truth for deducting
materials from inventory and charging their cost against a phase's
budget (and, by extension, the project budget).

Rules enforced here (see project spec):
    1. Enough inventory must exist for the requested quantity.
    2. The resulting cost must fit inside the phase's allocated budget.
    3. The resulting cost must fit inside the project's remaining budget.
    4. Usage is recorded as an InventoryUsage row with a snapshot of the
       unit price at the time of use (so later price edits don't rewrite
       history).
    5. Warnings (non-blocking) are returned to the caller:
         - 50% of project budget consumed
         - phase has exceeded its allocated budget (shouldn't happen
           because of rule 2, but included defensively if this service
           is ever called with skip_phase_check=True).

Never mutate InventoryItem.quantity or Phase.used_budget from anywhere
else — always go through record_material_usage / reverse_material_usage.
"""

from decimal import Decimal

from django.db import transaction
from django.core.exceptions import ValidationError

from app.models import (
    InventoryItem,
    InventoryUsage,
    Phase,
    Supervisors,
    FieldWorker,
)


class MaterialUsageError(ValidationError):
    """Raised when a material usage request violates a business rule."""


# Warning codes (stable identifiers for the frontend to switch on)
WARN_PROJECT_50_PERCENT = "PROJECT_50_PERCENT"
WARN_PHASE_OVER_BUDGET = "PHASE_OVER_BUDGET"


def _as_decimal(value) -> Decimal:
    if value is None:
        return Decimal("0")
    if isinstance(value, Decimal):
        return value
    return Decimal(str(value))


@transaction.atomic
def record_material_usage(
    *,
    phase: Phase,
    inventory_item: InventoryItem,
    quantity: int,
    supervisor: Supervisors,
    field_worker: FieldWorker = None,
    notes: str = "",
    enforce_inventory: bool = True,
):
    """
    Consume `quantity` units of `inventory_item` for `phase`.

    Returns:
        tuple[InventoryUsage, list[dict]]:
            - the created usage row
            - list of warnings: [{"code": str, "message": str}, ...]

    Raises:
        MaterialUsageError on any rule violation. The transaction is
        rolled back so inventory/phase/project state stays consistent.
    """
    if quantity is None or int(quantity) <= 0:
        raise MaterialUsageError("Quantity must be a positive integer.")
    quantity = int(quantity)

    # Lock rows for the duration of this transaction to prevent two
    # concurrent supervisors from both "seeing" enough inventory and
    # over-consuming it.
    inventory_item = (
        InventoryItem.objects.select_for_update().get(pk=inventory_item.pk)
    )
    phase = Phase.objects.select_for_update().get(pk=phase.pk)
    project = phase.project

    # Rule 1 — inventory (optional in reservation-based flows)
    if enforce_inventory and inventory_item.quantity < quantity:
        raise MaterialUsageError(
            f"Not enough inventory: requested {quantity}, "
            f"available {inventory_item.quantity}."
        )

    unit_price = _as_decimal(inventory_item.price)
    cost = unit_price * quantity

    # Rule 2 — phase budget (hard block)
    allocated = _as_decimal(phase.allocated_budget)
    used = _as_decimal(phase.used_budget)
    if allocated > 0 and (used + cost) > allocated:
        raise MaterialUsageError(
            f"This usage would exceed the phase's allocated budget. "
            f"Allocated: {allocated}, already used: {used}, "
            f"this cost: {cost}."
        )

    # Rule 3 — project budget (hard block)
    project_budget = _as_decimal(project.budget)
    remaining = _as_decimal(project.remaining_budget)
    if cost > remaining:
        raise MaterialUsageError(
            f"This usage would exceed the project's remaining budget. "
            f"Remaining: {remaining}, this cost: {cost}."
        )

    # Apply deductions. In reservation-based planned flows the inventory stock
    # has already been reserved at planning time, so we should not deduct again.
    if enforce_inventory:
        inventory_item.quantity = inventory_item.quantity - quantity
        inventory_item.save(update_fields=["quantity", "updated_at"])

    phase.used_budget = used + cost
    phase.save(update_fields=["used_budget", "updated_at"])

    usage = InventoryUsage.objects.create(
        inventory_item=inventory_item,
        phase=phase,
        project=project,
        checked_out_by=supervisor,
        field_worker=field_worker,
        quantity_used=quantity,
        unit_price_at_use=unit_price,
        total_cost=cost,
        status="Checked Out",
        notes=notes or "",
    )

    warnings = _collect_warnings(project, phase)
    return usage, warnings


@transaction.atomic
def reverse_material_usage(*, usage: InventoryUsage):
    """
    Undo a previously recorded usage (e.g. supervisor entered a typo,
    or material was returned unused). Restores inventory quantity and
    subtracts the cost from the phase's used_budget.

    Only supports reversing usages that carry the new phase/cost fields
    (new flow). Old unit-based checkouts are handled by their existing
    return endpoint.
    """
    if usage.quantity_used <= 0 or not usage.phase_id:
        raise MaterialUsageError(
            "This usage record has no phase/quantity and cannot be "
            "reversed through the material-usage service."
        )

    item = InventoryItem.objects.select_for_update().get(pk=usage.inventory_item_id)
    phase = Phase.objects.select_for_update().get(pk=usage.phase_id)

    item.quantity = item.quantity + usage.quantity_used
    item.save(update_fields=["quantity", "updated_at"])

    phase.used_budget = max(
        Decimal("0"), _as_decimal(phase.used_budget) - _as_decimal(usage.total_cost)
    )
    phase.save(update_fields=["used_budget", "updated_at"])

    usage.status = "Returned"
    usage.save(update_fields=["status"])
    return usage


def _collect_warnings(project, phase):
    warnings = []

    budget = _as_decimal(project.budget)
    if budget > 0:
        consumed = budget - _as_decimal(project.remaining_budget)
        if consumed >= budget * Decimal("0.5"):
            warnings.append(
                {
                    "code": WARN_PROJECT_50_PERCENT,
                    "message": (
                        f"50% or more of the project budget has been consumed "
                        f"({consumed} of {budget})."
                    ),
                }
            )

    if phase.is_over_budget:
        warnings.append(
            {
                "code": WARN_PHASE_OVER_BUDGET,
                "message": (
                    f"Phase '{phase.phase_name}' is over its allocated budget."
                ),
            }
        )

    return warnings


def project_budget_summary(project):
    """
    Convenience read-model used by the summary endpoint in Step 3.
    Returns a plain dict so the view can JSON-serialize it directly.
    """
    phases = list(
        project.phases.values(
            "phase_id",
            "phase_name",
            "allocated_budget",
            "used_budget",
        )
    )
    for p in phases:
        p["remaining"] = _as_decimal(p["allocated_budget"]) - _as_decimal(
            p["used_budget"]
        )

    return {
        "project_id": project.project_id,
        "total_budget": _as_decimal(project.budget),
        "total_allocated": project.total_allocated_budget,
        "total_used": project.total_used_budget,
        "remaining_budget": project.remaining_budget,
        "phases": phases,
    }
