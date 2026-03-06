from django.core.mail import send_mail
from django.template.loader import render_to_string
from django.utils.html import strip_tags
from django.conf import settings
from .models import SubscriptionWarning
import logging

logger = logging.getLogger(__name__)


def send_trial_warning_email(user, force_send=False):
    """
    Send trial warning email based on days remaining
    
    Args:
        user: User object to send email to
        force_send: If True, bypasses the "already sent" check (for manual admin actions)
    """
    days_remaining = user.get_trial_days_remaining()
    
    # Determine warning type
    if days_remaining == 7:
        warning_type = '7_days'
        if user.warning_7days_sent and not force_send:
            return False
    elif days_remaining == 3:
        warning_type = '3_days'
        if user.warning_3days_sent and not force_send:
            return False
    elif days_remaining == 1:
        warning_type = '1_day'
        if user.warning_1day_sent and not force_send:
            return False
    elif days_remaining <= 0:
        warning_type = 'expired'
    else:
        # For force_send (manual admin action), send even if not at threshold
        if not force_send:
            return False
        # Determine best warning type for current days
        if days_remaining >= 7:
            warning_type = '7_days'
        elif days_remaining >= 3:
            warning_type = '3_days'
        else:
            warning_type = '1_day'
    
    # Prepare email context
    context = {
        'user': user,
        'days_remaining': days_remaining,
        'trial_end_date': user.trial_end_date.strftime('%B %d, %Y'),
        'app_name': getattr(settings, 'APP_NAME', 'Structura'),
        'frontend_url': getattr(settings, 'FRONTEND_URL', 'https://martyscrackling.github.io/aestra_structura'),
    }
    
    # Generate email subject
    if days_remaining > 0:
        subject = f'Your {getattr(settings, "APP_NAME", "Structura")} Trial Expires in {days_remaining} Day{"s" if days_remaining != 1 else ""}'
    else:
        subject = f'Your {getattr(settings, "APP_NAME", "Structura")} Trial Has Expired'
    
    # Generate email body
    html_message = generate_trial_warning_html(context, warning_type)
    plain_message = strip_tags(html_message)
    
    # Send email
    try:
        send_mail(
            subject=subject,
            message=plain_message,
            from_email=getattr(settings, 'DEFAULT_FROM_EMAIL', 'noreply@structura.com'),
            recipient_list=[user.email],
            html_message=html_message,
            fail_silently=False,
        )
        
        # Log successful send
        SubscriptionWarning.objects.create(
            user=user,
            warning_type=warning_type,
            email_sent_successfully=True
        )
        
        # Update user warning flags
        if warning_type == '7_days':
            user.warning_7days_sent = True
        elif warning_type == '3_days':
            user.warning_3days_sent = True
        elif warning_type == '1_day':
            user.warning_1day_sent = True
        user.save()
        
        logger.info(f"Trial warning email sent to {user.email} ({warning_type})")
        return True
        
    except Exception as e:
        # Log failed send
        SubscriptionWarning.objects.create(
            user=user,
            warning_type=warning_type,
            email_sent_successfully=False,
            error_message=str(e)
        )
        logger.error(f"Failed to send trial warning email to {user.email}: {str(e)}")
        return False


def generate_trial_warning_html(context, warning_type):
    """
    Generate HTML email for trial warnings
    """
    user = context['user']
    days_remaining = context['days_remaining']
    trial_end_date = context['trial_end_date']
    app_name = context['app_name']
    frontend_url = context['frontend_url']
    
    if days_remaining > 0:
        # Warning email (7, 3, or 1 day)
        html = f"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Trial Expiring Soon</title>
        </head>
        <body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f4f4f4;">
            <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f4f4; padding: 20px;">
                <tr>
                    <td align="center">
                        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                            <!-- Header -->
                            <tr>
                                <td style="background: linear-gradient(135deg, #0A173D 0%, #FF6B2C 100%); padding: 30px; border-radius: 8px 8px 0 0; text-align: center;">
                                    <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold;">{app_name}</h1>
                                </td>
                            </tr>
                            
                            <!-- Content -->
                            <tr>
                                <td style="padding: 40px 30px;">
                                    <h2 style="color: #0A173D; margin: 0 0 20px 0; font-size: 24px;">Your Trial is Expiring Soon</h2>
                                    
                                    <p style="color: #333333; font-size: 16px; line-height: 1.6; margin: 0 0 20px 0;">
                                        Hi {user.first_name or 'there'},
                                    </p>
                                    
                                    <div style="background-color: {'#fff3cd' if days_remaining > 3 else '#f8d7da'}; border-left: 4px solid {'#ffc107' if days_remaining > 3 else '#dc3545'}; padding: 15px; margin: 20px 0;">
                                        <p style="color: #333333; font-size: 18px; margin: 0; font-weight: bold;">
                                            Your trial expires in {days_remaining} day{"s" if days_remaining != 1 else ""}!
                                        </p>
                                        <p style="color: #666666; font-size: 14px; margin: 10px 0 0 0;">
                                            Trial End Date: {trial_end_date}
                                        </p>
                                    </div>
                                    
                                    <p style="color: #333333; font-size: 16px; line-height: 1.6; margin: 20px 0;">
                                        Don't lose access to your construction management tools! Subscribe now to continue managing your projects, workforce, and clients without interruption.
                                    </p>
                                    
                                    <div style="margin: 30px 0; text-align: center;">
                                        <a href="{frontend_url}/license" style="background: linear-gradient(135deg, #FF6B2C 0%, #FF8C5A 100%); color: #ffffff; padding: 15px 40px; text-decoration: none; border-radius: 6px; font-size: 16px; font-weight: bold; display: inline-block;">
                                            Subscribe Now
                                        </a>
                                    </div>
                                    
                                    <div style="background-color: #f8f9fa; border-radius: 6px; padding: 20px; margin: 20px 0;">
                                        <h3 style="color: #0A173D; margin: 0 0 15px 0; font-size: 18px;">Subscription Benefits:</h3>
                                        <ul style="color: #333333; font-size: 14px; line-height: 1.8; margin: 0; padding-left: 20px;">
                                            <li>Unlimited project management</li>
                                            <li>Workforce tracking and attendance</li>
                                            <li>Client management portal</li>
                                            <li>Real-time progress reports</li>
                                            <li>Inventory management</li>
                                            <li>Priority support</li>
                                        </ul>
                                    </div>
                                    
                                    <p style="color: #666666; font-size: 14px; line-height: 1.6; margin: 20px 0 0 0;">
                                        If you have any questions or need assistance, please don't hesitate to contact our support team.
                                    </p>
                                </td>
                            </tr>
                            
                            <!-- Footer -->
                            <tr>
                                <td style="background-color: #f8f9fa; padding: 20px 30px; border-radius: 0 0 8px 8px; text-align: center;">
                                    <p style="color: #666666; font-size: 12px; line-height: 1.6; margin: 0;">
                                        © 2026 {app_name}. All rights reserved.<br>
                                        This is an automated message. Please do not reply to this email.
                                    </p>
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>
            </table>
        </body>
        </html>
        """
    else:
        # Expired email
        html = f"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Trial Expired</title>
        </head>
        <body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f4f4f4;">
            <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f4f4; padding: 20px;">
                <tr>
                    <td align="center">
                        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                            <!-- Header -->
                            <tr>
                                <td style="background: linear-gradient(135deg, #0A173D 0%, #FF6B2C 100%); padding: 30px; border-radius: 8px 8px 0 0; text-align: center;">
                                    <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold;">{app_name}</h1>
                                </td>
                            </tr>
                            
                            <!-- Content -->
                            <tr>
                                <td style="padding: 40px 30px;">
                                    <h2 style="color: #0A173D; margin: 0 0 20px 0; font-size: 24px;">Your Trial Has Expired</h2>
                                    
                                    <p style="color: #333333; font-size: 16px; line-height: 1.6; margin: 0 0 20px 0;">
                                        Hi {user.first_name or 'there'},
                                    </p>
                                    
                                    <div style="background-color: #f8d7da; border-left: 4px solid #dc3545; padding: 15px; margin: 20px 0;">
                                        <p style="color: #721c24; font-size: 18px; margin: 0; font-weight: bold;">
                                            Your trial period has ended.
                                        </p>
                                        <p style="color: #666666; font-size: 14px; margin: 10px 0 0 0;">
                                            Trial Ended: {trial_end_date}
                                        </p>
                                    </div>
                                    
                                    <p style="color: #333333; font-size: 16px; line-height: 1.6; margin: 20px 0;">
                                        You can still view your data, but editing and creating new content is now disabled. Subscribe now to regain full access to all features!
                                    </p>
                                    
                                    <div style="margin: 30px 0; text-align: center;">
                                        <a href="{frontend_url}/license" style="background: linear-gradient(135deg, #FF6B2C 0%, #FF8C5A 100%); color: #ffffff; padding: 15px 40px; text-decoration: none; border-radius: 6px; font-size: 16px; font-weight: bold; display: inline-block;">
                                            Subscribe Now
                                        </a>
                                    </div>
                                    
                                    <p style="color: #666666; font-size: 14px; line-height: 1.6; margin: 20px 0 0 0;">
                                        Questions? Contact our support team for assistance.
                                    </p>
                                </td>
                            </tr>
                            
                            <!-- Footer -->
                            <tr>
                                <td style="background-color: #f8f9fa; padding: 20px 30px; border-radius: 0 0 8px 8px; text-align: center;">
                                    <p style="color: #666666; font-size: 12px; line-height: 1.6; margin: 0;">
                                        © 2026 {app_name}. All rights reserved.<br>
                                        This is an automated message. Please do not reply to this email.
                                    </p>
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>
            </table>
        </body>
        </html>
        """
    
    return html


def send_subscription_activated_email(user):
    """
    Send email when subscription is activated
    """
    context = {
        'user': user,
        'subscription_end_date': user.subscription_end_date.strftime('%B %d, %Y') if user.subscription_end_date else 'N/A',
        'subscription_years': user.subscription_years,
        'app_name': getattr(settings, 'APP_NAME', 'Structura'),
        'frontend_url': getattr(settings, 'FRONTEND_URL', 'https://martyscrackling.github.io/aestra_structura'),
    }
    
    subject = f'Welcome to {getattr(settings, "APP_NAME", "Structura")} - Subscription Activated!'
    
    html_message = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Subscription Activated</title>
    </head>
    <body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f4f4f4;">
        <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f4f4; padding: 20px;">
            <tr>
                <td align="center">
                    <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                        <!-- Header -->
                        <tr>
                            <td style="background: linear-gradient(135deg, #28a745 0%, #20c997 100%); padding: 30px; border-radius: 8px 8px 0 0; text-align: center;">
                                <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold;">🎉 Subscription Activated!</h1>
                            </td>
                        </tr>
                        
                        <!-- Content -->
                        <tr>
                            <td style="padding: 40px 30px;">
                                <p style="color: #333333; font-size: 16px; line-height: 1.6; margin: 0 0 20px 0;">
                                    Hi {user.first_name or 'there'},
                                </p>
                                
                                <p style="color: #333333; font-size: 16px; line-height: 1.6; margin: 0 0 20px 0;">
                                    Thank you for subscribing to {context['app_name']}! Your subscription is now active.
                                </p>
                                
                                <div style="background-color: #d4edda; border-left: 4px solid #28a745; padding: 15px; margin: 20px 0;">
                                    <p style="color: #155724; font-size: 18px; margin: 0; font-weight: bold;">
                                        Your subscription is valid until {context['subscription_end_date']}
                                    </p>
                                    <p style="color: #155724; font-size: 14px; margin: 10px 0 0 0;">
                                        Subscription Period: {context['subscription_years']} year{"s" if context['subscription_years'] != 1 else ""}
                                    </p>
                                </div>
                                
                                <p style="color: #333333; font-size: 16px; line-height: 1.6; margin: 20px 0;">
                                    You now have full access to all premium features!
                                </p>
                                
                                <div style="margin: 30px 0; text-align: center;">
                                    <a href="{context['frontend_url']}" style="background: linear-gradient(135deg, #FF6B2C 0%, #FF8C5A 100%); color: #ffffff; padding: 15px 40px; text-decoration: none; border-radius: 6px; font-size: 16px; font-weight: bold; display: inline-block;">
                                        Go to Dashboard
                                    </a>
                                </div>
                            </td>
                        </tr>
                        
                        <!-- Footer -->
                        <tr>
                            <td style="background-color: #f8f9fa; padding: 20px 30px; border-radius: 0 0 8px 8px; text-align: center;">
                                <p style="color: #666666; font-size: 12px; line-height: 1.6; margin: 0;">
                                    © 2026 {context['app_name']}. All rights reserved.
                                </p>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>
        </table>
    </body>
    </html>
    """
    
    plain_message = strip_tags(html_message)
    
    try:
        send_mail(
            subject=subject,
            message=plain_message,
            from_email=getattr(settings, 'DEFAULT_FROM_EMAIL', 'noreply@structura.com'),
            recipient_list=[user.email],
            html_message=html_message,
            fail_silently=False,
        )
        logger.info(f"Subscription activated email sent to {user.email}")
        return True
    except Exception as e:
        logger.error(f"Failed to send subscription activated email to {user.email}: {str(e)}")
        return False
