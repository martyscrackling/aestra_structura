from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('app', '0035_fieldworker_photo'),
    ]

    operations = [
        migrations.AlterField(
            model_name='fieldworker',
            name='photo',
            field=models.FileField(blank=True, null=True, upload_to='fieldworker_images/'),
        ),
    ]
