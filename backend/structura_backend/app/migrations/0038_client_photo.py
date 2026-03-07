from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('app', '0037_supervisors_photo'),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            database_operations=[
                migrations.RunSQL(
                    sql=(
                        'ALTER TABLE app_client '
                        'ADD COLUMN IF NOT EXISTS photo varchar(100) NULL;'
                    ),
                    reverse_sql='ALTER TABLE app_client DROP COLUMN IF EXISTS photo;',
                ),
            ],
            state_operations=[
                migrations.AddField(
                    model_name='client',
                    name='photo',
                    field=models.FileField(
                        blank=True,
                        null=True,
                        upload_to='client_images/',
                    ),
                ),
            ],
        ),
    ]
