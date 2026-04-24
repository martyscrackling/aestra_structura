"""
Recompute every project's status from subtask completion (and overdue rules).
Use after fixing sync bugs or to repair stale Completed / Overdue / Active values.
"""
from django.core.management.base import BaseCommand

from app import models


class Command(BaseCommand):
    help = (
        'Resync all project statuses: Completed when 100% subtasks are done, '
        'clears Completed when not, then applies Overdue for Active/Overdue when past the scheduled end.'
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--quiet',
            action='store_true',
            help='Only print the summary line, not per-project changes',
        )

    def handle(self, *args, **options):
        quiet = options.get('quiet', False)
        total = 0
        changed = 0
        for pid in (
            models.Project.objects.order_by('project_id')
            .values_list('project_id', flat=True)
            .iterator()
        ):
            total += 1
            p = models.Project.objects.get(project_id=pid)
            before = p.status
            p.update_status_based_on_progress()
            p.refresh_from_db()
            p.refresh_overdue_status()
            p.refresh_from_db()
            after = p.status
            if after != before:
                changed += 1
                if not quiet:
                    self.stdout.write(
                        f"  {pid} {p.project_name!r}: {before!r} -> {after!r}"
                    )
        self.stdout.write(
            self.style.SUCCESS(
                f"Resynced {total} project(s). {changed} had a status change."
            )
        )
