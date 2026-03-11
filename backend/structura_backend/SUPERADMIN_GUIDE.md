# Structura SuperAdmin Dashboard Guide

## Quick Start

### 1. Access the Admin Panel
- URL: **http://127.0.0.1:8000/admin/**
- Login with your superuser credentials

### 2. Managing Users & Subscriptions

#### View Users
1. Click **Users** in the admin panel
2. You'll see all users with color-coded trial status:
   - 🟢 **Green**: More than 7 days remaining
   - 🟡 **Yellow**: 3-7 days remaining  
   - 🔴 **Red**: Less than 3 days remaining
   - ⚫ **Gray**: Trial expired

#### Filter Users
Use the right sidebar filters:
- **Trial Expiring Soon**: Expiring in 7/3/1 days
- **Subscription Status**: Active Trial / Active Paid / Expired
- **Role**: ProjectManager / Supervisor / Client
- **Email Warning Flags**: See which users have been notified

#### Bulk Actions
Select multiple users and use the "Action" dropdown:
- **Send trial warning emails**: Send warning emails to selected users
- **Extend trial by 7 days**: Give users more time
- **Extend trial by 14 days**: Extend for 2 weeks
- **Activate 1-year subscription**: Grant paid access
- **Mark as expired**: Manually expire subscriptions

### 3. Manage Individual Users

Click on any user to see detailed information:

#### Trial & Subscription Section
- **Subscription Status**: trial / active / expired
- **Trial Start/End Dates**: When trial period began and ends
- **Trial Days Remaining**: Visual indicator with color coding
- **Subscription Dates**: For paid users
- **Subscription Years**: Number of years paid for
- **Payment Date**: When payment was received

#### Actions You Can Take
1. **Extend Trial**: Manually edit `trial_end_date`
2. **Activate Subscription**: 
   - Set `subscription_status` to "active"
   - Set `subscription_start_date` to today
   - Set `subscription_end_date` to 1 year from now
   - Set `subscription_years` to 1 (or more)
   - Set `payment_date` to today
3. **Mark as Expired**: Set `subscription_status` to "expired"

### 4. View Email Communications

#### Subscription Warnings Table
Click **Subscription warnings** to see all warning emails sent:
- User email
- Warning type (7 days / 3 days / 1 day / expired)
- Sent timestamp
- Success status
- Error messages (if failed)

#### Payment History Table
Click **Payment histories** to see all payment records:
- User
- Amount paid
- Subscription years
- Payment date
- Payment status (pending / completed / failed)
- Notes

### 5. Automated Email Warnings

The system automatically sends email warnings at:
- **7 days** before trial expiration
- **3 days** before trial expiration
- **1 day** before trial expiration
- **On expiration day**

#### Run Manual Check
To manually check trials and send warnings:
```bash
cd backend\structura_backend
python manage.py check_trials
```

To force resend warnings (useful for testing):
```bash
python manage.py check_trials --force
```

### 6. Email Configuration

Email settings are configured in `.env` file:

```env
# Email delivery
DEFAULT_FROM_EMAIL=riaguanzon2@gmail.com
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=riaguanzon2@gmail.com
EMAIL_HOST_PASSWORD=efzidfhnfrxxlawo
EMAIL_USE_TLS=1
```

**Note**: Make sure your Gmail account has "App Passwords" enabled for SMTP access.

### 7. Schedule Automated Checks

#### Option 1: Windows Task Scheduler
1. Open **Task Scheduler**
2. Create Basic Task
3. Name: "Structura Trial Check"
4. Trigger: Daily at 9:00 AM
5. Action: Start a program
6. Program: `C:\Users\Administrator\AppData\Local\Programs\Python\Python310\python.exe`
7. Arguments: `manage.py check_trials`
8. Start in: `C:\Users\Administrator\aestra_structura\backend\structura_backend`

#### Option 2: Manual Daily Run
Run this command daily:
```bash
cd backend\structura_backend
python manage.py check_trials
```

### 8. API Endpoints for Frontend Integration

#### Check Subscription Status
```
GET /api/subscription/check/?user_id=<user_id>

Response:
{
  "success": true,
  "user_id": 1,
  "email": "user@example.com",
  "subscription_status": "trial",
  "is_subscription_valid": true,
  "can_edit": true,
  "can_create": true,
  "trial_days_remaining": 10,
  "trial_status_color": "green"
}
```

#### Activate Subscription (Admin Only)
```
POST /api/subscription/activate/

Body:
{
  "user_id": 1,
  "subscription_years": 1,
  "amount": 5000
}

Response:
{
  "success": true,
  "message": "Subscription activated successfully",
  "subscription_end_date": "2027-03-06T...",
  "subscription_years": 1
}
```

### 9. Access Control Rules

#### For Expired Users:
- ✅ **CAN**: View/read data (GET requests)
- ❌ **CANNOT**: Create, edit, or delete (POST/PUT/PATCH/DELETE)

#### When Blocked:
Users receive a 403 error with message:
```json
{
  "success": false,
  "error": "subscription_expired",
  "message": "Your subscription has expired. You can view data but cannot create or edit content. Please renew your subscription to continue.",
  "subscription_status": "expired"
}
```

#### SuperAdmin Bypasses:
SuperAdmin users bypass ALL subscription checks and have unlimited access.

### 10. User Hierarchy Impact

**Important**: When a ProjectManager's trial expires:
- ✅ Their account is marked as expired
- ✅ All Supervisors under that ProjectManager are affected
- ✅ All Clients under that ProjectManager are affected
- ❌ They cannot create/edit projects, workforce, or clients
- ✅ They can still view their existing data

### 11. Subscription Plans

Default plan: **1 Year Subscription**
- **Duration**: 365 days
- **Advance Payment**: Users can pay for multiple years
  - Example: Pay for 3 years = 3 × 365 = 1,095 days

To activate multi-year subscription:
1. Go to user in admin panel
2. Set `subscription_years` to desired number (e.g., 3)
3. Calculate end date: start_date + (365 × years)
4. Set `subscription_end_date` accordingly

### 12. Troubleshooting

#### Emails Not Sending?
1. Check `.env` email settings
2. Verify Gmail "App Passwords" is enabled
3. Check "Subscription warnings" table for error messages
4. Run `python manage.py check_trials --force` to test

#### User Can't Edit?
1. Check user's `subscription_status`
2. Verify `trial_end_date` or `subscription_end_date`
3. Check if trial/subscription is still valid
4. Look for middleware blocks in server logs

#### Dashboard Not Showing Stats?
1. Refresh the page
2. Check if there are users with trials
3. Verify database connection
4. Check browser console for errors

### 13. Daily Admin Workflow

**Morning (9 AM)**:
1. Run `python manage.py check_trials` (or automated)
2. Review "Subscription warnings" for sent emails
3. Check filter "Expiring in 7 days" for upcoming expirations

**When Payment Received**:
1. Find user in Users table
2. Click user to edit
3. Scroll to "Trial & Subscription" section
4. Update:
   - `subscription_status` = "active"
   - `subscription_start_date` = today
   - `subscription_end_date` = 1 year from today
   - `subscription_years` = 1 (or more)
   - `payment_date` = today
5. Add entry in "Payment History" inline form:
   - Amount
   - Subscription years
   - Payment status = "completed"
   - Notes (optional)
6. Click "Save"

**Weekly Review**:
1. Use filter "Trial Expiring Soon" → "Expiring in 7 days"
2. Review users approaching expiration
3. Consider sending personalized follow-up emails
4. Check "Active Paid" users for renewal reminders (30 days before end)

### 14. Email Templates

All email templates are professional HTML with:
- Structura branding
- Color-coded urgency indicators
- Clear call-to-action buttons
- Subscription benefits list
- Responsive design for mobile

Templates are defined in: `app/utils.py`

### 15. Reports & Analytics

**Summary Cards** (coming soon):
- Total users in trial
- Trials ending in next 7 days
- Active paid users
- Expired/overdue accounts

**Export Functionality** (current):
- Use Django admin's list page
- Select users
- Action: Export as CSV (Django default)

---

## Quick Reference Commands

```bash
# Create superuser
python manage.py createsuperuser

# Run migrations
python manage.py migrate

# Check trials and send warnings
python manage.py check_trials

# Force resend all warnings (testing)
python manage.py check_trials --force

# Start development server
python manage.py runserver

# Access admin panel
http://127.0.0.1:8000/admin/
```

---

## Support

For questions or issues, refer to:
- Django admin documentation: https://docs.djangoproject.com/en/5.2/ref/contrib/admin/
- Project README.md
- Contact development team

---

**Last Updated**: March 6, 2026
