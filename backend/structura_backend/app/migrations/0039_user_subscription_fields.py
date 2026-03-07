from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('app', '0038_client_photo'),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            database_operations=[
                migrations.RunSQL(
                    sql=(
                        "ALTER TABLE app_user "
                        "ADD COLUMN IF NOT EXISTS payment_date timestamptz NULL;"
                        "ALTER TABLE app_user "
                        "ADD COLUMN IF NOT EXISTS subscription_start_date timestamptz NULL;"
                        "ALTER TABLE app_user "
                        "ADD COLUMN IF NOT EXISTS subscription_end_date timestamptz NULL;"
                        "ALTER TABLE app_user "
                        "ADD COLUMN IF NOT EXISTS subscription_status varchar(50) NOT NULL DEFAULT 'trial';"
                        "ALTER TABLE app_user "
                        "ADD COLUMN IF NOT EXISTS subscription_years integer NOT NULL DEFAULT 0;"
                        "ALTER TABLE app_user "
                        "ADD COLUMN IF NOT EXISTS trial_start_date timestamptz NULL;"
                        "ALTER TABLE app_user "
                        "ADD COLUMN IF NOT EXISTS trial_end_date timestamptz NULL;"
                        "ALTER TABLE app_user "
                        "ADD COLUMN IF NOT EXISTS warning_1day_sent boolean NOT NULL DEFAULT false;"
                        "ALTER TABLE app_user "
                        "ADD COLUMN IF NOT EXISTS warning_3days_sent boolean NOT NULL DEFAULT false;"
                        "ALTER TABLE app_user "
                        "ADD COLUMN IF NOT EXISTS warning_7days_sent boolean NOT NULL DEFAULT false;"
                    ),
                    reverse_sql=(
                        "ALTER TABLE app_user DROP COLUMN IF EXISTS warning_7days_sent;"
                        "ALTER TABLE app_user DROP COLUMN IF EXISTS warning_3days_sent;"
                        "ALTER TABLE app_user DROP COLUMN IF EXISTS warning_1day_sent;"
                        "ALTER TABLE app_user DROP COLUMN IF EXISTS trial_end_date;"
                        "ALTER TABLE app_user DROP COLUMN IF EXISTS trial_start_date;"
                        "ALTER TABLE app_user DROP COLUMN IF EXISTS subscription_years;"
                        "ALTER TABLE app_user DROP COLUMN IF EXISTS subscription_status;"
                        "ALTER TABLE app_user DROP COLUMN IF EXISTS subscription_end_date;"
                        "ALTER TABLE app_user DROP COLUMN IF EXISTS subscription_start_date;"
                        "ALTER TABLE app_user DROP COLUMN IF EXISTS payment_date;"
                    ),
                ),
            ],
            state_operations=[
                migrations.AddField(
                    model_name='user',
                    name='payment_date',
                    field=models.DateTimeField(blank=True, null=True),
                ),
                migrations.AddField(
                    model_name='user',
                    name='subscription_start_date',
                    field=models.DateTimeField(blank=True, null=True),
                ),
                migrations.AddField(
                    model_name='user',
                    name='subscription_end_date',
                    field=models.DateTimeField(blank=True, null=True),
                ),
                migrations.AddField(
                    model_name='user',
                    name='subscription_status',
                    field=models.CharField(default='trial', max_length=50),
                ),
                migrations.AddField(
                    model_name='user',
                    name='subscription_years',
                    field=models.IntegerField(default=0),
                ),
                migrations.AddField(
                    model_name='user',
                    name='trial_start_date',
                    field=models.DateTimeField(blank=True, null=True),
                ),
                migrations.AddField(
                    model_name='user',
                    name='trial_end_date',
                    field=models.DateTimeField(blank=True, null=True),
                ),
                migrations.AddField(
                    model_name='user',
                    name='warning_1day_sent',
                    field=models.BooleanField(default=False),
                ),
                migrations.AddField(
                    model_name='user',
                    name='warning_3days_sent',
                    field=models.BooleanField(default=False),
                ),
                migrations.AddField(
                    model_name='user',
                    name='warning_7days_sent',
                    field=models.BooleanField(default=False),
                ),
            ],
        ),
    ]
