from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('app', '0034_supervisors_client_created_by'),
    ]

    operations = [
        migrations.AddField(
            model_name='fieldworker',
            name='photo',
            field=models.FileField(blank=True, null=True, upload_to='client_images/'),
        ),
    ]
