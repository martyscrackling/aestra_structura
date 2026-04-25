from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('app', '0073_remove_inappnotification_app_inappno_recipie_7205f1_idx_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='has_completed_quick_tour',
            field=models.BooleanField(default=False),
        ),
    ]
