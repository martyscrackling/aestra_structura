# Generated manually for per-phase client feedback

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('app', '0062_phasematerialplan_closed_at_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='backjobreview',
            name='phase',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='back_job_reviews',
                to='app.phase',
            ),
        ),
    ]
