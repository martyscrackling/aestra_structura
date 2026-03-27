from django.db import migrations, models
import django.db.models.deletion


def create_units_for_existing_items(apps, schema_editor):
    InventoryItem = apps.get_model('app', 'InventoryItem')
    InventoryUnit = apps.get_model('app', 'InventoryUnit')
    InventoryUnitMovement = apps.get_model('app', 'InventoryUnitMovement')

    for item in InventoryItem.objects.all().iterator():
        if InventoryUnit.objects.filter(inventory_item=item).exists():
            continue

        target_qty = item.quantity if item.quantity and item.quantity > 0 else 1
        prefix = f'ITEM{item.item_id}'

        for idx in range(1, target_qty + 1):
            code = f'{prefix}-{str(idx).zfill(3)}'
            unit = InventoryUnit.objects.create(
                inventory_item=item,
                unit_code=code,
                status='Available',
                current_project=item.project,
            )
            if item.project_id:
                InventoryUnitMovement.objects.create(
                    unit=unit,
                    from_project=None,
                    to_project=item.project,
                    action='Assigned',
                    moved_by=item.created_by,
                    notes='Auto-migrated from legacy inventory profile assignment',
                )


def noop_reverse(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('app', '0050_fieldworker_cash_advance_fields'),
    ]

    operations = [
        migrations.CreateModel(
            name='InventoryUnit',
            fields=[
                ('unit_id', models.AutoField(primary_key=True, serialize=False)),
                ('unit_code', models.CharField(max_length=120, unique=True)),
                (
                    'status',
                    models.CharField(
                        choices=[
                            ('Available', 'Available'),
                            ('Checked Out', 'Checked Out'),
                            ('Returned', 'Returned'),
                            ('Maintenance', 'Maintenance'),
                        ],
                        default='Available',
                        max_length=20,
                    ),
                ),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                (
                    'current_project',
                    models.ForeignKey(
                        blank=True,
                        db_column='project_id',
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name='inventory_units',
                        to='app.project',
                    ),
                ),
                (
                    'inventory_item',
                    models.ForeignKey(
                        db_column='item_id',
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='units',
                        to='app.inventoryitem',
                    ),
                ),
            ],
            options={
                'ordering': ['unit_code'],
            },
        ),
        migrations.CreateModel(
            name='InventoryUnitMovement',
            fields=[
                ('movement_id', models.AutoField(primary_key=True, serialize=False)),
                (
                    'action',
                    models.CharField(
                        choices=[
                            ('Assigned', 'Assigned'),
                            ('Transferred', 'Transferred'),
                            ('Checked Out', 'Checked Out'),
                            ('Returned', 'Returned'),
                            ('Status Updated', 'Status Updated'),
                        ],
                        max_length=30,
                    ),
                ),
                ('notes', models.TextField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                (
                    'from_project',
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name='unit_movements_from',
                        to='app.project',
                    ),
                ),
                (
                    'moved_by',
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name='inventory_unit_movements',
                        to='app.user',
                    ),
                ),
                (
                    'to_project',
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name='unit_movements_to',
                        to='app.project',
                    ),
                ),
                (
                    'unit',
                    models.ForeignKey(
                        db_column='unit_id',
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='movements',
                        to='app.inventoryunit',
                    ),
                ),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
        migrations.AddField(
            model_name='inventoryusage',
            name='inventory_unit',
            field=models.ForeignKey(
                blank=True,
                db_column='unit_id',
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='usages',
                to='app.inventoryunit',
            ),
        ),
        migrations.RunPython(create_units_for_existing_items, noop_reverse),
    ]
