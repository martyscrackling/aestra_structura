"""
Test Subscription Expiry in Flutter App

This script helps test the subscription expiry pop-up warning.
"""

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'structura_backend.settings')
django.setup()

from django.utils import timezone
from datetime import timedelta
from app.models import User

def create_expired_test_user():
    """
    Creates a test user with expired trial for testing the pop-up warning
    """
    print("="*60)
    print("  Create Expired Test User")
    print("="*60)
    
    email = "test_expired@example.com"
    
    # Check if user already exists
    existing_user = User.objects.filter(email=email).first()
    if existing_user:
        print(f"\n⚠ User {email} already exists!")
        print(f"   User ID: {existing_user.user_id}")
        print("\nUpdating to expired status...")
        user = existing_user
    else:
        print(f"\nCreating new test user: {email}")
        user = User(
            email=email,
            password_hash="test_password_hash",
            first_name="Test",
            last_name="Expired",
            role="ProjectManager",
        )
    
    # Set trial dates to expired
    user.trial_start_date = timezone.now() - timedelta(days=20)
    user.trial_end_date = timezone.now() - timedelta(days=6)  # Expired 6 days ago
    user.subscription_status = 'expired'
    user.subscription_end_date = None
    user.subscription_years = 0
    user.payment_date = None
    user.status = 'Active'
    
    user.save()
    
    print("\n✓ Test user created/updated successfully!")
    print("\nUser Details:")
    print(f"  Email: {user.email}")
    print(f"  User ID: {user.user_id}")
    print(f"  Role: {user.role}")
    print(f"  Status: {user.subscription_status}")
    print(f"  Trial End: {user.trial_end_date}")
    print(f"  Days Remaining: {user.get_trial_days_remaining()}")
    
    print("\n" + "="*60)
    print("  Test Instructions")
    print("="*60)
    print("\n1. Login to the Flutter app with this user:")
    print(f"   Email: {email}")
    print(f"   Password: PASSWORD (or whatever you set)")
    
    print("\n2. Try to create or edit something:")
    print("   - Add a new client")
    print("   - Add a new supervisor/worker")
    print("   - Create a project phase")
    print("   - Update task status (if Supervisor role)")
    
    print("\n3. You should see a pop-up dialog:")
    print("   ⚠️ Subscription Expired")
    print("   Your trial period has expired...")
    
    print("\n4. Verify you CAN still:")
    print("   ✓ View existing data")
    print("   ✓ Navigate the app")
    print("   ✓ Read information")
    
    print("\n5. Verify you CANNOT:")
    print("   ✗ Create new items")
    print("   ✗ Edit existing items")
    print("   ✗ Delete items")
    
    print("\n" + "="*60)
    print("  To Restore Access")
    print("="*60)
    print("\nOption 1: Extend Trial")
    print(f"  python -c \"from app.models import User; u=User.objects.get(user_id={user.user_id}); u.trial_end_date=timezone.now()+timedelta(days=14); u.subscription_status='trial'; u.save()\"")
    
    print("\nOption 2: Activate Subscription")
    print(f"  python -c \"from app.models import User; u=User.objects.get(user_id={user.user_id}); u.subscription_status='active'; u.subscription_start_date=timezone.now(); u.subscription_end_date=timezone.now()+timedelta(days=365); u.subscription_years=1; u.save()\"")
    
    print("\n" + "="*60)
    return user

if __name__ == '__main__':
    create_expired_test_user()
