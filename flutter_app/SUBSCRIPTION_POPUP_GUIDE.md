# Subscription Expiry Pop-up Warning - Implementation Guide

## Overview

When a user's trial or subscription expires, they can still view data but cannot create or edit anything. If they attempt to make changes, they will receive a pop-up warning dialog explaining their subscription has expired.

## Backend (Django) - Already Implemented ✅

The backend middleware returns a **403 Forbidden** response with this JSON structure:

```json
{
  "success": false,
  "error": "subscription_expired",
  "message": "Your subscription has expired. You can view data but cannot create or edit content. Please renew your subscription to continue.",
  "subscription_status": "expired"
}
```

This happens automatically for any POST/PUT/PATCH/DELETE request from expired users.

## Flutter Implementation ✅

### 1. Subscription Helper Service

Created: `lib/services/subscription_helper.dart`

This service provides three main functions:

#### a) Check if Response is Subscription Error
```dart
bool isExpired = SubscriptionHelper.isSubscriptionExpired(response);
```

#### b) Show Subscription Expired Dialog
```dart
SubscriptionHelper.showSubscriptionExpiredDialog(context, customMessage: 'Optional custom message');
```

#### c) Handle Response Automatically
```dart
// Returns true if subscription error was handled, false otherwise
if (SubscriptionHelper.handleResponse(context, response)) {
  // Subscription error was shown, stop processing
  return;
}
```

### 2. Updated Files

The following files have been updated to show subscription expiry dialogs:

#### Project Manager Files:
- ✅ `lib/projectmanager/modals/add_client_modal.dart` - Creating clients
- ✅ `lib/projectmanager/modals/add_worker_modal.dart` - Creating supervisors
- ✅ `lib/projectmanager/modals/add_fieldworker_modal.dart` - Creating field workers
- ✅ `lib/projectmanager/modals/phase_modal.dart` - Creating project phases
- ✅ `lib/projectmanager/widgets/manage_workers.dart` - Assigning/removing workers

#### Client Files:
- ✅ `lib/client/cl_settings.dart` - Updating profile

#### Supervisor Files:
- ✅ `lib/supervisor/task_progress.dart` - Updating task status
- ✅ `lib/supervisor/attendance_page.dart` - Marking attendance

## Usage Example

### Before (Old Code):
```dart
final response = await http.post(
  AppConfig.apiUri('clients/'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode(clientData),
);

if (response.statusCode == 201 || response.statusCode == 200) {
  // Success
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Client added successfully!')),
  );
} else {
  // Error
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: Failed')),
  );
}
```

### After (New Code with Subscription Check):
```dart
final response = await http.post(
  AppConfig.apiUri('clients/'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode(clientData),
);

if (!mounted) return;

// Check for subscription expiry FIRST
if (SubscriptionHelper.handleResponse(context, response)) {
  setState(() {
    _isLoading = false;
  });
  return; // Stop processing, dialog is shown
}

if (response.statusCode == 201 || response.statusCode == 200) {
  // Success
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Client added successfully!')),
  );
} else {
  // Other errors
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: Failed')),
  );
}
```

## The Dialog

When a subscription error is detected, users see:

```
⚠️ Subscription Expired

Your trial period has expired. To continue creating and editing 
content, please subscribe to our service.

┌────────────────────────────────────────┐
│ ✓ You can still view your data         │
│ ✗ Creating and editing is disabled     │
└────────────────────────────────────────┘

Contact your administrator to renew your subscription.

                                [   OK   ]
```

### Dialog Features:
- ⚠️ Warning icon with orange color
- Clear explanation of the issue
- Visual indicators showing what's allowed/blocked
- Professional, branded design
- Must be dismissed by user (not dismissible by tapping outside)
- Matches Flutter Material Design guidelines

## Adding to New API Calls

When creating new API calls that perform create/update/delete operations:

1. **Import the helper:**
   ```dart
   import '../services/subscription_helper.dart';
   ```

2. **Check response after API call:**
   ```dart
   final response = await http.post(...);
   
   if (!mounted) return;
   
   // Add this check
   if (SubscriptionHelper.handleResponse(context, response)) {
     return;
   }
   
   // Continue with normal success/error handling
   ```

## Alternative: Using makeApiCall Wrapper

For cleaner code, you can use the wrapper function:

```dart
final success = await SubscriptionHelper.makeApiCall(
  context,
  () async {
    return await http.post(
      AppConfig.apiUri('clients/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(clientData),
    );
  },
  onSuccess: (response) {
    // Handle success
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Client added successfully!')),
    );
  },
  onError: (errorMessage) {
    // Handle error
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $errorMessage')),
    );
  },
);
```

## Backend Configuration

The backend middleware automatically blocks expired users from:
- POST (create)
- PUT (full update)
- PATCH (partial update)
- DELETE (remove)

But allows:
- GET (read/view)
- HEAD (header info)
- OPTIONS (CORS preflight)

## Testing

### Test Subscription Expiry:

1. **Create a test user with expired trial:**
   - Go to Django admin: http://127.0.0.1:8000/admin/
   - Find a ProjectManager user
   - Set `trial_end_date` to yesterday
   - Set `subscription_status` to "expired"
   - Save

2. **Test in the app:**
   - Login as that user
   - Try to create a new client/worker/phase
   - You should see the subscription expired dialog

3. **Verify read access:**
   - Navigate around the app
   - View existing projects, clients, workers
   - Should work normally

4. **Restore access:**
   - Back in Django admin
   - Either: Extend trial (set future `trial_end_date`)
   - Or: Activate subscription (set status to "active" and future `subscription_end_date`)
   - User can immediately create/edit again

## Files Changed

### New Files:
- `lib/services/subscription_helper.dart` - Subscription error handling service

### Modified Files:
- `lib/projectmanager/modals/add_client_modal.dart`
- `lib/projectmanager/modals/add_worker_modal.dart`
- `lib/projectmanager/modals/add_fieldworker_modal.dart`
- `lib/projectmanager/modals/phase_modal.dart`
- `lib/projectmanager/widgets/manage_workers.dart`
- `lib/client/cl_settings.dart`
- `lib/supervisor/task_progress.dart`
- `lib/supervisor/attendance_page.dart`

## Future Enhancements

Potential improvements:
- Add "Subscribe Now" button in dialog that navigates to subscription/payment page
- Show trial expiry warning 7/3/1 days before expiry (proactive notification)
- Cache subscription status to avoid repeated failed API calls
- Add subscription status indicator in app bar/sidebar

## Support

For questions or issues:
- Backend: See `backend/structura_backend/SUPERADMIN_GUIDE.md`
- Frontend: Contact Flutter development team

---

**Last Updated**: March 6, 2026
