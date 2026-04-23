# Generated manually

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('app', '0063_backjobreview_phase'),
    ]

    operations = [
        migrations.CreateModel(
            name='SupervisorReportSubmission',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('submission_id', models.CharField(db_index=True, max_length=255, unique=True)),
                ('report_data', models.JSONField()),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('project', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='supervisor_report_submissions',
                    to='app.project',
                )),
                ('supervisor', models.ForeignKey(
                    blank=True,
                    null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='report_submissions',
                    to='app.supervisors',
                )),
            ],
            options={
                'ordering': ['-updated_at'],
            },
        ),
    ]
