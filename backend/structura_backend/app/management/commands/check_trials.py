from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from app.models import User
from app.utils import send_trial_warning_email
import logging

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Check trial periods and send warning emails to users approaching expiration'

    def add_arguments(self, parser):
        parser.add_argument(
            '--force',
            action='store_true',
            help='Force send warnings even if already sent',
        )

    def handle(self, *args, **options):
        force = options.get('force', False)
        
        self.stdout.write(self.style.SUCCESS('Starting trial period check...'))
        
        now = timezone.now()
        
        # Get all ProjectManager users in trial period
        trial_users = User.objects.filter(
            role='ProjectManager',
            subscription_status='trial',
            trial_end_date__isnull=False
        )
        
        warnings_sent = 0
        expired_users = 0
        
        for user in trial_users:
            days_remaining = user.get_trial_days_remaining()
            
            # Check if trial has expired
            if days_remaining <= 0:
                if user.subscription_status != 'expired':
                    user.subscription_status = 'expired'
                    user.save()
                    expired_users += 1
                    self.stdout.write(
                        self.style.WARNING(f'Marked {user.email} as expired')
                    )
                
                # Send expired notification if not sent
                if send_trial_warning_email(user, force_send=force):
                    warnings_sent += 1
                    self.stdout.write(
                        self.style.SUCCESS(f'Sent expiration email to {user.email}')
                    )
                continue
            
            # Send 7-day warning
            if days_remaining <= 7:
                if send_trial_warning_email(user, force_send=force):
                    warnings_sent += 1
                    self.stdout.write(
                        self.style.SUCCESS(f'Sent 7-day warning to {user.email}')
                    )
            
            # Send 3-day warning
            elif days_remaining <= 3:
                if send_trial_warning_email(user, force_send=force):
                    warnings_sent += 1
                    self.stdout.write(
                        self.style.SUCCESS(f'Sent 3-day warning to {user.email}')
                    )
            
            # Send 1-day warning
            elif days_remaining <= 1:
                if send_trial_warning_email(user, force_send=force):
                    warnings_sent += 1
                    self.stdout.write(
                        self.style.SUCCESS(f'Sent 1-day warning to {user.email}')
                    )
        
        # Summary
        self.stdout.write(self.style.SUCCESS('\n' + '='*50))
        self.stdout.write(self.style.SUCCESS('Trial Check Complete!'))
        self.stdout.write(self.style.SUCCESS(f'Total trial users checked: {trial_users.count()}'))
        self.stdout.write(self.style.SUCCESS(f'Warning emails sent: {warnings_sent}'))
        self.stdout.write(self.style.SUCCESS(f'Users marked as expired: {expired_users}'))
        self.stdout.write(self.style.SUCCESS('='*50 + '\n'))
