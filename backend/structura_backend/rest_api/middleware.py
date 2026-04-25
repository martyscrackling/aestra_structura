from django.http import JsonResponse
from app.models import User
import logging

logger = logging.getLogger(__name__)


class SubscriptionMiddleware:
    """
    Middleware to check subscription status and block editing/creating for expired users.
    
    Allows:
    - GET requests (viewing is allowed for expired users)
    - SuperAdmin users (bypass all checks)
    - Non-ProjectManager users
    
    Blocks:
    - POST, PUT, PATCH, DELETE requests for ProjectManagers with expired subscriptions
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
        
        # Paths that should be exempt from subscription checks
        self.exempt_paths = [
            '/api/login/',
            '/api/health/',
            '/api/subscription/check/',
            '/api/subscription/activate/',
            '/api/subscription/paymongo-checkout/',
            '/api/webhooks/paymongo/',
            '/api/change-password/',
            '/admin/',
        ]
    
    def __call__(self, request):
        # Skip subscription check for exempt paths
        if any(request.path.startswith(path) for path in self.exempt_paths):
            return self.get_response(request)
        
        # Only check for write operations (POST, PUT, PATCH, DELETE)
        if request.method in ['POST', 'PUT', 'PATCH', 'DELETE']:
            # Try to get user_id from various sources
            user_id = self._get_user_id(request)
            
            if user_id:
                try:
                    user = User.objects.get(user_id=user_id)
                    
                    # SuperAdmin bypasses all checks
                    if user.role == 'SuperAdmin':
                        return self.get_response(request)
                    
                    # Only check ProjectManagers
                    if user.role == 'ProjectManager':
                        # Check if subscription is valid
                        if not user.is_subscription_valid():
                            logger.warning(
                                f"Blocked write operation for user {user.email} "
                                f"(subscription status: {user.subscription_status})"
                            )
                            return JsonResponse({
                                'success': False,
                                'error': 'subscription_expired',
                                'message': 'Your subscription has expired. You can view data but cannot create or edit content. Please renew your subscription to continue.',
                                'subscription_status': user.subscription_status,
                                'trial_days_remaining': user.get_trial_days_remaining() if user.subscription_status == 'trial' else None,
                            }, status=403)
                        
                        # Check if user can edit
                        if not user.can_edit():
                            logger.warning(
                                f"Blocked write operation for user {user.email} "
                                f"(cannot edit)"
                            )
                            return JsonResponse({
                                'success': False,
                                'error': 'cannot_edit',
                                'message': 'You do not have permission to create or edit content at this time.',
                                'subscription_status': user.subscription_status,
                            }, status=403)
                
                except User.DoesNotExist:
                    # User not found - let the request through, 
                    # the view will handle authentication
                    pass
                except Exception as e:
                    logger.error(f"Error in subscription middleware: {str(e)}")
                    # On error, let the request through to avoid blocking legitimate requests
                    pass
        
        response = self.get_response(request)
        return response
    
    def _get_user_id(self, request):
        """
        Extract user_id from various sources in the request.
        """
        # Check query parameters
        user_id = request.GET.get('user_id')
        if user_id:
            return user_id
        
        # Check headers
        user_id = request.headers.get('X-User-Id')
        if user_id:
            return user_id
        
        # Check request body (for POST/PUT/PATCH)
        if request.method in ['POST', 'PUT', 'PATCH']:
            try:
                import json
                content_type = (request.content_type or '').lower()
                # Only parse JSON bodies. Multipart/form-data may include binary bytes.
                if hasattr(request, 'body') and 'application/json' in content_type:
                    body = json.loads(request.body)
                    user_id = body.get('user_id') or body.get('created_by') or body.get('created_by_id')
                    if user_id:
                        return user_id
            except (json.JSONDecodeError, UnicodeDecodeError, AttributeError, TypeError, ValueError):
                pass
        
        return None
