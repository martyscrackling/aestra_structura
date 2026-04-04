from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('app', '0051_inventory_units_and_movements'),
    ]

    operations = [
        migrations.AlterUniqueTogether(
            name='attendance',
            unique_together={('field_worker', 'project', 'attendance_date')},
        ),
    ]
