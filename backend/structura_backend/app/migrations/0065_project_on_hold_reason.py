# Generated manually for on_hold_reason field

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("app", "0064_supervisorreportsubmission"),
    ]

    operations = [
        migrations.AddField(
            model_name="project",
            name="on_hold_reason",
            field=models.TextField(blank=True, default=""),
        ),
    ]
