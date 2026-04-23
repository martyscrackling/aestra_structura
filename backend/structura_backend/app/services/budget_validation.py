"""
Pure validation helpers for budget/allocation rules.

These are called from:
    - serializers (so generic CRUD hits the rules)
    - explicit detail actions (set-budget / allocate-budget)
    - delete guards

Each function returns an error message (str) if the rule is violated,
or None if the input is valid. Callers convert this into whatever
exception their layer expects (DRF ValidationError, MaterialUsageError,
or a 400 Response).
"""

from decimal import Decimal, InvalidOperation
from django.db.models import Sum


def to_decimal(value) -> Decimal:
    if value is None or value == "":
        return Decimal("0")
    if isinstance(value, Decimal):
        return value
    try:
        return Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        return Decimal("0")


def check_non_negative(value, field_name: str):
    v = to_decimal(value)
    if v < 0:
        return f"{field_name} cannot be negative."
    return None


def check_project_budget(project, new_budget) -> str | None:
    """
    A project's budget must be >= the sum of its phases' allocated budgets.
    """
    new_budget = to_decimal(new_budget)
    if new_budget < 0:
        return "budget cannot be negative."
    if project is None or project.pk is None:
        return None  # creating a brand-new project; no phases yet
    allocated = project.phases.aggregate(s=Sum("allocated_budget"))["s"] or Decimal("0")
    if new_budget < allocated:
        return (
            f"New budget ({new_budget}) is less than the sum of phase "
            f"allocations ({allocated}). Reduce phase allocations first."
        )
    return None


def check_phase_allocation(phase, new_alloc, project=None) -> str | None:
    """
    A phase's allocated_budget must be:
      - non-negative
      - >= its used_budget (can't allocate less than already spent)
      - sum of all phase allocations in the project must fit in the
        project's total budget.
    `project` is required when `phase` has no pk yet (creation).
    """
    new_alloc = to_decimal(new_alloc)
    if new_alloc < 0:
        return "allocated_budget cannot be negative."

    if phase is not None and phase.pk is not None:
        used = to_decimal(phase.used_budget)
        if new_alloc < used:
            return (
                f"Allocation ({new_alloc}) is less than what has already "
                f"been used on this phase ({used})."
            )
        project = phase.project

    if project is None:
        return None

    project_budget = to_decimal(project.budget)
    other_alloc_qs = project.phases.all()
    if phase is not None and phase.pk is not None:
        other_alloc_qs = other_alloc_qs.exclude(pk=phase.pk)
    other_alloc = other_alloc_qs.aggregate(s=Sum("allocated_budget"))["s"] or Decimal("0")

    if (other_alloc + new_alloc) > project_budget:
        return (
            f"Phase allocations would exceed the project budget. "
            f"Project budget: {project_budget}, other phases: {other_alloc}, "
            f"this phase: {new_alloc}."
        )
    return None


def check_phase_is_deletable(phase) -> str | None:
    """
    Blocks deletion of a phase that already carries budget history.
    """
    used = to_decimal(phase.used_budget)
    if used > 0:
        return (
            f"Cannot delete phase '{phase.phase_name}': it has "
            f"{used} of used budget. Reverse its usages first."
        )
    if phase.usages.exclude(quantity_used=0).exists():
        return (
            f"Cannot delete phase '{phase.phase_name}': it has recorded "
            f"material usages. Reverse them first."
        )
    return None


def check_inventory_item_is_deletable(item) -> str | None:
    """
    Blocks deletion of an inventory item that has been consumed via the
    phase/budget flow or planned for a phase.
    """
    if item.usages.exclude(quantity_used=0).exists():
        return (
            f"Cannot delete item '{item.name}': it has recorded material "
            f"usages charged to phase budgets."
        )
    if item.phase_plans.exists():
        return (
            f"Cannot delete item '{item.name}': it is referenced by one or "
            f"more phase material plans."
        )
    return None
