"""
Scripted end-to-end seed for the budget/inventory flow.

Walks through the exact scenario the system spec calls out so the whole
happy-path can be smoke-tested locally (and from the test suite):

    Project budget = 1,000,000
    Inventory: 1,000 cement @ 50, 500 rebar @ 200
    Phase 1 allocated 100,000, Phase 2 allocated 50,000
    Plan 100 cement + 20 rebar for Phase 1
    Supervisor records 50 cement and 10 rebar against Phase 1
    Print the resulting budget summary

Idempotent: if `--reset` is passed it wipes the demo project first.

Usage:
    python manage.py seed_budget_demo
    python manage.py seed_budget_demo --reset
    python manage.py seed_budget_demo --trigger-50-percent
"""

from decimal import Decimal
from datetime import date

from django.core.management.base import BaseCommand
from django.db import transaction

from app import models
from app.services.material_usage import (
    record_material_usage,
    project_budget_summary,
)


DEMO_PROJECT_NAME = "Budget Demo Project"
DEMO_PM_EMAIL = "pm-demo@aestra.local"
DEMO_SUPERVISOR_EMAIL = "supervisor-demo@aestra.local"


class Command(BaseCommand):
    help = "Seed and walk the budget/inventory flow end-to-end."

    def add_arguments(self, parser):
        parser.add_argument(
            "--reset",
            action="store_true",
            help="Delete the existing demo project before seeding.",
        )
        parser.add_argument(
            "--trigger-50-percent",
            action="store_true",
            help="Record an additional large usage so the 50% warning fires.",
        )

    @transaction.atomic
    def handle(self, *args, **opts):
        if opts.get("reset"):
            self._wipe_demo()

        pm = self._ensure_pm()
        supervisor = self._ensure_supervisor(pm)
        project = self._ensure_project(pm, supervisor)
        phase_1, phase_2 = self._ensure_phases(project)
        cement, rebar = self._ensure_inventory(pm, project)
        self._ensure_plans(phase_1, cement, rebar)

        self._record_usages(
            phase=phase_1,
            supervisor=supervisor,
            cement=cement,
            rebar=rebar,
            trigger_50=opts.get("trigger_50_percent", False),
        )

        self._print_summary(project)

    # ---- steps -----------------------------------------------------------

    def _wipe_demo(self):
        qs = models.Project.objects.filter(project_name=DEMO_PROJECT_NAME)
        for project in qs:
            models.InventoryUsage.objects.filter(project=project).delete()
            models.PhaseMaterialPlan.objects.filter(
                phase__project=project
            ).delete()
            project.phases.all().delete()
            models.InventoryItem.objects.filter(project=project).delete()
            project.delete()
        self.stdout.write("Demo project wiped.")

    def _ensure_pm(self):
        pm, _ = models.User.objects.get_or_create(
            email=DEMO_PM_EMAIL,
            defaults={
                "password_hash": "demo",
                "first_name": "Demo",
                "last_name": "Manager",
                "role": "ProjectManager",
            },
        )
        return pm

    def _ensure_supervisor(self, pm):
        supervisor, _ = models.Supervisors.objects.get_or_create(
            email=DEMO_SUPERVISOR_EMAIL,
            defaults={
                "created_by": pm,
                "first_name": "Demo",
                "last_name": "Supervisor",
                "phone_number": "09170000000",
            },
        )
        return supervisor

    def _ensure_project(self, pm, supervisor):
        project, created = models.Project.objects.get_or_create(
            project_name=DEMO_PROJECT_NAME,
            defaults={
                "project_type": "Residential",
                "start_date": date.today(),
                "budget": Decimal("1000000"),
                "user": pm,
                "supervisor": supervisor,
            },
        )
        if not created:
            # Keep the scenario repeatable by resetting used_budget-linked
            # rows; if the caller passed --reset we already wiped them.
            pass
        if supervisor.project_id_id != project.pk:
            supervisor.project_id = project
            supervisor.save()
        return project

    def _ensure_phases(self, project):
        phase_1, _ = models.Phase.objects.get_or_create(
            project=project,
            phase_name="PHASE 1 - Pre-Construction Phase",
            defaults={"allocated_budget": Decimal("100000")},
        )
        phase_2, _ = models.Phase.objects.get_or_create(
            project=project,
            phase_name="PHASE 2 - Design Phase",
            defaults={"allocated_budget": Decimal("50000")},
        )
        return phase_1, phase_2

    def _ensure_inventory(self, pm, project):
        cement, _ = models.InventoryItem.objects.get_or_create(
            name="Cement",
            created_by=pm,
            defaults={
                "category": "Building Material",
                "quantity": 1000,
                "price": Decimal("50"),
                "project": project,
            },
        )
        rebar, _ = models.InventoryItem.objects.get_or_create(
            name="Rebar",
            created_by=pm,
            defaults={
                "category": "Building Material",
                "quantity": 500,
                "price": Decimal("200"),
                "project": project,
            },
        )
        return cement, rebar

    def _ensure_plans(self, phase_1, cement, rebar):
        models.PhaseMaterialPlan.objects.update_or_create(
            phase=phase_1,
            inventory_item=cement,
            defaults={"planned_quantity": 100},
        )
        models.PhaseMaterialPlan.objects.update_or_create(
            phase=phase_1,
            inventory_item=rebar,
            defaults={"planned_quantity": 20},
        )

    def _record_usages(self, *, phase, supervisor, cement, rebar, trigger_50):
        record_material_usage(
            phase=phase,
            inventory_item=cement,
            quantity=50,
            supervisor=supervisor,
            notes="Demo cement usage",
        )
        record_material_usage(
            phase=phase,
            inventory_item=rebar,
            quantity=10,
            supervisor=supervisor,
            notes="Demo rebar usage",
        )

        if trigger_50:
            # Force the 50%-consumed warning by pushing the allocation and
            # inventory up and consuming >= half the project budget.
            phase.allocated_budget = Decimal("1000000")
            phase.save(update_fields=["allocated_budget", "updated_at"])
            cement.quantity = 20000
            cement.save(update_fields=["quantity", "updated_at"])

            _, warnings = record_material_usage(
                phase=phase,
                inventory_item=cement,
                quantity=10000,
                supervisor=supervisor,
                notes="Big demo pour",
            )
            for w in warnings:
                self.stdout.write(
                    self.style.WARNING(f"[{w['code']}] {w['message']}")
                )

    def _print_summary(self, project):
        summary = project_budget_summary(project)
        self.stdout.write(self.style.SUCCESS("Budget summary:"))
        self.stdout.write(f"  Project:          {project.project_name}")
        self.stdout.write(f"  Total budget:     {summary['total_budget']}")
        self.stdout.write(f"  Total allocated:  {summary['total_allocated']}")
        self.stdout.write(f"  Total used:       {summary['total_used']}")
        self.stdout.write(f"  Remaining:        {summary['remaining_budget']}")
        for phase in summary["phases"]:
            self.stdout.write(
                f"    - {phase['phase_name']}: used "
                f"{phase['used_budget']} / {phase['allocated_budget']} "
                f"(remaining {phase['remaining']})"
            )
