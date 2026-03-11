"""
Test Email Sending Script
This script tests the SMTP configuration and sends a test email.
"""

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'structura_backend.settings')
django.setup()

from django.core.mail import send_mail
from django.conf import settings

def test_email():
    print("="*60)
    print("  Testing Email Configuration")
    print("="*60)
    print(f"\nSMTP Settings:")
    print(f"  Host: {settings.EMAIL_HOST}")
    print(f"  Port: {settings.EMAIL_PORT}")
    print(f"  User: {settings.EMAIL_HOST_USER}")
    print(f"  TLS: {settings.EMAIL_USE_TLS}")
    print(f"  From: {settings.DEFAULT_FROM_EMAIL}")
    
    recipient = input("\nEnter test email address to send to: ").strip()
    
    if not recipient:
        print("No email address provided. Exiting.")
        return
    
    print(f"\nAttempting to send test email to: {recipient}")
    print("Please wait...\n")
    
    try:
        result = send_mail(
            subject='Test Email from Structura Admin',
            message='This is a test email to verify SMTP configuration is working correctly.',
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[recipient],
            fail_silently=False,
        )
        
        if result:
            print("✓ SUCCESS! Test email sent successfully!")
            print(f"✓ Check the inbox of {recipient}")
            print("✓ Also check spam/junk folder if not in inbox")
        else:
            print("✗ FAILED! Email was not sent (no exception but result was 0)")
            
    except Exception as e:
        print("✗ ERROR! Failed to send email:")
        print(f"   Error type: {type(e).__name__}")
        print(f"   Error message: {str(e)}")
        print("\nCommon issues and solutions:")
        print("\n1. Gmail 'Less secure app access' is deprecated")
        print("   Solution: Use an 'App Password' instead of your regular password")
        print("   Steps:")
        print("     a. Go to https://myaccount.google.com/security")
        print("     b. Enable 2-Step Verification first")
        print("     c. Then go to 'App passwords'")
        print("     d. Generate a new app password for 'Mail'")
        print("     e. Update EMAIL_HOST_PASSWORD in .env with the app password")
        print("\n2. Authentication failed")
        print("   - Check EMAIL_HOST_USER matches the account")
        print("   - Verify EMAIL_HOST_PASSWORD is correct")
        print("\n3. Connection refused/timeout")
        print("   - Check firewall settings")
        print("   - Verify EMAIL_HOST and EMAIL_PORT are correct")
        print("   - Try EMAIL_PORT: 465 with EMAIL_USE_SSL instead of TLS")

if __name__ == '__main__':
    test_email()
