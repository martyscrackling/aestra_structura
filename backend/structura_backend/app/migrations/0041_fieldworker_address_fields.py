from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('app', '0040_supervisors_address_fields'),
    ]

    operations = [
        migrations.AddField(
            model_name='fieldworker',
            name='region',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=models.SET_NULL,
                to='app.region',
            ),
        ),
        migrations.AddField(
            model_name='fieldworker',
            name='province',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=models.SET_NULL,
                to='app.province',
            ),
        ),
        migrations.AddField(
            model_name='fieldworker',
            name='city',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=models.SET_NULL,
                to='app.city',
            ),
        ),
        migrations.AddField(
            model_name='fieldworker',
            name='barangay',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=models.SET_NULL,
                to='app.barangay',
            ),
        ),
    ]
