from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('app', '0049_fieldworker_weekly_deductions'),
    ]

    operations = [
        migrations.AddField(
            model_name='fieldworker',
            name='cash_advance_balance',
            field=models.DecimalField(decimal_places=2, default=0, max_digits=10),
        ),
        migrations.AddField(
            model_name='fieldworker',
            name='deduction_per_salary',
            field=models.DecimalField(decimal_places=2, default=0, max_digits=10),
        ),
    ]
