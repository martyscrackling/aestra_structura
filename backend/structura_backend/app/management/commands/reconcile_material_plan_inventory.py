from django.core.management.base import BaseCommand
from django.db import transaction

from app.models import InventoryItem, PhaseMaterialPlan


class Command(BaseCommand):
    help = (
        "Reserve inventory for legacy PhaseMaterialPlan rows that were created "
        "before inventory auto-deduction was introduced."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--phase-id",
            type=int,
            help="Only reconcile plans under this phase id.",
        )
        parser.add_argument(
            "--plan-id",
            type=int,
            help="Only reconcile a single plan id.",
        )
        parser.add_argument(
            "--apply",
            action="store_true",
            help="Apply changes. Without this flag, the command runs in dry-run mode.",
        )

    def handle(self, *args, **options):
        phase_id = options.get("phase_id")
        plan_id = options.get("plan_id")
        apply_changes = bool(options.get("apply"))

        qs = PhaseMaterialPlan.objects.select_related("inventory_item", "phase").filter(
            inventory_reserved=False
        )
        if phase_id:
            qs = qs.filter(phase_id=phase_id)
        if plan_id:
            qs = qs.filter(plan_id=plan_id)

        plans = list(qs.order_by("plan_id"))
        if not plans:
            self.stdout.write(self.style.SUCCESS("No unreserved material plans found."))
            return

        self.stdout.write(
            f"{'Applying' if apply_changes else 'Dry-run for'} {len(plans)} plan(s)."
        )

        success_count = 0
        skipped_count = 0

        for plan in plans:
            needed = int(plan.planned_quantity)
            item = plan.inventory_item
            available = int(item.quantity)
            detail = (
                f"plan_id={plan.plan_id} phase_id={plan.phase_id} "
                f"item_id={item.item_id} item={item.name!r} "
                f"needed={needed} available={available}"
            )

            if needed <= 0:
                skipped_count += 1
                self.stdout.write(self.style.WARNING(f"SKIP (zero quantity): {detail}"))
                continue

            if available < needed:
                skipped_count += 1
                self.stdout.write(self.style.WARNING(f"SKIP (insufficient stock): {detail}"))
                continue

            if not apply_changes:
                success_count += 1
                self.stdout.write(self.style.SUCCESS(f"WOULD RESERVE: {detail}"))
                continue

            with transaction.atomic():
                locked_plan = PhaseMaterialPlan.objects.select_for_update().get(
                    pk=plan.plan_id
                )
                if locked_plan.inventory_reserved:
                    skipped_count += 1
                    self.stdout.write(
                        self.style.WARNING(
                            f"SKIP (already reserved by another process): {detail}"
                        )
                    )
                    continue

                locked_item = InventoryItem.objects.select_for_update().get(
                    pk=locked_plan.inventory_item_id
                )
                locked_available = int(locked_item.quantity)
                locked_needed = int(locked_plan.planned_quantity)
                if locked_available < locked_needed:
                    skipped_count += 1
                    self.stdout.write(
                        self.style.WARNING(
                            "SKIP (insufficient stock after lock): "
                            f"plan_id={locked_plan.plan_id} "
                            f"item_id={locked_item.item_id} needed={locked_needed} "
                            f"available={locked_available}"
                        )
                    )
                    continue

                locked_item.quantity = locked_available - locked_needed
                locked_item.save(update_fields=["quantity", "updated_at"])

                locked_plan.inventory_reserved = True
                locked_plan.save(update_fields=["inventory_reserved", "updated_at"])
                success_count += 1
                self.stdout.write(
                    self.style.SUCCESS(
                        f"RESERVED: plan_id={locked_plan.plan_id} "
                        f"item_id={locked_item.item_id} qty={locked_needed}"
                    )
                )

        self.stdout.write(
            self.style.SUCCESS(
                f"Done. success={success_count} skipped={skipped_count} total={len(plans)}"
            )
        )
