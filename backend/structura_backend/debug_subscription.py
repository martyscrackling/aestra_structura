"""
Debug Subscription Status - Check User and Test API
"""

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'structura_backend.settings')
django.setup()

from app.models import User
from django.utils import timezone

def check_user_subscription():
    print("="*70)
    print("  DEBUG SUBSCRIPTION STATUS")
    print("="*70)
    
    email = input("\nEnter the email address you're testing with: ").strip()
    
    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        print(f"\n✗ ERROR: User with email '{email}' not found!")
        print("\nAvailable ProjectManager users:")
        for u in User.objects.filter(role='ProjectManager')[:10]:
            print(f"  - {u.email} (ID: {u.user_id})")
        return
    
    print(f"\n✓ User found: {user.email}")
    print("\n" + "-"*70)
    print("USER DETAILS:")
    print("-"*70)
    print(f"  User ID: {user.user_id}")
    print(f"  Name: {user.first_name} {user.last_name}")
    print(f"  Role: {user.role}")
    print(f"  Status: {user.status}")
    
    print("\n" + "-"*70)
    print("SUBSCRIPTION STATUS:")
    print("-"*70)
    print(f"  Subscription Status: {user.subscription_status}")
    print(f"  Trial Start: {user.trial_start_date}")
    print(f"  Trial End: {user.trial_end_date}")
    print(f"  Subscription End: {user.subscription_end_date}")
    
    if user.role == 'ProjectManager':
        days_remaining = user.get_trial_days_remaining()
        print(f"  Days Remaining: {days_remaining}")
        print(f"  Status Color: {user.get_trial_status_color()}")
        print(f"  Is Valid: {user.is_subscription_valid()}")
        print(f"  Can Edit: {user.can_edit()}")
    
    print("\n" + "-"*70)
    print("MIDDLEWARE CHECK:")
    print("-"*70)
    
    if user.role != 'ProjectManager':
        print(f"  ⚠ User role is '{user.role}' - Middleware only applies to ProjectManagers!")
        print("  Supervisors and Clients inherit restrictions from their ProjectManager")
    elif user.subscription_status == 'expired':
        print("  ✓ Status is 'expired' - Middleware WILL block write operations")
    elif user.subscription_status == 'trial':
        if user.trial_end_date and user.trial_end_date <= timezone.now():
            print("  ⚠ Status is 'trial' but trial_end_date has passed!")
            print("  ⚠ User should be marked as expired. Run: python manage.py check_trials")
        else:
            print(f"  ✓ Status is 'trial' and trial is active ({days_remaining} days remaining)")
            print("  ✗ Middleware will NOT block (trial is still valid)")
    elif user.subscription_status == 'active':
        print("  ✓ Status is 'active' - Middleware will NOT block")
    
    print("\n" + "-"*70)
    print("RECOMMENDED ACTIONS:")
    print("-"*70)
    
    if user.role != 'ProjectManager':
        print("\n  1. Test with a ProjectManager account instead")
        print("  2. Or check the ProjectManager that this user belongs to")
    elif user.subscription_status != 'expired':
        if user.trial_end_date and user.trial_end_date <= timezone.now():
            print("\n  1. Run the check_trials command to mark user as expired:")
            print("     python manage.py check_trials")
        else:
            print("\n  1. To test the pop-up, manually set this user to expired:")
            print("\n     Option A: Via Django Admin")
            print("       - Go to http://127.0.0.1:8000/admin/")
            print(f"       - Find user: {email}")
            print("       - Set 'Subscription status' to 'expired'")
            print("       - Set 'Trial end date' to yesterday")
            print("       - Click Save")
            print("\n     Option B: Via Python command")
            print(f"       python -c \"from app.models import User; from django.utils import timezone; from datetime import timedelta; u=User.objects.get(user_id={user.user_id}); u.trial_end_date=timezone.now()-timedelta(days=1); u.subscription_status='expired'; u.save(); print('✓ User marked as expired')\"")
    else:
        print("\n  ✓ User is properly configured as expired")
        print("\n  If pop-up still doesn't appear, check:")
        print("    1. Is the Django server running? (http://127.0.0.1:8000/)")
        print("    2. Did you hot-reload/restart the Flutter app?")
        print("    3. Are you testing POST/PUT/PATCH/DELETE operations (not GET)?")
        print("    4. Check browser console for JavaScript errors")
    
    print("\n" + "="*70)
    print("  TEST API CALL")
    print("="*70)
    
    test = input("\nWould you like to test the API directly? (y/n): ").strip().lower()
    if test == 'y':
        print("\nTesting POST request to /api/clients/ endpoint...")
        print("This simulates creating a new client.\n")
        
        import requests
        import json
        
        test_data = {
            'user_id': user.user_id,
            'first_name': 'Test',
            'last_name': 'Client',
            'email': f'test_client_{user.user_id}@example.com',
            'password_hash': 'test123',
        }
        
        try:
            response = requests.post(
                'http://127.0.0.1:8000/api/clients/',
                headers={'Content-Type': 'application/json'},
                json=test_data,
                timeout=5
            )
            
            print(f"Status Code: {response.status_code}")
            print(f"Response Body:\n{json.dumps(response.json(), indent=2)}")
            
            if response.status_code == 403:
                data = response.json()
                if data.get('error') == 'subscription_expired':
                    print("\n✓ SUCCESS! Backend is correctly returning subscription_expired error")
                    print("✓ The Flutter app should show the pop-up dialog")
                    print("\nIf pop-up still doesn't appear in Flutter:")
                    print("  1. Make sure you hot-restarted the Flutter app (not just hot-reload)")
                    print("  2. Check if subscription_helper.dart is imported in the file")
                    print("  3. Check browser console for errors (F12 in Chrome)")
                else:
                    print(f"\n⚠ Got 403 but error is: {data.get('error')}")
            elif response.status_code == 201 or response.status_code == 200:
                print("\n✗ PROBLEM: Request succeeded when it should be blocked!")
                print("✗ The middleware is not working correctly")
                print("\nCheck:")
                print("  1. Is SubscriptionMiddleware in settings.MIDDLEWARE?")
                print("  2. Is the Django server running the latest code?")
            else:
                print(f"\n⚠ Unexpected status code: {response.status_code}")
                
        except requests.exceptions.ConnectionError:
            print("\n✗ ERROR: Cannot connect to http://127.0.0.1:8000/")
            print("✗ Is the Django server running?")
            print("\nStart server with:")
            print("  python manage.py runserver")
        except Exception as e:
            print(f"\n✗ ERROR: {e}")
    
    print("\n" + "="*70)

if __name__ == '__main__':
    check_user_subscription()
