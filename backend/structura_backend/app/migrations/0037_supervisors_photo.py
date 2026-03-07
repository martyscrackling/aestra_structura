from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('app', '0036_alter_fieldworker_photo_upload_to'),
    ]

    operations = [
        migrations.AddField(
            model_name='supervisors',
            name='photo',
            field=models.FileField(blank=True, null=True, upload_to='supervisor_images/'),
        ),
    ]
