"""
Quick Check - Is User Expired?
"""

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'structura_backend.settings')
django.setup()

from app.models import User

email = input("Enter email address: ").strip()

try:
    user = User.objects.get(email=email)
    print(f"\n✓ Found user: {user.email}")
    print(f"  Role: {user.role}")
    print(f"  Subscription Status: {user.subscription_status}")
    
    if user.role == 'ProjectManager':
        print(f"  Is Valid: {user.is_subscription_valid()}")
        print(f"  Can Edit: {user.can_edit()}")
        print(f"  Days Remaining: {user.get_trial_days_remaining()}")
        
        if user.subscription_status == 'expired' or not user.is_subscription_valid():
            print("\n✓ User IS expired - Pop-up SHOULD appear")
        else:
            print("\n✗ User is NOT expired - Pop-up will NOT appear")
            print("\nTo test the pop-up, mark this user as expired:")
            print(f"  In Django Admin: http://127.0.0.1:8000/admin/app/user/{user.user_id}/change/")
            print(f"  Set 'Subscription status' = 'expired'")
    else:
        print(f"\n⚠ User role is '{user.role}' - Only ProjectManagers trigger the pop-up")
        
except User.DoesNotExist:
    print(f"\n✗ User not found: {email}")
    print("\nAvailable users:")
    for u in User.objects.all()[:10]:
        print(f"  {u.email} ({u.role})")
