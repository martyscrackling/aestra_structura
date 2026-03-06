"""
Quick Email Test - Tests if SMTP connection and email sending works
"""

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'structura_backend.settings')
django.setup()

from django.core.mail import send_mail
from django.conf import settings

def test_email_send():
    print("="*60)
    print("  Quick Email SMTP Test")
    print("="*60)
    print(f"\nSMTP Config:")
    print(f"  Host: {settings.EMAIL_HOST}")
    print(f"  Port: {settings.EMAIL_PORT}")
    print(f"  User: {settings.EMAIL_HOST_USER}")
    print(f"  TLS: {settings.EMAIL_USE_TLS}")
    
    # Send to the same email address for testing
    test_recipient = settings.EMAIL_HOST_USER  # Send to yourself
    
    print(f"\nSending test email to: {test_recipient}")
    print("Please wait...\n")
    
    try:
        result = send_mail(
            subject='Structura Admin - Email Test',
            message='This is a test email from Structura admin system. If you receive this, your email configuration is working correctly!',
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[test_recipient],
            fail_silently=False,
        )
        
        if result == 1:
            print("✓ SUCCESS! Test email sent successfully!")
            print(f"✓ Check the inbox of {test_recipient}")
            print("✓ Also check spam/junk folder\n")
            return True
        else:
            print(f"✗ FAILED! send_mail returned {result} instead of 1\n")
            return False
            
    except Exception as e:
        print("✗ ERROR! Failed to send email:")
        print(f"   Type: {type(e).__name__}")
        print(f"   Message: {str(e)}\n")
        
        # Check common issues
        if 'authentication' in str(e).lower() or 'password' in str(e).lower():
            print("⚠ Authentication Issue Detected:")
            print("  The Gmail password might be incorrect or you need an App Password")
            print("\n  Gmail App Password Setup:")
            print("  1. Go to https://myaccount.google.com/security")
            print("  2. Enable 2-Step Verification (if not already enabled)")
            print("  3. Go to 'App passwords': https://myaccount.google.com/apppasswords")
            print("  4. Create a new app password for 'Mail'")
            print("  5. Update EMAIL_HOST_PASSWORD in your .env file with the new app password")
            print("  6. Restart the Django server\n")
        
        return False

if __name__ == '__main__':
    test_email_send()
