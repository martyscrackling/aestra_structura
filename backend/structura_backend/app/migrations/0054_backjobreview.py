from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('app', '0053_alter_inventoryitem_status_and_more'),
    ]

    operations = [
        migrations.CreateModel(
            name='BackJobReview',
            fields=[
                ('review_id', models.AutoField(primary_key=True, serialize=False)),
                ('review_text', models.TextField(max_length=2000)),
                ('is_resolved', models.BooleanField(default=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('client', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='back_job_reviews', to='app.client')),
                ('project', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='back_job_reviews', to='app.project')),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
    ]
