from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('app', '0075_supervisors_client_has_completed_quick_tour'),
    ]

    operations = [
        migrations.AddField(
            model_name='project',
            name='payroll_used_budget',
            field=models.DecimalField(decimal_places=2, default=0, max_digits=12),
        ),
    ]

