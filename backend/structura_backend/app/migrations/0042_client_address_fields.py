from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('app', '0041_fieldworker_address_fields'),
    ]

    operations = [
        migrations.AddField(
            model_name='client',
            name='region',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=models.SET_NULL,
                to='app.region',
            ),
        ),
        migrations.AddField(
            model_name='client',
            name='province',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=models.SET_NULL,
                to='app.province',
            ),
        ),
        migrations.AddField(
            model_name='client',
            name='city',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=models.SET_NULL,
                to='app.city',
            ),
        ),
        migrations.AddField(
            model_name='client',
            name='barangay',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=models.SET_NULL,
                to='app.barangay',
            ),
        ),
    ]
