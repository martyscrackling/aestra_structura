from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('app', '0055_emailotp'),
    ]

    operations = [
        migrations.CreateModel(
            name='SubtaskPhoto',
            fields=[
                ('photo_id', models.AutoField(primary_key=True, serialize=False)),
                ('photo', models.FileField(upload_to='subtask_update_photos/')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('subtask', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='update_photos', to='app.subtask')),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
    ]
