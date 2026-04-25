from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('app', '0074_user_has_completed_quick_tour'),
    ]

    operations = [
        migrations.AddField(
            model_name='client',
            name='has_completed_quick_tour',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='supervisors',
            name='has_completed_quick_tour',
            field=models.BooleanField(default=False),
        ),
    ]
