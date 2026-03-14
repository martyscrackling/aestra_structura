from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('app', '0048_add_project_to_inventoryitem'),
    ]

    operations = [
        migrations.AddField(
            model_name='fieldworker',
            name='weekly_salary',
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True),
        ),
        migrations.AddField(
            model_name='fieldworker',
            name='sss_weekly_min',
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True),
        ),
        migrations.AddField(
            model_name='fieldworker',
            name='philhealth_weekly_min',
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True),
        ),
        migrations.AddField(
            model_name='fieldworker',
            name='pagibig_weekly_min',
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True),
        ),
        migrations.AddField(
            model_name='fieldworker',
            name='sss_weekly_topup',
            field=models.DecimalField(decimal_places=2, default=0, max_digits=10),
        ),
        migrations.AddField(
            model_name='fieldworker',
            name='philhealth_weekly_topup',
            field=models.DecimalField(decimal_places=2, default=0, max_digits=10),
        ),
        migrations.AddField(
            model_name='fieldworker',
            name='pagibig_weekly_topup',
            field=models.DecimalField(decimal_places=2, default=0, max_digits=10),
        ),
        migrations.AddField(
            model_name='fieldworker',
            name='sss_weekly_total',
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True),
        ),
        migrations.AddField(
            model_name='fieldworker',
            name='philhealth_weekly_total',
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True),
        ),
        migrations.AddField(
            model_name='fieldworker',
            name='pagibig_weekly_total',
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True),
        ),
        migrations.AddField(
            model_name='fieldworker',
            name='total_weekly_deduction',
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True),
        ),
        migrations.AddField(
            model_name='fieldworker',
            name='net_weekly_pay',
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True),
        ),
    ]
