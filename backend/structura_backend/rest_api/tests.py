"""
Test suite for the Project / Phase / Inventory budget system.

Covers:
  * Project.set-budget and Project.budget-summary endpoints
  * Phase.allocate-budget endpoint
  * Phase.record-usage endpoint (happy path + validation + warnings)
  * Phase.planned-vs-actual endpoint
  * PhaseMaterialPlan CRUD (including duplicate guard)
  * Destructive guards on Phase and InventoryItem
  * Direct service-layer tests for record_material_usage / reverse_material_usage
  * Model property sanity checks
"""

from datetime import date
from decimal import Decimal
from io import StringIO

from django.core.management import call_command
from django.test import TestCase
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from app import models
from app.services.material_usage import (
    MaterialUsageError,
    WARN_PHASE_OVER_BUDGET,
    WARN_PROJECT_50_PERCENT,
    record_material_usage,
    reverse_material_usage,
)


# ---------------------------------------------------------------------------
# Shared fixture
# ---------------------------------------------------------------------------

class BudgetTestMixin:
    """Create a small, self-contained project/phase/inventory graph."""

    @classmethod
    def setUpTestData(cls):
        cls.pm_user = models.User.objects.create(
            email='pm-budget@test.local',
            password_hash='x',
            first_name='PM',
            last_name='Tester',
            role='ProjectManager',
        )

        cls.supervisor = models.Supervisors.objects.create(
            created_by=cls.pm_user,
            first_name='Sup',
            last_name='Visor',
            email='sv-budget@test.local',
            phone_number='09170000000',
        )

        cls.project = models.Project.objects.create(
            project_name='Budget Test Project',
            project_type='Residential',
            start_date=date(2026, 1, 1),
            budget=Decimal('1000000'),
            user=cls.pm_user,
            supervisor=cls.supervisor,
        )
        # Link the supervisor to the project so scoping queries succeed.
        cls.supervisor.project_id = cls.project
        cls.supervisor.save()

        cls.phase_1 = models.Phase.objects.create(
            project=cls.project,
            phase_name='PHASE 1 - Pre-Construction Phase',
            allocated_budget=Decimal('100000'),
        )
        cls.phase_2 = models.Phase.objects.create(
            project=cls.project,
            phase_name='PHASE 2 - Design Phase',
            allocated_budget=Decimal('50000'),
        )

        cls.cement = models.InventoryItem.objects.create(
            name='Cement',
            category='Building Material',
            quantity=1000,
            price=Decimal('50'),
            created_by=cls.pm_user,
            project=cls.project,
        )
        cls.rebar = models.InventoryItem.objects.create(
            name='Rebar',
            category='Building Material',
            quantity=500,
            price=Decimal('200'),
            created_by=cls.pm_user,
            project=cls.project,
        )


# ---------------------------------------------------------------------------
# Model properties
# ---------------------------------------------------------------------------

class ModelPropertyTests(BudgetTestMixin, APITestCase):
    def test_project_allocated_and_remaining(self):
        self.assertEqual(self.project.total_allocated_budget, Decimal('150000'))
        self.assertEqual(self.project.total_used_budget, Decimal('0'))
        self.assertEqual(self.project.remaining_budget, Decimal('1000000'))

    def test_phase_remaining_and_over_budget(self):
        self.assertEqual(self.phase_1.remaining_phase_budget, Decimal('100000'))
        self.assertFalse(self.phase_1.is_over_budget)

        self.phase_1.used_budget = Decimal('100001')
        self.phase_1.save()
        self.assertTrue(self.phase_1.is_over_budget)
        self.assertEqual(self.phase_1.remaining_phase_budget, Decimal('-1'))


# ---------------------------------------------------------------------------
# Project.set-budget & budget-summary
# ---------------------------------------------------------------------------

class ProjectBudgetEndpointTests(BudgetTestMixin, APITestCase):
    def _set_budget(self, project, payload):
        url = reverse('project-set-budget', kwargs={'pk': project.pk})
        return self.client.patch(url, payload, format='json')

    def test_set_budget_happy_path(self):
        r = self._set_budget(self.project, {'budget': '2000000'})
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        self.project.refresh_from_db()
        self.assertEqual(self.project.budget, Decimal('2000000'))

    def test_set_budget_missing(self):
        r = self._set_budget(self.project, {})
        self.assertEqual(r.status_code, 400)
        self.assertIn('budget', r.data.get('error', '').lower())

    def test_set_budget_not_numeric(self):
        r = self._set_budget(self.project, {'budget': 'one million'})
        self.assertEqual(r.status_code, 400)
        self.assertIn('number', r.data.get('error', '').lower())

    def test_set_budget_below_phase_allocations_is_rejected(self):
        # phase_1 + phase_2 allocations = 150,000; try to set budget to 100,000.
        r = self._set_budget(self.project, {'budget': '100000'})
        self.assertEqual(r.status_code, 400)
        self.assertIn('phase', r.data['error'].lower())
        self.project.refresh_from_db()
        self.assertEqual(self.project.budget, Decimal('1000000'))

    def test_set_budget_negative_rejected(self):
        r = self._set_budget(self.project, {'budget': '-1'})
        self.assertEqual(r.status_code, 400)

    def test_budget_summary_shape(self):
        url = reverse('project-budget-summary', kwargs={'pk': self.project.pk})
        r = self.client.get(url)
        self.assertEqual(r.status_code, 200)
        body = r.data
        self.assertEqual(body['project_id'], self.project.pk)
        self.assertEqual(Decimal(str(body['total_budget'])), Decimal('1000000'))
        self.assertEqual(Decimal(str(body['total_allocated'])), Decimal('150000'))
        self.assertEqual(Decimal(str(body['total_used'])), Decimal('0'))
        self.assertEqual(Decimal(str(body['remaining_budget'])), Decimal('1000000'))

        phase_ids = [p['phase_id'] for p in body['phases']]
        self.assertIn(self.phase_1.pk, phase_ids)
        self.assertIn(self.phase_2.pk, phase_ids)


# ---------------------------------------------------------------------------
# Phase.allocate-budget
# ---------------------------------------------------------------------------

class PhaseAllocateBudgetTests(BudgetTestMixin, APITestCase):
    def _allocate(self, phase, payload):
        url = reverse('phase-allocate-budget', kwargs={'pk': phase.pk})
        return self.client.patch(url, payload, format='json')

    def test_allocate_happy(self):
        r = self._allocate(self.phase_1, {'allocated_budget': '200000'})
        self.assertEqual(r.status_code, 200)
        self.phase_1.refresh_from_db()
        self.assertEqual(self.phase_1.allocated_budget, Decimal('200000'))

    def test_allocate_missing(self):
        r = self._allocate(self.phase_1, {})
        self.assertEqual(r.status_code, 400)

    def test_allocate_non_numeric(self):
        r = self._allocate(self.phase_1, {'allocated_budget': 'ten grand'})
        self.assertEqual(r.status_code, 400)

    def test_allocate_exceeds_project_budget(self):
        # project budget is 1,000,000, phase_2 allocation is 50,000; try to set
        # phase_1 to 990,000 -> total would be 1,040,000.
        r = self._allocate(self.phase_1, {'allocated_budget': '990000'})
        self.assertEqual(r.status_code, 400)
        self.assertIn('project budget', r.data['error'].lower())

    def test_allocate_less_than_used_is_rejected(self):
        self.phase_1.used_budget = Decimal('40000')
        self.phase_1.save()
        r = self._allocate(self.phase_1, {'allocated_budget': '30000'})
        self.assertEqual(r.status_code, 400)
        self.assertIn('already', r.data['error'].lower())

    def test_allocate_negative_rejected(self):
        r = self._allocate(self.phase_1, {'allocated_budget': '-1'})
        self.assertEqual(r.status_code, 400)


# ---------------------------------------------------------------------------
# Phase.record-usage
# ---------------------------------------------------------------------------

class RecordUsageEndpointTests(BudgetTestMixin, APITestCase):
    def _record(self, phase, payload):
        url = reverse('phase-record-usage', kwargs={'pk': phase.pk})
        return self.client.post(url, payload, format='json')

    def _payload(self, *, item=None, quantity=10, **overrides):
        base = {
            'inventory_item': (item or self.cement).pk,
            'quantity': quantity,
            'supervisor_id': self.supervisor.pk,
        }
        base.update(overrides)
        return base

    def test_record_usage_happy_path(self):
        r = self._record(self.phase_1, self._payload(quantity=10))
        self.assertEqual(r.status_code, 201, r.data)

        # Response shape
        self.assertIn('usage', r.data)
        self.assertIn('warnings', r.data)
        self.assertIn('phase', r.data)
        self.assertIn('project_remaining_budget', r.data)

        # Deductions
        self.cement.refresh_from_db()
        self.phase_1.refresh_from_db()
        self.project.refresh_from_db()
        self.assertEqual(self.cement.quantity, 990)
        self.assertEqual(self.phase_1.used_budget, Decimal('500'))
        self.assertEqual(self.project.remaining_budget, Decimal('999500'))

        # Usage row snapshot
        usage = models.InventoryUsage.objects.get(pk=r.data['usage']['usage_id'])
        self.assertEqual(usage.quantity_used, 10)
        self.assertEqual(usage.unit_price_at_use, Decimal('50'))
        self.assertEqual(usage.total_cost, Decimal('500'))
        self.assertEqual(usage.phase_id, self.phase_1.pk)
        self.assertEqual(usage.project_id, self.project.pk)
        self.assertEqual(usage.checked_out_by_id, self.supervisor.pk)

    def test_record_usage_missing_item(self):
        r = self._record(self.phase_1, {'quantity': 1, 'supervisor_id': self.supervisor.pk})
        self.assertEqual(r.status_code, 400)

    def test_record_usage_missing_supervisor(self):
        r = self._record(self.phase_1, {'inventory_item': self.cement.pk, 'quantity': 1})
        self.assertEqual(r.status_code, 400)

    def test_record_usage_non_integer_quantity(self):
        r = self._record(self.phase_1, self._payload(quantity='abc'))
        self.assertEqual(r.status_code, 400)

    def test_record_usage_zero_quantity(self):
        r = self._record(self.phase_1, self._payload(quantity=0))
        self.assertEqual(r.status_code, 400)

    def test_record_usage_unknown_item(self):
        r = self.client.post(
            reverse('phase-record-usage', kwargs={'pk': self.phase_1.pk}),
            {
                'inventory_item': 999999,
                'quantity': 1,
                'supervisor_id': self.supervisor.pk,
            },
            format='json',
        )
        self.assertEqual(r.status_code, 404)

    def test_record_usage_unknown_supervisor(self):
        r = self._record(self.phase_1, self._payload(supervisor_id=999999))
        self.assertEqual(r.status_code, 404)

    def test_record_usage_insufficient_inventory(self):
        self.cement.quantity = 5
        self.cement.save()
        r = self._record(self.phase_1, self._payload(quantity=10))
        self.assertEqual(r.status_code, 400)
        self.assertIn('inventory', r.data['error'].lower())

        # Nothing should have been deducted.
        self.cement.refresh_from_db()
        self.phase_1.refresh_from_db()
        self.assertEqual(self.cement.quantity, 5)
        self.assertEqual(self.phase_1.used_budget, Decimal('0'))
        self.assertFalse(models.InventoryUsage.objects.filter(phase=self.phase_1).exists())

    def test_record_usage_exceeds_phase_budget(self):
        # Give ourselves enough inventory so only the phase rule fires.
        self.cement.quantity = 10000
        self.cement.save()
        # phase_1 allocated 100,000; cement=50/unit; 2001 cement = 100,050 -> over.
        r = self._record(self.phase_1, self._payload(quantity=2001))
        self.assertEqual(r.status_code, 400)
        self.assertIn('phase', r.data['error'].lower())

        self.cement.refresh_from_db()
        self.phase_1.refresh_from_db()
        self.assertEqual(self.cement.quantity, 10000)
        self.assertEqual(self.phase_1.used_budget, Decimal('0'))

    def test_record_usage_exceeds_project_budget(self):
        # Set project budget very low but phase allocation large so only the
        # project-level rule blocks the request.
        self.project.budget = Decimal('100')
        self.project.save()
        self.phase_1.allocated_budget = Decimal('100000')
        self.phase_1.save()

        r = self._record(self.phase_1, self._payload(quantity=10))  # 10 * 50 = 500 > 100
        self.assertEqual(r.status_code, 400)
        self.assertIn('project', r.data['error'].lower())

    def test_record_usage_50_percent_warning(self):
        # Consume just over half of the project budget in one go.
        self.phase_1.allocated_budget = Decimal('1000000')
        self.phase_1.save()
        self.cement.quantity = 20000
        self.cement.save()
        # 10001 cement * 50 = 500,050 which is > 50% of 1,000,000
        r = self._record(self.phase_1, self._payload(quantity=10001))
        self.assertEqual(r.status_code, 201, r.data)
        codes = [w['code'] for w in r.data['warnings']]
        self.assertIn(WARN_PROJECT_50_PERCENT, codes)

    def test_record_usage_no_allocation_skips_phase_check(self):
        """
        If allocated_budget is 0 the service treats it as "unbudgeted" and
        does not block on the phase rule. The project rule still applies.
        """
        self.phase_1.allocated_budget = Decimal('0')
        self.phase_1.save()
        r = self._record(self.phase_1, self._payload(quantity=10))
        self.assertEqual(r.status_code, 201, r.data)


# ---------------------------------------------------------------------------
# PhaseMaterialPlan CRUD
# ---------------------------------------------------------------------------

class PhaseMaterialPlanCRUDTests(BudgetTestMixin, APITestCase):
    def _list_url(self):
        return reverse('phase-material-plan-list')

    def _detail_url(self, pk):
        return reverse('phase-material-plan-detail', kwargs={'pk': pk})

    def test_create_plan(self):
        r = self.client.post(
            self._list_url(),
            {
                'phase': self.phase_1.pk,
                'inventory_item': self.cement.pk,
                'planned_quantity': 100,
            },
            format='json',
        )
        self.assertEqual(r.status_code, 201, r.data)
        self.assertEqual(r.data['planned_quantity'], 100)
        self.assertEqual(Decimal(str(r.data['planned_cost'])), Decimal('5000'))

    def test_create_duplicate_plan_is_rejected(self):
        models.PhaseMaterialPlan.objects.create(
            phase=self.phase_1, inventory_item=self.cement, planned_quantity=1
        )
        r = self.client.post(
            self._list_url(),
            {
                'phase': self.phase_1.pk,
                'inventory_item': self.cement.pk,
                'planned_quantity': 5,
            },
            format='json',
        )
        self.assertEqual(r.status_code, 400)

    def test_create_two_plans_same_item_different_subtasks(self):
        st1 = models.Subtask.objects.create(
            phase=self.phase_1,
            title='Subtask A',
            status='pending',
        )
        st2 = models.Subtask.objects.create(
            phase=self.phase_1,
            title='Subtask B',
            status='pending',
        )
        r1 = self.client.post(
            self._list_url(),
            {
                'phase': self.phase_1.pk,
                'inventory_item': self.cement.pk,
                'planned_quantity': 10,
                'subtask': st1.subtask_id,
            },
            format='json',
        )
        self.assertEqual(r1.status_code, 201, r1.data)
        r2 = self.client.post(
            self._list_url(),
            {
                'phase': self.phase_1.pk,
                'inventory_item': self.cement.pk,
                'planned_quantity': 20,
                'subtask': st2.subtask_id,
            },
            format='json',
        )
        self.assertEqual(r2.status_code, 201, r2.data)
        self.assertEqual(
            models.PhaseMaterialPlan.objects.filter(
                phase=self.phase_1,
                inventory_item=self.cement,
            ).count(),
            2,
        )

    def test_plan_zero_or_negative_quantity_rejected(self):
        for q in (0, -3):
            r = self.client.post(
                self._list_url(),
                {
                    'phase': self.phase_1.pk,
                    'inventory_item': self.cement.pk,
                    'planned_quantity': q,
                },
                format='json',
            )
            self.assertEqual(r.status_code, 400, f'quantity {q} should be rejected')

    def test_list_plans_filtered_by_phase(self):
        models.PhaseMaterialPlan.objects.create(
            phase=self.phase_1, inventory_item=self.cement, planned_quantity=10
        )
        models.PhaseMaterialPlan.objects.create(
            phase=self.phase_2, inventory_item=self.rebar, planned_quantity=5
        )
        r = self.client.get(self._list_url(), {'phase_id': self.phase_1.pk})
        self.assertEqual(r.status_code, 200)
        data = r.data['results'] if isinstance(r.data, dict) else r.data
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]['phase'], self.phase_1.pk)

    def test_update_plan_quantity(self):
        plan = models.PhaseMaterialPlan.objects.create(
            phase=self.phase_1, inventory_item=self.cement, planned_quantity=10
        )
        r = self.client.patch(
            self._detail_url(plan.pk),
            {'planned_quantity': 25},
            format='json',
        )
        self.assertEqual(r.status_code, 200, r.data)
        plan.refresh_from_db()
        self.assertEqual(plan.planned_quantity, 25)

    def test_delete_plan(self):
        plan = models.PhaseMaterialPlan.objects.create(
            phase=self.phase_1, inventory_item=self.cement, planned_quantity=10
        )
        r = self.client.delete(self._detail_url(plan.pk))
        self.assertEqual(r.status_code, 204)
        self.assertFalse(
            models.PhaseMaterialPlan.objects.filter(pk=plan.pk).exists()
        )


# ---------------------------------------------------------------------------
# Planned-vs-actual
# ---------------------------------------------------------------------------

class PlannedVsActualTests(BudgetTestMixin, APITestCase):
    def _pva(self, phase):
        url = reverse('phase-planned-vs-actual', kwargs={'pk': phase.pk})
        return self.client.get(url)

    def test_empty_returns_no_items(self):
        r = self._pva(self.phase_1)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data['phase_id'], self.phase_1.pk)
        self.assertEqual(r.data['items'], [])

    def test_plan_only_shows_zero_actuals(self):
        models.PhaseMaterialPlan.objects.create(
            phase=self.phase_1, inventory_item=self.cement, planned_quantity=100
        )
        r = self._pva(self.phase_1)
        self.assertEqual(r.status_code, 200)
        items = r.data['items']
        self.assertEqual(len(items), 1)
        item = items[0]
        self.assertTrue(item['has_plan'])
        self.assertEqual(item['planned_quantity'], 100)
        self.assertEqual(Decimal(item['planned_cost']), Decimal('5000'))
        self.assertEqual(item['actual_quantity'], 0)
        self.assertEqual(Decimal(item['actual_cost']), Decimal('0'))
        self.assertEqual(item['quantity_variance'], -100)

    def test_plan_plus_actual_variance(self):
        models.PhaseMaterialPlan.objects.create(
            phase=self.phase_1, inventory_item=self.cement, planned_quantity=100
        )
        record_material_usage(
            phase=self.phase_1,
            inventory_item=self.cement,
            quantity=60,
            supervisor=self.supervisor,
        )

        r = self._pva(self.phase_1)
        item = r.data['items'][0]
        self.assertTrue(item['has_plan'])
        self.assertEqual(item['actual_quantity'], 60)
        self.assertEqual(Decimal(item['actual_cost']), Decimal('3000'))
        self.assertEqual(item['quantity_variance'], -40)
        self.assertEqual(Decimal(item['cost_variance']), Decimal('-2000'))

    def test_unplanned_usage_still_appears(self):
        record_material_usage(
            phase=self.phase_1,
            inventory_item=self.rebar,
            quantity=2,
            supervisor=self.supervisor,
        )
        r = self._pva(self.phase_1)
        items = r.data['items']
        self.assertEqual(len(items), 1)
        item = items[0]
        self.assertFalse(item['has_plan'])
        self.assertEqual(item['inventory_item_id'], self.rebar.pk)
        self.assertEqual(item['actual_quantity'], 2)
        self.assertEqual(Decimal(item['actual_cost']), Decimal('400'))


# ---------------------------------------------------------------------------
# Destructive guards
# ---------------------------------------------------------------------------

class DestructiveGuardTests(BudgetTestMixin, APITestCase):
    def test_phase_with_usage_cannot_be_deleted(self):
        record_material_usage(
            phase=self.phase_1,
            inventory_item=self.cement,
            quantity=1,
            supervisor=self.supervisor,
        )
        url = reverse('phase-detail', kwargs={'pk': self.phase_1.pk})
        r = self.client.delete(url)
        self.assertEqual(r.status_code, 400)
        self.assertTrue(models.Phase.objects.filter(pk=self.phase_1.pk).exists())

    def test_phase_without_usage_can_be_deleted(self):
        url = reverse('phase-detail', kwargs={'pk': self.phase_2.pk})
        r = self.client.delete(url)
        self.assertEqual(r.status_code, 204)
        self.assertFalse(models.Phase.objects.filter(pk=self.phase_2.pk).exists())

    def test_inventory_item_with_usage_cannot_be_deleted(self):
        record_material_usage(
            phase=self.phase_1,
            inventory_item=self.cement,
            quantity=1,
            supervisor=self.supervisor,
        )
        url = reverse('inventory-item-detail', kwargs={'pk': self.cement.pk})
        r = self.client.delete(f'{url}?user_id={self.pm_user.pk}')
        self.assertEqual(r.status_code, 400)
        self.assertTrue(models.InventoryItem.objects.filter(pk=self.cement.pk).exists())

    def test_inventory_item_with_plan_cannot_be_deleted(self):
        models.PhaseMaterialPlan.objects.create(
            phase=self.phase_1, inventory_item=self.rebar, planned_quantity=1
        )
        url = reverse('inventory-item-detail', kwargs={'pk': self.rebar.pk})
        r = self.client.delete(f'{url}?user_id={self.pm_user.pk}')
        self.assertEqual(r.status_code, 400)
        self.assertTrue(models.InventoryItem.objects.filter(pk=self.rebar.pk).exists())


# ---------------------------------------------------------------------------
# Phase completion closes material plans (Policy A)
# ---------------------------------------------------------------------------

class PhaseCompletionClosesPlansTests(BudgetTestMixin, APITestCase):
    def setUp(self):
        super().setUp()
        # Assign 30 cement to phase 1, use 12.
        self.plan = models.PhaseMaterialPlan.objects.create(
            phase=self.phase_1, inventory_item=self.cement, planned_quantity=30,
        )
        record_material_usage(
            phase=self.phase_1,
            inventory_item=self.cement,
            quantity=12,
            supervisor=self.supervisor,
        )

    def test_patching_phase_to_completed_closes_plans_with_leftover(self):
        url = reverse('phase-detail', kwargs={'pk': self.phase_1.pk})
        r = self.client.patch(url, {'status': 'completed'}, format='json')
        self.assertEqual(r.status_code, 200)
        closure = r.data.get('material_plan_closure')
        self.assertIsNotNone(closure)
        self.assertEqual(len(closure['leftovers']), 1)
        leftover = closure['leftovers'][0]
        self.assertEqual(leftover['assigned'], 30)
        self.assertEqual(leftover['used'], 12)
        self.assertEqual(leftover['leftover'], 18)

        self.plan.refresh_from_db()
        self.assertEqual(self.plan.status, models.PhaseMaterialPlan.STATUS_CLOSED)
        self.assertEqual(self.plan.leftover_quantity, 18)
        self.assertIsNotNone(self.plan.closed_at)

    def test_record_usage_rejected_after_phase_completed(self):
        self.phase_1.status = 'completed'
        self.phase_1.save(update_fields=['status'])
        url = reverse('phase-record-usage', kwargs={'pk': self.phase_1.pk})
        r = self.client.post(url, {
            'inventory_item': self.cement.pk,
            'quantity': 1,
            'supervisor_id': self.supervisor.pk,
        }, format='json')
        self.assertEqual(r.status_code, 400)
        self.assertIn('completed', r.data['error'].lower())

    def test_planned_vs_actual_reports_closed_status(self):
        url = reverse('phase-detail', kwargs={'pk': self.phase_1.pk})
        self.client.patch(url, {'status': 'completed'}, format='json')

        pva_url = reverse('phase-planned-vs-actual', kwargs={'pk': self.phase_1.pk})
        r = self.client.get(pva_url)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data['phase_status'], 'completed')
        row = next(i for i in r.data['items']
                   if i['inventory_item_id'] == self.cement.pk)
        self.assertEqual(row['plan_status'], 'closed')
        self.assertEqual(row['leftover_quantity'], 18)
        self.assertEqual(row['remaining_quantity'], 0)

    def test_explicit_close_materials_endpoint(self):
        url = reverse('phase-close-materials', kwargs={'pk': self.phase_1.pk})
        r = self.client.post(url, {}, format='json')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(len(r.data['leftovers']), 1)
        self.plan.refresh_from_db()
        self.assertTrue(self.plan.is_closed)

    def test_closing_is_idempotent(self):
        url = reverse('phase-close-materials', kwargs={'pk': self.phase_1.pk})
        r1 = self.client.post(url, {}, format='json')
        self.assertEqual(len(r1.data['leftovers']), 1)
        r2 = self.client.post(url, {}, format='json')
        self.assertEqual(r2.status_code, 200)
        self.assertEqual(r2.data['leftovers'], [])


# ---------------------------------------------------------------------------
# Service layer (direct)
# ---------------------------------------------------------------------------

class MaterialUsageServiceTests(BudgetTestMixin, APITestCase):
    def test_service_deducts_and_snapshots_price(self):
        usage, warnings = record_material_usage(
            phase=self.phase_1,
            inventory_item=self.cement,
            quantity=20,
            supervisor=self.supervisor,
            notes='first pour',
        )
        self.assertEqual(usage.quantity_used, 20)
        self.assertEqual(usage.unit_price_at_use, Decimal('50'))
        self.assertEqual(usage.total_cost, Decimal('1000'))
        self.assertEqual(usage.notes, 'first pour')
        self.assertEqual(warnings, [])

        self.cement.refresh_from_db()
        self.phase_1.refresh_from_db()
        self.assertEqual(self.cement.quantity, 980)
        self.assertEqual(self.phase_1.used_budget, Decimal('1000'))

    def test_service_rejects_zero_or_negative_quantity(self):
        for q in (0, -5):
            with self.assertRaises(MaterialUsageError):
                record_material_usage(
                    phase=self.phase_1,
                    inventory_item=self.cement,
                    quantity=q,
                    supervisor=self.supervisor,
                )

    def test_service_insufficient_inventory_raises(self):
        self.cement.quantity = 3
        self.cement.save()
        with self.assertRaises(MaterialUsageError):
            record_material_usage(
                phase=self.phase_1,
                inventory_item=self.cement,
                quantity=10,
                supervisor=self.supervisor,
            )
        self.cement.refresh_from_db()
        self.assertEqual(self.cement.quantity, 3)

    def test_service_phase_over_budget_raises(self):
        self.phase_1.allocated_budget = Decimal('100')
        self.phase_1.save()
        with self.assertRaises(MaterialUsageError):
            record_material_usage(
                phase=self.phase_1,
                inventory_item=self.cement,
                quantity=10,  # 500 > 100
                supervisor=self.supervisor,
            )

    def test_service_phase_over_budget_warning_when_unbudgeted_phase(self):
        """
        Set allocation to 0 (skip hard block) and make usage trivially produce
        a warning by leaving phase.is_over_budget True post-mutation.
        """
        self.phase_1.allocated_budget = Decimal('0')
        self.phase_1.save()
        _, warnings = record_material_usage(
            phase=self.phase_1,
            inventory_item=self.cement,
            quantity=1,  # cost 50 against 0 allocation -> over budget
            supervisor=self.supervisor,
        )
        codes = [w['code'] for w in warnings]
        self.assertIn(WARN_PHASE_OVER_BUDGET, codes)

    def test_reverse_restores_inventory_and_budget(self):
        usage, _ = record_material_usage(
            phase=self.phase_1,
            inventory_item=self.cement,
            quantity=10,
            supervisor=self.supervisor,
        )
        self.cement.refresh_from_db()
        self.phase_1.refresh_from_db()
        self.assertEqual(self.cement.quantity, 990)
        self.assertEqual(self.phase_1.used_budget, Decimal('500'))

        reverse_material_usage(usage=usage)
        self.cement.refresh_from_db()
        self.phase_1.refresh_from_db()
        usage.refresh_from_db()
        self.assertEqual(self.cement.quantity, 1000)
        self.assertEqual(self.phase_1.used_budget, Decimal('0'))
        self.assertEqual(usage.status, 'Returned')


# ---------------------------------------------------------------------------
# End-to-end seed scenario (management command)
# ---------------------------------------------------------------------------

class SeedBudgetDemoCommandTests(TestCase):
    """
    Smoke-tests the `seed_budget_demo` management command so the scripted
    end-to-end scenario stays green as the budget flow evolves.
    """

    def test_command_runs_and_applies_expected_mutations(self):
        out = StringIO()
        call_command('seed_budget_demo', stdout=out)
        output = out.getvalue()

        self.assertIn('Budget summary', output)
        self.assertIn('Total budget:', output)

        project = models.Project.objects.get(project_name='Budget Demo Project')
        self.assertEqual(project.budget, Decimal('1000000'))

        phase_1 = project.phases.get(
            phase_name='PHASE 1 - Pre-Construction Phase'
        )
        self.assertEqual(phase_1.allocated_budget, Decimal('100000'))
        # 50 cement @ 50 + 10 rebar @ 200 = 2,500 + 2,000 = 4,500
        self.assertEqual(phase_1.used_budget, Decimal('4500'))

        cement = models.InventoryItem.objects.get(
            name='Cement', created_by__email='pm-demo@aestra.local'
        )
        rebar = models.InventoryItem.objects.get(
            name='Rebar', created_by__email='pm-demo@aestra.local'
        )
        self.assertEqual(cement.quantity, 950)
        self.assertEqual(rebar.quantity, 490)

        # Both plans were recorded.
        self.assertEqual(phase_1.material_plans.count(), 2)

        project.refresh_from_db()
        self.assertEqual(project.remaining_budget, Decimal('995500'))

    def test_command_is_idempotent(self):
        call_command('seed_budget_demo', stdout=StringIO())
        call_command('seed_budget_demo', '--reset', stdout=StringIO())

        self.assertEqual(
            models.Project.objects.filter(
                project_name='Budget Demo Project'
            ).count(),
            1,
        )

    def test_command_trigger_50_percent_fires_warning(self):
        out = StringIO()
        call_command(
            'seed_budget_demo', '--trigger-50-percent', stdout=out
        )
        output = out.getvalue()
        self.assertIn('PROJECT_50_PERCENT', output)
