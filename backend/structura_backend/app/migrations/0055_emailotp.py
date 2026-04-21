from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('app', '0054_backjobreview'),
    ]

    operations = [
        migrations.CreateModel(
            name='EmailOTP',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('email', models.EmailField(max_length=100, unique=True)),
                ('code_hash', models.CharField(max_length=255)),
                ('expires_at', models.DateTimeField()),
                ('resend_available_at', models.DateTimeField()),
                ('is_verified', models.BooleanField(default=False)),
                ('verified_at', models.DateTimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
        ),
    ]
