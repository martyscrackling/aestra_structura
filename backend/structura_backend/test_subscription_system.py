"""
Test Script for Subscription Management System

This script helps test the trial and subscription management features.

Usage:
    python test_subscription_system.py
"""

from django.utils import timezone
from datetime import timedelta
from app.models import User, SubscriptionWarning, PaymentHistory
from app.utils import send_trial_warning_email
import os
import django

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'structura_backend.settings')
django.setup()

def print_header(text):
    print("\n" + "="*60)
    print(f"  {text}")
    print("="*60)

def print_section(text):
    print(f"\n--- {text} ---")

def create_test_users():
    """Create test users with different trial statuses"""
    print_header("Creating Test Users")
    
    test_users = [
        {
            'email': 'trial_green@test.com',
            'first_name': 'Green',
            'last_name': 'User',
            'days_remaining': 10,
            'description': 'More than 7 days remaining (GREEN)'
        },
        {
            'email': 'trial_yellow@test.com',
            'first_name': 'Yellow',
            'last_name': 'User',
            'days_remaining': 5,
            'description': '3-7 days remaining (YELLOW)'
        },
        {
            'email': 'trial_red@test.com',
            'first_name': 'Red',
            'last_name': 'User',
            'days_remaining': 2,
            'description': 'Less than 3 days remaining (RED)'
        },
        {
            'email': 'trial_expired@test.com',
            'first_name': 'Expired',
            'last_name': 'User',
            'days_remaining': -2,
            'description': 'Trial expired (GRAY)'
        },
        {
            'email': 'paid_user@test.com',
            'first_name': 'Paid',
            'last_name': 'User',
            'days_remaining': None,
            'description': 'Active paid subscription'
        }
    ]
    
    created_users = []
    
    for user_data in test_users:
        email = user_data['email']
        
        # Check if user already exists
        if User.objects.filter(email=email).exists():
            print(f"✓ User already exists: {email}")
            user = User.objects.get(email=email)
        else:
            # Create user
            now = timezone.now()
            
            if user_data['days_remaining'] is None:
                # Paid user
                user = User.objects.create(
                    email=email,
                    password_hash='testpassword123',
                    first_name=user_data['first_name'],
                    last_name=user_data['last_name'],
                    role='ProjectManager',
                    subscription_status='active',
                    subscription_start_date=now,
                    subscription_end_date=now + timedelta(days=365),
                    subscription_years=1,
                    payment_date=now
                )
            else:
                # Trial user
                days = user_data['days_remaining']
                user = User.objects.create(
                    email=email,
                    password_hash='testpassword123',
                    first_name=user_data['first_name'],
                    last_name=user_data['last_name'],
                    role='ProjectManager',
                    subscription_status='trial' if days > 0 else 'expired',
                    trial_start_date=now - timedelta(days=14-days),
                    trial_end_date=now + timedelta(days=days)
                )
            
            print(f"✓ Created: {email} - {user_data['description']}")
        
        created_users.append(user)
    
    return created_users

def display_user_status(users):
    """Display status of all users"""
    print_header("User Status Overview")
    
    print(f"\n{'Email':<30} {'Status':<15} {'Days Left':<12} {'Color':<10}")
    print("-" * 70)
    
    for user in users:
        if user.subscription_status == 'trial':
            days = user.get_trial_days_remaining()
            color = user.get_trial_status_color().upper()
        elif user.subscription_status == 'active':
            days = user.get_subscription_days_remaining()
            color = 'BLUE'
        else:
            days = 0
            color = 'GRAY'
        
        print(f"{user.email:<30} {user.subscription_status:<15} {days:<12} {color:<10}")

def test_warning_emails(users):
    """Test sending warning emails"""
    print_header("Testing Warning Emails")
    
    print("\nThis will test the email warning system.")
    print("Note: Emails will only be sent if SMTP is configured in .env")
    
    response = input("\nDo you want to test sending warning emails? (y/n): ")
    
    if response.lower() == 'y':
        for user in users:
            if user.subscription_status == 'trial':
                days = user.get_trial_days_remaining()
                if days in [7, 3, 1] or days <= 0:
                    print(f"\nSending warning to {user.email}...")
                    result = send_trial_warning_email(user)
                    if result:
                        print(f"  ✓ Email sent successfully")
                    else:
                        print(f"  ✗ Email failed (check logs)")
    else:
        print("Skipping email test.")

def display_warnings():
    """Display all warning emails sent"""
    print_header("Email Warning Log")
    
    warnings = SubscriptionWarning.objects.all().order_by('-sent_at')[:10]
    
    if warnings:
        print(f"\n{'User':<30} {'Type':<15} {'Sent At':<20} {'Success':<10}")
        print("-" * 80)
        for warning in warnings:
            print(f"{warning.user.email:<30} {warning.warning_type:<15} "
                  f"{warning.sent_at.strftime('%Y-%m-%d %H:%M'):<20} "
                  f"{'✓' if warning.email_sent_successfully else '✗':<10}")
    else:
        print("\nNo warning emails sent yet.")

def display_payment_history():
    """Display payment history"""
    print_header("Payment History")
    
    payments = PaymentHistory.objects.all().order_by('-payment_date')[:10]
    
    if payments:
        print(f"\n{'User':<30} {'Amount':<12} {'Years':<8} {'Date':<20}")
        print("-" * 75)
        for payment in payments:
            print(f"{payment.user.email:<30} ${payment.amount:<11} "
                  f"{payment.subscription_years:<8} "
                  f"{payment.payment_date.strftime('%Y-%m-%d %H:%M'):<20}")
    else:
        print("\nNo payment records yet.")

def test_subscription_check():
    """Test subscription validation"""
    print_header("Testing Subscription Validation")
    
    users = User.objects.filter(role='ProjectManager')[:5]
    
    print(f"\n{'User':<30} {'Valid?':<10} {'Can Edit?':<12}")
    print("-" * 55)
    
    for user in users:
        is_valid = user.is_subscription_valid()
        can_edit = user.can_edit()
        print(f"{user.email:<30} {'✓' if is_valid else '✗':<10} "
              f"{'✓' if can_edit else '✗':<12}")

def cleanup_test_users():
    """Remove test users"""
    print_header("Cleanup")
    
    response = input("\nDo you want to delete test users? (y/n): ")
    
    if response.lower() == 'y':
        test_emails = [
            'trial_green@test.com',
            'trial_yellow@test.com',
            'trial_red@test.com',
            'trial_expired@test.com',
            'paid_user@test.com'
        ]
        
        count = User.objects.filter(email__in=test_emails).delete()[0]
        print(f"✓ Deleted {count} test users")
    else:
        print("Test users kept for review in admin panel.")

def main():
    print_header("Structura Subscription System Test")
    print("\nThis script will test the trial and subscription management system.")
    print("Make sure the Django server is running before proceeding.")
    
    input("\nPress Enter to continue...")
    
    try:
        # Step 1: Create test users
        users = create_test_users()
        
        # Step 2: Display status
        display_user_status(users)
        
        # Step 3: Test subscription validation
        test_subscription_check()
        
        # Step 4: Display warning log
        display_warnings()
        
        # Step 5: Display payment history
        display_payment_history()
        
        # Step 6: Test email warnings (optional)
        test_warning_emails(users)
        
        # Step 7: Cleanup (optional)
        cleanup_test_users()
        
        print_header("Testing Complete!")
        print("\n✓ All tests completed successfully")
        print("\nNext steps:")
        print("1. Access Django Admin: http://127.0.0.1:8000/admin/")
        print("2. Review test users in the Users table")
        print("3. Try the bulk actions and filters")
        print("4. Check the Subscription Warnings table")
        print("5. View Payment History")
        
    except Exception as e:
        print(f"\n✗ Error: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    main()
