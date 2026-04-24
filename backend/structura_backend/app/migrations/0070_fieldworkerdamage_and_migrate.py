# Generated manually for multiple damage lines per field worker

from decimal import Decimal

from django.db import migrations, models
import django.db.models.deletion


def migrate_legacy_damages(apps, schema_editor):
    FieldWorker = apps.get_model('app', 'FieldWorker')
    FieldWorkerDamage = apps.get_model('app', 'FieldWorkerDamage')

    for fw in FieldWorker.objects.all().iterator():
        has_any = bool(
            (fw.damages_item and str(fw.damages_item).strip())
            or (fw.damages_category and str(fw.damages_category).strip())
        )
        if not has_any and fw.damages_price is None and fw.damages_deduction_per_salary is None:
            continue
        if FieldWorkerDamage.objects.filter(field_worker_id=fw.fieldworker_id).exists():
            continue
        FieldWorkerDamage.objects.create(
            field_worker_id=fw.fieldworker_id,
            category=fw.damages_category,
            item=fw.damages_item,
            price=fw.damages_price,
            schedule=fw.damages_schedule,
            deduction_per_salary=fw.damages_deduction_per_salary,
            pm_covers=bool(getattr(fw, 'damages_pm_covers', False)),
        )

    for fw in FieldWorker.objects.filter(
        fieldworker_id__in=FieldWorkerDamage.objects.values_list('field_worker_id', flat=True).distinct()
    ).iterator():
        entries = list(
            FieldWorkerDamage.objects.filter(field_worker_id=fw.fieldworker_id).order_by('id')
        )
        n = len(entries)
        if n == 0:
            continue

        def d(v, default=Decimal('0')):
            if v is None:
                return default
            return v if isinstance(v, Decimal) else Decimal(str(v))

        total_price = sum(d(e.price) for e in entries)
        total_ded = sum(
            d(e.deduction_per_salary) for e in entries if not e.pm_covers
        )
        if n == 1:
            e0 = entries[0]
            FieldWorker.objects.filter(pk=fw.fieldworker_id).update(
                damages_category=e0.category,
                damages_item=e0.item,
                damages_price=e0.price,
                damages_schedule=e0.schedule,
                damages_deduction_per_salary=Decimal('0') if e0.pm_covers else e0.deduction_per_salary,
                damages_pm_covers=e0.pm_covers,
            )
        else:
            FieldWorker.objects.filter(pk=fw.fieldworker_id).update(
                damages_category='Multiple',
                damages_item=f'{n} items',
                damages_price=total_price,
                damages_deduction_per_salary=total_ded,
                damages_pm_covers=all(e.pm_covers for e in entries),
                damages_schedule='Payment every Salary',
            )


def noop_reverse(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("app", "0069_fieldworker_damages_pm_covers"),
    ]

    operations = [
        migrations.CreateModel(
            name="FieldWorkerDamage",
            fields=[
                ("id", models.AutoField(primary_key=True, serialize=False)),
                (
                    "category",
                    models.CharField(blank=True, max_length=50, null=True),
                ),
                (
                    "item",
                    models.CharField(blank=True, max_length=255, null=True),
                ),
                (
                    "price",
                    models.DecimalField(
                        blank=True, decimal_places=2, max_digits=10, null=True
                    ),
                ),
                (
                    "schedule",
                    models.CharField(blank=True, max_length=50, null=True),
                ),
                (
                    "deduction_per_salary",
                    models.DecimalField(
                        blank=True, decimal_places=2, max_digits=10, null=True
                    ),
                ),
                ("pm_covers", models.BooleanField(default=False)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "field_worker",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="damage_entries",
                        to="app.fieldworker",
                    ),
                ),
            ],
            options={
                "ordering": ["created_at", "id"],
            },
        ),
        migrations.RunPython(migrate_legacy_damages, noop_reverse),
    ]
