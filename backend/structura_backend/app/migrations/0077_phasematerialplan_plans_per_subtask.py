# Generated manually: allow the same (phase, material) with different subtasks.

from django.db import migrations, models
from django.db.models import Q


class Migration(migrations.Migration):
    dependencies = [
        ("app", "0076_project_payroll_used_budget"),
    ]

    operations = [
        migrations.AlterUniqueTogether(
            name="phasematerialplan",
            unique_together=set(),
        ),
        migrations.AddConstraint(
            model_name="phasematerialplan",
            constraint=models.UniqueConstraint(
                condition=Q(subtask__isnull=False),
                fields=("phase", "inventory_item", "subtask"),
                name="phmatplan_uniq_phase_item_subtask_set",
            ),
        ),
        migrations.AddConstraint(
            model_name="phasematerialplan",
            constraint=models.UniqueConstraint(
                condition=Q(subtask__isnull=True),
                fields=("phase", "inventory_item"),
                name="phmatplan_uniq_phase_item_subtask_null",
            ),
        ),
    ]
