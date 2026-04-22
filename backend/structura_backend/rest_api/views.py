from django.shortcuts import render
from rest_framework import generics, status, viewsets
from rest_framework.decorators import api_view, action, parser_classes
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from django.contrib.auth.hashers import check_password
from django.contrib.auth.hashers import make_password
from django.views.decorators.csrf import csrf_exempt
from django.db.models import Count, Q, Prefetch
from django.db import transaction
from django.db.models.functions import TruncDate
from django.utils import timezone
from django.core.cache import cache
import json
import os
import re
import secrets
import threading
import time
from datetime import timedelta
import logging

logger = logging.getLogger(__name__)

from app.image_verification import verify_image_has_human_face
from .email_utils import (
    send_signup_otp_email,
    send_phase_update_summary_email,
)


def _get_request_pm_user_id(request):
    """Best-effort extraction of the ProjectManager's `user_id` from the request.

    Note: This project currently does not use auth tokens, so scoping relies on a
    `user_id` being supplied by the client app.
    """
    raw = (
        request.query_params.get('user_id')
        or request.headers.get('X-User-Id')
        or request.data.get('user_id')
        or request.data.get('created_by')
        or request.data.get('created_by_id')
    )
    try:
        return int(raw) if raw is not None and raw != '' else None
    except (TypeError, ValueError):
        return None


def _get_pm_user_or_none(pm_user_id):
    if pm_user_id is None:
        return None
    return models.User.objects.filter(
        user_id=pm_user_id,
        role__in=['ProjectManager', 'SuperAdmin'],
    ).first()


_PHASE_UPDATE_QUEUE_WINDOW_SECONDS = 5
_PHASE_UPDATE_QUEUE_TTL_SECONDS = 90


def _queue_phase_update_notification(*, queue_key: str, summary_payload: dict) -> None:
    pending_updates = cache.get(queue_key) or []
    pending_updates.append(summary_payload)
    cache.set(queue_key, pending_updates, timeout=_PHASE_UPDATE_QUEUE_TTL_SECONDS)

    flush_lock_key = f"{queue_key}:flush_lock"
    should_schedule_flush = cache.add(
        flush_lock_key,
        True,
        timeout=_PHASE_UPDATE_QUEUE_WINDOW_SECONDS + 5,
    )

    if not should_schedule_flush:
        return

    def _flush_queue() -> None:
        try:
            time.sleep(_PHASE_UPDATE_QUEUE_WINDOW_SECONDS)
            batched_updates = cache.get(queue_key) or []
            if not batched_updates:
                return

            latest = batched_updates[-1]
            subtask_lines = []
            for item in batched_updates:
                title = (item.get('subtask_title') or '').strip() or 'Untitled subtask'
                status = (item.get('subtask_status') or '').strip() or 'Updated'
                action = (item.get('update_action') or '').strip()
                has_photo = bool(item.get('has_photo'))
                action_label = action if action else status
                subtask_lines.append(
                    f"{title} - {action_label} [{status}] ({'Photo' if has_photo else 'No photo'})"
                )

            # Preserve order while removing duplicates from repeated PATCH calls.
            deduped_subtask_lines = list(dict.fromkeys(subtask_lines))

            send_phase_update_summary_email(
                to_email=latest.get('to_email', ''),
                client_first_name=latest.get('client_first_name'),
                project_name=latest.get('project_name'),
                phase_name=latest.get('phase_name'),
                supervisor_name=latest.get('supervisor_name'),
                progress_notes=latest.get('progress_notes'),
                subtask_lines=deduped_subtask_lines,
            )
        except Exception:
            logger.exception("Failed to flush queued phase update emails (key=%s)", queue_key)
        finally:
            cache.delete(queue_key)
            cache.delete(flush_lock_key)

    threading.Thread(target=_flush_queue, daemon=True).start()

# Health check endpoint for debugging
@api_view(['GET'])
def health_check(request):
    """
    Health check endpoint to verify database connection and app status.
    """
    from django.db import connection
    from django.test.utils import CaptureQueriesContext
    
    try:
        # Test database connection
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        db_status = "connected"
        db_error = None
    except Exception as e:
        db_status = "error"
        db_error = str(e)
    
    return Response({
        'status': 'ok' if db_status == 'connected' else 'error',
        'database': {
            'status': db_status,
            'error': db_error,
            'engine': connection.settings_dict.get('ENGINE', 'unknown'),
            'name': str(connection.settings_dict.get('NAME', 'unknown')),
        },
        'version': '1.0',
    })


@csrf_exempt
@api_view(['POST'])
@parser_classes([MultiPartParser, FormParser])
def verify_profile_photo(request):
    """Return ACCEPT/REJECT after running the face detector on a raw upload."""
    uploaded = request.FILES.get('image') or request.FILES.get('photo')
    if uploaded is None:
        return Response(
            {
                'image_verification': 'REJECT',
                'detail': 'No file provided. Use multipart field "image".',
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    image_bytes = uploaded.read()
    try:
        uploaded.seek(0)
    except Exception:
        pass

    if not image_bytes:
        return Response(
            {
                'image_verification': 'REJECT',
                'detail': 'Uploaded image appears to be empty.',
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    if verify_image_has_human_face(image_bytes):
        return Response(
            {
                'image_verification': 'ACCEPT',
                'detail': 'Human face detected in the uploaded image.',
            },
            status=status.HTTP_200_OK,
        )

    return Response(
        {
            'image_verification': 'REJECT',
            'detail': 'No human face detected in the uploaded image.',
        },
        status=status.HTTP_400_BAD_REQUEST,
    )

# Create your views here.
from app import models
from .serializers import (
    UserSerializer, 
    RegionSerializer, 
    ProvinceSerializer, 
    CitySerializer, 
    BarangaySerializer,
    ProjectSerializer,
    SupervisorSerializer,
    SupervisorsSerializer,
    FieldWorkerSerializer,
    ClientSerializer,
    BackJobReviewSerializer,
    PhaseSerializer,
    SubtaskSerializer,
    SubtaskFieldWorkerSerializer,
    AttendanceSerializer,
    InventoryItemSerializer,
    InventoryUsageSerializer,
    InventoryUnitSerializer,
    InventoryUnitMovementSerializer,
)
from rest_framework.exceptions import ValidationError

class ListUser(generics.ListCreateAPIView):
    queryset = models.User.objects.all()
    serializer_class = UserSerializer
    
    def create(self, request, *args, **kwargs):
        try:
            email = (request.data.get('email') or '').strip()
            if not email:
                return Response(
                    {'success': False, 'message': 'Email is required'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            otp_entry = models.EmailOTP.objects.filter(email=email, is_verified=True).first()
            if otp_entry is None:
                return Response(
                    {'success': False, 'message': 'Email is not verified. Please verify OTP first.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            return super().create(request, *args, **kwargs)
        except Exception as e:
            logger.error(f"User creation error: {str(e)}", exc_info=True)
            return Response(
                {'success': False, 'message': f'Error creating user: {str(e)}'},
                status=status.HTTP_400_BAD_REQUEST
            )

    def perform_create(self, serializer):
        user = serializer.save()
        email = (getattr(user, 'email', '') or '').strip()
        if email:
            models.EmailOTP.objects.filter(email=email).delete()

class DetailUser(generics.RetrieveUpdateDestroyAPIView):
    queryset = models.User.objects.all()
    serializer_class = UserSerializer


@csrf_exempt
@api_view(['POST'])
def send_signup_otp(request):
    try:
        data = json.loads(request.body)
        email = (data.get('email') or '').strip().lower()
        if not email:
            return Response(
                {'success': False, 'message': 'Email is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if (
            models.User.objects.filter(email=email).exists()
            or models.Supervisors.objects.filter(email=email).exists()
            or models.Client.objects.filter(email=email).exists()
        ):
            return Response(
                {'success': False, 'message': 'Email already exists'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        now = timezone.now()
        existing = models.EmailOTP.objects.filter(email=email).first()
        if existing is not None and existing.resend_available_at > now:
            remaining_seconds = int((existing.resend_available_at - now).total_seconds())
            return Response(
                {
                    'success': False,
                    'message': 'Please wait before requesting another OTP.',
                    'retry_after_seconds': remaining_seconds,
                },
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

        otp_code = f"{secrets.randbelow(1000000):06d}"
        models.EmailOTP.objects.update_or_create(
            email=email,
            defaults={
                'code_hash': make_password(otp_code),
                'expires_at': now + timedelta(minutes=10),
                'resend_available_at': now + timedelta(minutes=1),
                'is_verified': False,
                'verified_at': None,
            },
        )

        send_signup_otp_email(to_email=email, otp_code=otp_code)
        return Response(
            {
                'success': True,
                'message': 'OTP sent successfully',
                'resend_available_in_seconds': 60,
            },
            status=status.HTTP_200_OK,
        )
    except json.JSONDecodeError:
        return Response(
            {'success': False, 'message': 'Invalid JSON body'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    except Exception as e:
        return Response(
            {'success': False, 'message': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


@csrf_exempt
@api_view(['POST'])
def verify_signup_otp(request):
    try:
        data = json.loads(request.body)
        email = (data.get('email') or '').strip().lower()
        otp = (data.get('otp') or '').strip()
        if not email or not otp:
            return Response(
                {'success': False, 'message': 'Email and otp are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        otp_entry = models.EmailOTP.objects.filter(email=email).first()
        if otp_entry is None:
            return Response(
                {'success': False, 'message': 'No OTP request found for this email'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        now = timezone.now()
        if otp_entry.expires_at < now:
            return Response(
                {'success': False, 'message': 'OTP expired. Please request a new one.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not check_password(otp, otp_entry.code_hash):
            return Response(
                {'success': False, 'message': 'Wrong OTP code'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        otp_entry.is_verified = True
        otp_entry.verified_at = now
        otp_entry.save(update_fields=['is_verified', 'verified_at', 'updated_at'])
        return Response(
            {'success': True, 'message': 'Email verified successfully'},
            status=status.HTTP_200_OK,
        )
    except json.JSONDecodeError:
        return Response(
            {'success': False, 'message': 'Invalid JSON body'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    except Exception as e:
        return Response(
            {'success': False, 'message': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

@csrf_exempt
@api_view(['POST'])
def login_user(request):
    """
    Authenticate user with email and password.
    Can login as either a User (ProjectManager), Worker, or Client.
    """
    try:
        data = json.loads(request.body)
        email = data.get('email')
        password = data.get('password')
        
        if not email or not password:
            return Response(
                {'success': False, 'message': 'Email and password required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # First, try to find user as a regular User (ProjectManager, etc.)
        try:
            user = models.User.objects.get(email=email)
            # Check password
            if check_password(password, user.password_hash):
                # If this is a Client user, also resolve the corresponding Client profile.
                # Many parts of the mobile/web clients rely on `client_id` / `project_id`.
                if user.role == 'Client':
                    client = (
                        models.Client.objects.filter(user_id=user).select_related('project_id').first()
                        or models.Client.objects.filter(email=email).select_related('project_id').first()
                    )
                    return Response({
                        'success': True,
                        'message': 'Login successful',
                        'user': {
                            'user_id': user.user_id,
                            'client_id': client.client_id if client else None,
                            'project_id': client.project_id.project_id if (client and client.project_id) else None,
                            'email': user.email,
                            'first_name': user.first_name,
                            'last_name': user.last_name,
                            'role': 'Client',
                            'type': 'Client',
                            'force_password_change': password == 'PASSWORD',
                        }
                    }, status=status.HTTP_200_OK)

                return Response({
                    'success': True,
                    'message': 'Login successful',
                    'user': {
                        'user_id': user.user_id,
                        'email': user.email,
                        'first_name': user.first_name,
                        'last_name': user.last_name,
                        'role': user.role,
                        'type': 'user',  # Indicate this is a regular user/project manager
                    }
                }, status=status.HTTP_200_OK)
            else:
                return Response(
                    {'success': False, 'message': 'Invalid password'},
                    status=status.HTTP_401_UNAUTHORIZED
                )
        except models.User.DoesNotExist:
            pass  # Not a User, check if it's a Worker or Client
        
        # If not a regular user, check if they're a Supervisor
        try:
            supervisor = models.Supervisors.objects.get(email=email)
            # Check password
            if check_password(password, supervisor.password_hash):
                # Prefer the explicit FK on the supervisor row, but fall back to
                # resolving the project through Project.supervisor.
                project_obj = supervisor.project_id
                if project_obj is None:
                    project_obj = (
                        models.Project.objects.filter(supervisor=supervisor)
                        .order_by('-created_at')
                        .first()
                    )
                    if project_obj is not None:
                        # Backfill for future logins
                        supervisor.project_id = project_obj
                        supervisor.save(update_fields=['project_id'])

                return Response({
                    'success': True,
                    'message': 'Login successful',
                    'user': {
                        'supervisor_id': supervisor.supervisor_id,
                        'user_id': supervisor.supervisor_id,  # Use supervisor_id as user_id
                        'project_id': project_obj.project_id if project_obj else None,
                        'email': supervisor.email,
                        'first_name': supervisor.first_name,
                        'last_name': supervisor.last_name,
                        'role': 'Supervisor',
                        'type': 'Supervisor',  # Indicate this is a supervisor
                        'force_password_change': password == 'PASSWORD',
                    }
                }, status=status.HTTP_200_OK)
            else:
                return Response(
                    {'success': False, 'message': 'Invalid password'},
                    status=status.HTTP_401_UNAUTHORIZED
                )
        except models.Supervisors.DoesNotExist:
            pass  # Not a Supervisor, check if it's a Client
        
        # If not a supervisor, check if they're a Client
        try:
            client = models.Client.objects.get(email=email)
            # Check password
            if check_password(password, client.password_hash):
                return Response({
                    'success': True,
                    'message': 'Login successful',
                    'user': {
                        'client_id': client.client_id,
                        'user_id': client.client_id,  # Use client_id as user_id
                        'project_id': client.project_id.project_id if client.project_id else None,
                        'email': client.email,
                        'first_name': client.first_name,
                        'last_name': client.last_name,
                        'role': 'Client',
                        'type': 'Client',  # Indicate this is a client
                        'force_password_change': password == 'PASSWORD',
                    }
                }, status=status.HTTP_200_OK)
            else:
                return Response(
                    {'success': False, 'message': 'Invalid password'},
                    status=status.HTTP_401_UNAUTHORIZED
                )
        except models.Client.DoesNotExist:
            return Response(
                {'success': False, 'message': 'Email not found in system'},
                status=status.HTTP_404_NOT_FOUND
            )
        
    except Exception as e:
        return Response(
            {'success': False, 'message': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@csrf_exempt
@api_view(['POST'])
def change_password(request):
    """Change password for Supervisor/Client accounts.

    Body:
      {
        "email": "...",
        "current_password": "...",
        "new_password": "..."
      }
    """
    try:
        data = json.loads(request.body)
        email = (data.get('email') or '').strip()
        current_password = data.get('current_password') or ''
        new_password = data.get('new_password') or ''

        if not email or not current_password or not new_password:
            return Response(
                {'success': False, 'message': 'Email, current_password, and new_password are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if new_password == current_password:
            return Response(
                {'success': False, 'message': 'New password must be different from current password'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if new_password == 'PASSWORD':
            return Response(
                {'success': False, 'message': 'New password must not be PASSWORD'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Supervisors table
        supervisor = models.Supervisors.objects.filter(email=email).first()
        if supervisor is not None:
            if not check_password(current_password, supervisor.password_hash):
                return Response(
                    {'success': False, 'message': 'Current password is incorrect'},
                    status=status.HTTP_401_UNAUTHORIZED,
                )
            supervisor.password_hash = new_password
            supervisor.save(update_fields=['password_hash'])
            return Response({'success': True, 'message': 'Password updated'}, status=status.HTTP_200_OK)

        # Clients table
        client = models.Client.objects.filter(email=email).first()
        if client is not None:
            if not check_password(current_password, client.password_hash):
                return Response(
                    {'success': False, 'message': 'Current password is incorrect'},
                    status=status.HTTP_401_UNAUTHORIZED,
                )
            client.password_hash = new_password
            client.save(update_fields=['password_hash'])
            return Response({'success': True, 'message': 'Password updated'}, status=status.HTTP_200_OK)

        # Client users may also exist in the User table with role=Client
        user = models.User.objects.filter(email=email, role='Client').first()
        if user is not None:
            if not check_password(current_password, user.password_hash):
                return Response(
                    {'success': False, 'message': 'Current password is incorrect'},
                    status=status.HTTP_401_UNAUTHORIZED,
                )
            user.password_hash = new_password
            user.save(update_fields=['password_hash'])
            return Response({'success': True, 'message': 'Password updated'}, status=status.HTTP_200_OK)

        return Response(
            {'success': False, 'message': 'Email not found in system'},
            status=status.HTTP_404_NOT_FOUND,
        )
    except json.JSONDecodeError:
        return Response(
            {'success': False, 'message': 'Invalid JSON body'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    except Exception as e:
        return Response(
            {'success': False, 'message': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


# Subscription Management Endpoints
@api_view(['GET'])
def check_subscription_status(request):
    """
    Check subscription status for a user (ProjectManager).
    Query param: user_id
    
    Returns subscription status, trial info, and whether user can edit/create.
    """
    try:
        user_id = request.query_params.get('user_id')
        
        if not user_id:
            return Response(
                {'success': False, 'message': 'user_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            user = models.User.objects.get(user_id=user_id, role='ProjectManager')
        except models.User.DoesNotExist:
            return Response(
                {'success': False, 'message': 'User not found or not a ProjectManager'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        is_valid = user.is_subscription_valid()
        can_edit = user.can_edit()
        
        response_data = {
            'success': True,
            'user_id': user.user_id,
            'email': user.email,
            'subscription_status': user.subscription_status,
            'is_subscription_valid': is_valid,
            'can_edit': can_edit,
            'can_create': can_edit,
        }
        
        if user.subscription_status == 'trial':
            response_data.update({
                'trial_start_date': user.trial_start_date.isoformat() if user.trial_start_date else None,
                'trial_end_date': user.trial_end_date.isoformat() if user.trial_end_date else None,
                'trial_days_remaining': user.get_trial_days_remaining(),
                'trial_status_color': user.get_trial_status_color(),
            })
        elif user.subscription_status == 'active':
            response_data.update({
                'subscription_start_date': user.subscription_start_date.isoformat() if user.subscription_start_date else None,
                'subscription_end_date': user.subscription_end_date.isoformat() if user.subscription_end_date else None,
                'subscription_days_remaining': user.get_subscription_days_remaining(),
                'subscription_years': user.subscription_years,
            })
        
        return Response(response_data, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Error checking subscription status: {str(e)}")
        return Response(
            {'success': False, 'message': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
def activate_subscription(request):
    """
    Activate subscription for a user (admin use).
    Body: {
        "user_id": int,
        "subscription_years": int (default 1),
        "amount": decimal (optional)
    }
    """
    try:
        data = json.loads(request.body)
        user_id = data.get('user_id')
        subscription_years = data.get('subscription_years', 1)
        amount = data.get('amount', 0)
        
        if not user_id:
            return Response(
                {'success': False, 'message': 'user_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            user = models.User.objects.get(user_id=user_id, role='ProjectManager')
        except models.User.DoesNotExist:
            return Response(
                {'success': False, 'message': 'User not found or not a ProjectManager'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Activate subscription
        user.subscription_status = 'active'
        user.subscription_start_date = timezone.now()
        user.subscription_end_date = timezone.now() + timedelta(days=365 * subscription_years)
        user.subscription_years = subscription_years
        user.payment_date = timezone.now()
        user.save()
        
        # Create payment history record
        from app.models import PaymentHistory
        PaymentHistory.objects.create(
            user=user,
            amount=amount,
            subscription_years=subscription_years,
            payment_status='completed'
        )
        
        # Send confirmation email
        from app.utils import send_subscription_activated_email
        send_subscription_activated_email(user)
        
        return Response({
            'success': True,
            'message': 'Subscription activated successfully',
            'subscription_end_date': user.subscription_end_date.isoformat(),
            'subscription_years': user.subscription_years,
        }, status=status.HTTP_200_OK)
        
    except json.JSONDecodeError:
        return Response(
            {'success': False, 'message': 'Invalid JSON body'},
            status=status.HTTP_400_BAD_REQUEST
        )
    except Exception as e:
        logger.error(f"Error activating subscription: {str(e)}")
        return Response(
            {'success': False, 'message': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


# Address Hierarchy ViewSets
class RegionViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = models.Region.objects.all()
    serializer_class = RegionSerializer


class ProvinceViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = ProvinceSerializer

    def get_queryset(self):
        queryset = models.Province.objects.all()
        region_id = self.request.query_params.get('region')
        if region_id:
            queryset = queryset.filter(region_id=region_id)
        return queryset


class CityViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = CitySerializer

    def get_queryset(self):
        queryset = models.City.objects.all()
        province_id = self.request.query_params.get('province')
        if province_id:
            queryset = queryset.filter(province_id=province_id)
        return queryset


class BarangayViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = BarangaySerializer

    def get_queryset(self):
        queryset = models.Barangay.objects.all()
        city_id = self.request.query_params.get('city')
        if city_id:
            queryset = queryset.filter(city_id=city_id)
        return queryset


# Project ViewSet

from rest_framework.decorators import action, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser
import os
from django.conf import settings

class ProjectViewSet(viewsets.ModelViewSet):
    serializer_class = ProjectSerializer

    @action(detail=True, methods=['post'], url_path='upload_image', parser_classes=[MultiPartParser, FormParser])
    def upload_image(self, request, pk=None):
        """
        Accepts a multipart POST with an image file, saves it, and returns the public URL.
        """
        project = self.get_object()
        image_file = request.FILES.get('image')
        if not image_file:
            return Response({'error': 'No image file provided.'}, status=400)

        # Save to MEDIA_ROOT/project_images/pj_<user_id>_<project_id>.<ext>
        media_root = getattr(settings, 'MEDIA_ROOT', 'media')
        os.makedirs(os.path.join(media_root, 'project_images'), exist_ok=True)
        original_name = getattr(image_file, 'name', '') or ''
        ext = os.path.splitext(original_name)[1].lower()
        if not ext:
            ext = '.jpg'

        owner_user_id = getattr(project, 'user_id', None) or '0'
        filename = f'pj_{owner_user_id}_{project.project_id}{ext}'
        file_path = os.path.join(media_root, 'project_images', filename)
        with open(file_path, 'wb+') as dest:
            for chunk in image_file.chunks():
                dest.write(chunk)

        # Save path to project and return URL
        rel_path = f'project_images/{filename}'
        project.project_image = rel_path
        project.save()

        # Build absolute URL
        if hasattr(request, 'build_absolute_uri'):
            url = request.build_absolute_uri(settings.MEDIA_URL + rel_path)
        else:
            url = settings.MEDIA_URL + rel_path
        return Response({'url': url})

    @action(detail=True, methods=['post'], url_path='add-supervisor')
    def add_supervisor(self, request, pk=None):
        """
        Assign a supervisor to this project.
        Expected request body: {'supervisor_id': <int>, 'project_id': <int> (optional)}
        """
        project = self.get_object()
        supervisor_id = request.data.get('supervisor_id')
        
        if not supervisor_id:
            return Response(
                {'error': 'supervisor_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            supervisor = models.Supervisors.objects.get(supervisor_id=supervisor_id)
        except models.Supervisors.DoesNotExist:
            return Response(
                {'error': f'Supervisor with id {supervisor_id} not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Assign supervisor to project
        supervisor.project_id = project
        supervisor.save()
        
        print(f'✅ Supervisor {supervisor.first_name} {supervisor.last_name} (ID: {supervisor_id}) assigned to project {project.project_name} (ID: {project.project_id})')
        
        # Return updated supervisor data
        serializer = SupervisorsSerializer(supervisor)
        return Response(serializer.data, status=status.HTTP_200_OK)

    @action(detail=False, methods=['get'], url_path='supervisors')
    def get_supervisors(self, request):
        """
        Get all supervisors assigned to a project.
        Query params: project_id=<int>
        """
        project_id = request.query_params.get('project_id')
        
        if not project_id:
            return Response(
                {'error': 'project_id query parameter is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            supervisors = models.Supervisors.objects.filter(project_id=project_id)
            serializer = SupervisorsSerializer(supervisors, many=True)
            return Response(serializer.data, status=status.HTTP_200_OK)
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=True, methods=['post'], url_path='deactivate')
    def deactivate(self, request, pk=None):
        """
        Toggle project status through cycle: Active → On Hold → Deactivated → Active
        """
        project = self.get_object()
        
        # Cycle through all three states
        if project.status == 'Active':
            project.status = 'On Hold'
        elif project.status == 'On Hold':
            project.status = 'Deactivated'
        elif project.status == 'Deactivated':
            project.status = 'Active'
        else:
            # If status is unknown, default to On Hold
            project.status = 'On Hold'
        
        project.save()
        
        print(f'✅ Project {project.project_name} (ID: {project.project_id}) status changed to {project.status}')
        
        # Return updated project data
        serializer = ProjectSerializer(project)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def get_queryset(self):
        """
        Get projects only for the logged-in user
        SELECT * FROM projects WHERE user_id = user_id
        """
        # For now, get user_id from request headers or query params
        # In production, use authentication tokens
        user_id = self.request.query_params.get('user_id')
        client_id = self.request.query_params.get('client_id')
        supervisor_id = self.request.query_params.get('supervisor_id')
        print(f"🔍 ProjectViewSet get_queryset called")
        print(f"🔍 Received user_id: {user_id}")

        if supervisor_id:
            # Check for projects where this supervisor is assigned via two methods:
            # 1. New method: Supervisors.project_id (multiple supervisors per project)
            from django.db.models import Q
            queryset = models.Project.objects.filter(
                Q(supervisor_id=supervisor_id) |  # Old single-supervisor FK
                Q(supervisors__supervisor_id=supervisor_id)  # New multi-supervisor FK
            ).distinct().order_by('-created_at')
            print(f"✅ Filtered projects by supervisor_id count: {queryset.count()}")
            print(f"  - Checking both Project.supervisor_id and Supervisors.project_id relationships")
            return queryset
        
        if client_id:
            queryset = models.Project.objects.filter(client_id=client_id).order_by('-created_at')
            print(f"✅ Filtered projects by client_id count: {queryset.count()}")
            return queryset

        if user_id:
            # `user_id` is used by multiple client apps. For Project Managers it maps to Project.user_id.
            # For Clients, projects are linked through Project.client (Client profile), not Project.user.
            try:
                user_id_int = int(user_id)
            except (TypeError, ValueError):
                user_id_int = None

            if user_id_int is not None:
                # First, interpret this as a real User PK if it exists.
                user_obj = models.User.objects.filter(user_id=user_id_int).only('role').first()
                if user_obj and user_obj.role == 'Client':
                    queryset = models.Project.objects.filter(client__user_id=user_id_int).order_by('-created_at')
                    print(f"✅ Filtered projects by client user_id count: {queryset.count()}")
                    return queryset

                if user_obj:
                    queryset = models.Project.objects.filter(user_id=user_id_int).order_by('-created_at')
                    print(f"✅ Filtered projects by PM user_id count: {queryset.count()}")
                    return queryset

                # Legacy/mobile fallback: some clients stored `user_id` as the Client PK.
                # Only apply this if there is no matching User record; otherwise PM user_id values
                # can accidentally collide with Client PKs.
                if models.Client.objects.filter(client_id=user_id_int).exists():
                    queryset = models.Project.objects.filter(client_id=user_id_int).order_by('-created_at')
                    print(f"✅ Filtered projects by legacy client_id(user_id) count: {queryset.count()}")
                    return queryset

                queryset = models.Project.objects.none()
                print("⚠️ user_id provided but no matching User/Client found; returning empty queryset")
                return queryset

            queryset = models.Project.objects.filter(user_id=user_id).order_by('-created_at')
            print(f"✅ Filtered projects count: {queryset.count()}")
            return queryset
        
        # If no user_id provided, return all projects (for individual project retrieval)
        print(f"⚠️ No user_id provided, returning all projects")
        return models.Project.objects.all()
    
    def perform_create(self, serializer):
        """
        Automatically set the user_id when creating a project
        """
        user_id = self.request.data.get('user_id') or self.request.query_params.get('user_id')
        print(f"🔍 perform_create called with user_id: {user_id}")
        if user_id:
            serializer.save(user_id=user_id)
        else:
            raise ValueError("user_id is required to create a project")


@csrf_exempt
@api_view(['GET'])
def debug_projects(request):
    """
    Debug endpoint to see all projects with their user_id
    """
    all_projects = models.Project.objects.all().values('project_id', 'project_name', 'user_id', 'created_at')
    return Response({
        'total_projects': models.Project.objects.count(),
        'projects': list(all_projects)
    })


@csrf_exempt
@api_view(['GET'])
def debug_all_data(request):
    """
    Debug endpoint to check all data in database
    """
    return Response({
        'total_users': models.User.objects.count(),
        'total_projects': models.Project.objects.count(),
        'total_supervisors': models.Supervisors.objects.count(),
        'total_clients': models.Client.objects.count(),
        'sample_users': list(models.User.objects.all().values('user_id', 'email')[:5]),
        'sample_projects': list(models.Project.objects.all().values('project_id', 'project_name', 'user_id')[:5]),
    })


# Supervisors ViewSet
class SupervisorsViewSet(viewsets.ModelViewSet):
    queryset = models.Supervisors.objects.all()
    serializer_class = SupervisorsSerializer

    def get_queryset(self):
        pm_user_id = _get_request_pm_user_id(self.request)
        project_id = self.request.query_params.get('project_id')

        if pm_user_id is None:
            if project_id:
                return models.Supervisors.objects.filter(project_id=project_id)
            return models.Supervisors.objects.none()

        # Prefer explicit ownership; fall back to project ownership for older rows.
        queryset = models.Supervisors.objects.filter(
            Q(created_by_id=pm_user_id) | Q(project_id__user_id=pm_user_id)
        ).distinct()
        if project_id:
            queryset = queryset.filter(project_id=project_id)
        return queryset

    def perform_create(self, serializer):
        pm_user_id = _get_request_pm_user_id(self.request)
        pm_user = _get_pm_user_or_none(pm_user_id)
        if pm_user is None:
            # If a project is supplied, infer PM from the project itself.
            project = serializer.validated_data.get('project_id')
            if project is not None and getattr(project, 'user_id', None) is not None:
                pm_user = project.user

        serializer.save(created_by=pm_user)

    @action(
        detail=True,
        methods=['post'],
        url_path='upload-photo',
        parser_classes=[MultiPartParser, FormParser],
    )
    def upload_photo(self, request, pk=None):
        """Upload/replace a supervisor photo.

        Accepts multipart form-data with `image` (preferred) or `photo`.
        Saves to MEDIA_ROOT/supervisor_images/ with filename sv_<user_id>_<supervisor_id>.<ext>
        """
        supervisor = self.get_object()

        uploaded = request.FILES.get('image') or request.FILES.get('photo')
        if uploaded is None:
            return Response(
                {'detail': 'No file provided. Use multipart field "image".'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Verify face presence before mutating existing state.
        image_bytes = uploaded.read()
        try:
            uploaded.seek(0)
        except Exception:
            pass

        if not verify_image_has_human_face(image_bytes):
            return Response(
                {
                    'image_verification': 'REJECT',
                    'detail': 'No human face detected in the uploaded image.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Delete existing photo so the next save reuses the same name.
        if getattr(supervisor, 'photo', None):
            try:
                supervisor.photo.delete(save=False)
            except Exception:
                # Best-effort cleanup; continue with overwrite.
                pass

        ext = os.path.splitext(getattr(uploaded, 'name', '') or '')[1].lower()
        if not ext:
            ext = '.jpg'

        pm_user_id = getattr(supervisor, 'created_by_id', None) or _get_request_pm_user_id(request) or 0
        filename = f'sv_{pm_user_id}_{supervisor.supervisor_id}{ext}'
        supervisor.photo.save(filename, uploaded, save=True)

        data = self.get_serializer(supervisor).data
        data['image_verification'] = 'ACCEPT'
        return Response(
            data,
            status=status.HTTP_200_OK,
        )


# Supervisor ViewSet (alias for backwards compatibility)
class SupervisorViewSet(viewsets.ModelViewSet):
    queryset = models.Supervisors.objects.all()
    serializer_class = SupervisorSerializer

    def get_queryset(self):
        pm_user_id = _get_request_pm_user_id(self.request)
        project_id = self.request.query_params.get('project_id')

        if pm_user_id is None:
            if project_id:
                return models.Supervisors.objects.filter(project_id=project_id)
            return models.Supervisors.objects.none()

        queryset = models.Supervisors.objects.filter(
            Q(created_by_id=pm_user_id) | Q(project_id__user_id=pm_user_id)
        ).distinct()
        if project_id:
            queryset = queryset.filter(project_id=project_id)
        return queryset

    def perform_create(self, serializer):
        pm_user_id = _get_request_pm_user_id(self.request)
        pm_user = _get_pm_user_or_none(pm_user_id)
        if pm_user is None:
            project = serializer.validated_data.get('project_id')
            if project is not None and getattr(project, 'user_id', None) is not None:
                pm_user = project.user
        serializer.save(created_by=pm_user)

    @action(
        detail=True,
        methods=['post'],
        url_path='upload-photo',
        parser_classes=[MultiPartParser, FormParser],
    )
    def upload_photo(self, request, pk=None):
        """Upload/replace a supervisor photo.

        Accepts multipart form-data with `image` (preferred) or `photo`.
        Saves to MEDIA_ROOT/supervisor_images/ with filename sv_<user_id>_<supervisor_id>.<ext>
        """
        supervisor = self.get_object()

        uploaded = request.FILES.get('image') or request.FILES.get('photo')
        if uploaded is None:
            return Response(
                {'detail': 'No file provided. Use multipart field "image".'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Verify face presence before mutating existing state.
        image_bytes = uploaded.read()
        try:
            uploaded.seek(0)
        except Exception:
            pass

        if not verify_image_has_human_face(image_bytes):
            return Response(
                {
                    'image_verification': 'REJECT',
                    'detail': 'No human face detected in the uploaded image.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if getattr(supervisor, 'photo', None):
            try:
                supervisor.photo.delete(save=False)
            except Exception:
                pass

        ext = os.path.splitext(getattr(uploaded, 'name', '') or '')[1].lower()
        if not ext:
            ext = '.jpg'

        pm_user_id = getattr(supervisor, 'created_by_id', None) or _get_request_pm_user_id(request) or 0
        filename = f'sv_{pm_user_id}_{supervisor.supervisor_id}{ext}'
        supervisor.photo.save(filename, uploaded, save=True)

        data = self.get_serializer(supervisor).data
        data['image_verification'] = 'ACCEPT'
        return Response(
            data,
            status=status.HTTP_200_OK,
        )


# FieldWorker ViewSet
class FieldWorkerViewSet(viewsets.ModelViewSet):
    queryset = models.FieldWorker.objects.all()
    serializer_class = FieldWorkerSerializer

    def get_queryset(self):
        pm_user_id = _get_request_pm_user_id(self.request)
        project_id = self.request.query_params.get('project_id')
        supervisor_id = self.request.query_params.get('supervisor_id')
        
        # Special case: If 'include_other_projects' flag is set, show ALL workers for assignment
        # This is used when assigning workers to subtasks across projects
        include_other_projects = self.request.query_params.get('include_other_projects')

        # Supervisor accessing field workers: return workers from their projects
        if supervisor_id:
            try:
                sv = models.Supervisors.objects.get(supervisor_id=int(supervisor_id))
            except (models.Supervisors.DoesNotExist, ValueError, TypeError):
                return models.FieldWorker.objects.none()
            sv_project_ids = (
                models.Project.objects
                .filter(supervisor_id=sv.supervisor_id)
                .values_list('project_id', flat=True)
            )
            queryset = models.FieldWorker.objects.filter(
                Q(project_id__in=sv_project_ids) |
                Q(subtask_assignments__subtask__phase__project_id__in=sv_project_ids)
            )
            if project_id:
                queryset = queryset.filter(
                    Q(project_id=project_id) |
                    Q(subtask_assignments__subtask__phase__project_id=project_id)
                )
            return queryset.distinct()

        if pm_user_id is None:
            if project_id:
                return models.FieldWorker.objects.filter(project_id=project_id)
            return models.FieldWorker.objects.none()

        # If include_other_projects is requested, return ALL workers accessible to this PM
        # (from any of their projects or directly assigned)
        if include_other_projects:
            queryset = models.FieldWorker.objects.filter(
                Q(user_id=pm_user_id)
                | Q(project_id__user_id=pm_user_id)
                | Q(subtask_assignments__subtask__phase__project__user_id=pm_user_id)
            ).distinct()
            return queryset

        # Default behavior: filter by project if specified
        queryset = models.FieldWorker.objects.filter(
            Q(user_id=pm_user_id)
            | Q(project_id__user_id=pm_user_id)
            | Q(subtask_assignments__subtask__phase__project__user_id=pm_user_id)
        ).distinct()
        if project_id:
            queryset = queryset.filter(
                Q(project_id=project_id)
                | Q(subtask_assignments__subtask__phase__project_id=project_id)
            )
        return queryset

    def get_serializer_context(self):
        """Pass current_project_id context to serializer for assignment status calculation"""
        context = super().get_serializer_context()
        project_id = self.request.query_params.get('project_id')
        if project_id:
            try:
                context['current_project_id'] = int(project_id)
            except (TypeError, ValueError):
                pass
        return context

    def perform_create(self, serializer):
        # If user_id wasn't provided, attach the PM based on request user_id.
        pm_user_id = _get_request_pm_user_id(self.request)
        pm_user = _get_pm_user_or_none(pm_user_id)
        if serializer.validated_data.get('user_id') is None and pm_user is not None:
            serializer.save(user_id=pm_user)
        else:
            serializer.save()

    @action(
        detail=True,
        methods=['post'],
        url_path='upload-photo',
        parser_classes=[MultiPartParser, FormParser],
    )
    def upload_photo(self, request, pk=None):
        """Upload/replace a field worker photo.

        Accepts multipart form-data with `image` (preferred) or `photo`.
        Saves to MEDIA_ROOT/fieldworker_images/ with filename fieldworker_<fieldworker_id>.<ext>
        """
        field_worker = self.get_object()

        uploaded = request.FILES.get('image') or request.FILES.get('photo')
        if uploaded is None:
            return Response(
                {'detail': 'No file provided. Use multipart field "image".'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Verify face presence before mutating existing state.
        image_bytes = uploaded.read()
        try:
            uploaded.seek(0)
        except Exception:
            pass

        if not verify_image_has_human_face(image_bytes):
            return Response(
                {
                    'image_verification': 'REJECT',
                    'detail': 'No human face detected in the uploaded image.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Delete existing photo so the next save reuses the same name.
        if getattr(field_worker, 'photo', None):
            try:
                field_worker.photo.delete(save=False)
            except Exception:
                # Best-effort cleanup; continue with overwrite.
                pass

        ext = os.path.splitext(getattr(uploaded, 'name', '') or '')[1].lower()
        if not ext:
            ext = '.jpg'

        owner_user_id = getattr(field_worker, 'user_id_id', None)
        if owner_user_id in (None, ''):
            project = getattr(field_worker, 'project_id', None)
            owner_user_id = getattr(project, 'user_id_id', None) if project is not None else None
        if owner_user_id in (None, ''):
            owner_user_id = 0

        filename = f'fw_{owner_user_id}_{field_worker.fieldworker_id}{ext}'
        field_worker.photo.save(filename, uploaded, save=True)

        data = self.get_serializer(field_worker).data
        data['image_verification'] = 'ACCEPT'
        return Response(
            data,
            status=status.HTTP_200_OK,
        )

    @action(detail=True, methods=['get'], url_path='debug-assignments')
    def debug_assignments(self, request, pk=None):
        """Debug endpoint to show all assignments for a field worker."""
        try:
            field_worker = self.get_object()
            
            # Check subtask assignments
            subtask_count = models.SubtaskFieldWorker.objects.filter(
                field_worker_id=field_worker.fieldworker_id
            ).count()
            
            # Check direct project
            has_direct_project = field_worker.project_id is not None
            direct_project_name = field_worker.project_id.project_name if has_direct_project else None
            
            # Get all phases if has direct project
            phase_count = 0
            if has_direct_project:
                phase_count = models.Phase.objects.filter(
                    project_id=field_worker.project_id.project_id
                ).count()
            
            return Response({
                'field_worker_id': field_worker.fieldworker_id,
                'name': f"{field_worker.first_name} {field_worker.last_name}",
                'subtask_assignments': subtask_count,
                'has_direct_project': has_direct_project,
                'direct_project': direct_project_name,
                'phases_in_project': phase_count,
            })
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=True, methods=['get'], url_path='active-projects')
    def active_projects(self, request, pk=None):
        """Get active subtask assignments with their phase and project details.

        By default this returns only explicit subtask assignments.
        Set include_direct_project=true to include fallback direct project rows.
        """
        try:
            print(f"\n{'='*80}")
            print(f"🔍 active_projects endpoint called with pk={pk}")
            print(f"   Request path: {request.path}")
            print(f"   Request user: {request.user}")
            
            # Try to bypass permission filters and get directly from all field workers
            try:
                field_worker = models.FieldWorker.objects.get(fieldworker_id=int(pk))
                print(f"✓ Found field worker: {field_worker.first_name} {field_worker.last_name} (ID: {field_worker.fieldworker_id})")
            except models.FieldWorker.DoesNotExist:
                print(f"❌ FieldWorker with id={pk} does not exist in database")
                return Response(
                    {'error': f'Field worker {pk} not found in database'},
                    status=status.HTTP_404_NOT_FOUND
                )
            except (ValueError, TypeError) as e:
                print(f"❌ Invalid pk type: {e}")
                return Response(
                    {'error': f'Invalid field worker ID: {pk}'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            print(f"   Direct project assignment: {field_worker.project_id}")

            include_direct_project = str(
                request.query_params.get('include_direct_project', 'false')
            ).strip().lower() in ('1', 'true', 'yes', 'y', 'on')
            
            assignments_data = []
            
            # Method 1: Subtask assignments
            subtask_assignments = models.SubtaskFieldWorker.objects.filter(
                field_worker_id=field_worker.fieldworker_id
            ).select_related(
                'subtask__phase__project',
                'subtask__phase__project__region',
                'subtask__phase__project__province',
                'subtask__phase__project__city',
                'subtask__phase__project__barangay',
            )
            
            print(f"📊 Subtask assignments: {subtask_assignments.count()}")
            for i, assignment in enumerate(subtask_assignments, 1):
                try:
                    subtask = assignment.subtask
                    phase = subtask.phase
                    project = phase.project
                    
                    assignment_info = {
                        'assignment_id': assignment.assignment_id,
                        'assigned_at': assignment.assigned_at.isoformat(),
                        'assignment_type': 'subtask',
                        'subtask': {
                            'subtask_id': subtask.subtask_id,
                            'title': subtask.title,
                            'status': subtask.status,
                        },
                        'phase': {
                            'phase_id': phase.phase_id,
                            'phase_name': phase.phase_name,
                            'status': phase.status,
                        },
                        'project': {
                            'project_id': project.project_id,
                            'project_name': project.project_name,
                            'status': project.status,
                            'start_date': project.start_date.isoformat() if project.start_date else None,
                            'end_date': project.end_date.isoformat() if project.end_date else None,
                            'street': project.street,
                            'barangay_name': project.barangay.name if project.barangay else None,
                            'city_name': project.city.name if project.city else None,
                            'province_name': project.province.name if project.province else None,
                        }
                    }
                    assignments_data.append(assignment_info)
                    print(f"  #{i} ✓ Subtask: {project.project_name} > {phase.phase_name} > {subtask.title}")
                except Exception as e:
                    print(f"  #{i} ❌ Error: {e}")
            
            # Optional method 2: include direct project only when explicitly requested.
            if include_direct_project and len(assignments_data) == 0 and field_worker.project_id:
                print(f"⚠️  No subtask assignments, checking direct project assignment...")
                try:
                    project = field_worker.project_id
                    
                    # Get all phases for this project
                    phases = models.Phase.objects.filter(project_id=project.project_id)
                    print(f"   Project has {phases.count()} phases")
                    
                    for phase in phases:
                        assignment_info = {
                            'assignment_id': None,
                            'assigned_at': str(field_worker.created_at.isoformat() if field_worker.created_at else None),
                            'assignment_type': 'project',
                            'subtask': {
                                'subtask_id': None,
                                'title': 'Assigned to Project',
                                'status': 'assigned',
                            },
                            'phase': {
                                'phase_id': phase.phase_id,
                                'phase_name': phase.phase_name,
                                'status': phase.status,
                            },
                            'project': {
                                'project_id': project.project_id,
                                'project_name': project.project_name,
                                'status': project.status,
                                'start_date': project.start_date.isoformat() if project.start_date else None,
                                'end_date': project.end_date.isoformat() if project.end_date else None,
                                'street': project.street,
                                'barangay_name': project.barangay.name if project.barangay else None,
                                'city_name': project.city.name if project.city else None,
                                'province_name': project.province.name if project.province else None,
                            }
                        }
                        assignments_data.append(assignment_info)
                        print(f"  ✓ Direct: {project.project_name} > {phase.phase_name}")
                except Exception as e:
                    print(f"  ❌ Error getting direct project: {e}")
            
            print(f"✅ Returning {len(assignments_data)} total assignments")
            print(f"{'='*80}\n")
            
            return Response(assignments_data, status=status.HTTP_200_OK)
            
        except models.FieldWorker.DoesNotExist:
            print(f"❌ Field worker not found: {pk}")
            return Response(
                {'error': f'Field worker {pk} not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            print(f"❌ Unexpected error: {e}")
            import traceback
            traceback.print_exc()
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


# Client ViewSet
class ClientViewSet(viewsets.ModelViewSet):
    queryset = models.Client.objects.all()
    serializer_class = ClientSerializer

    def get_queryset(self):
        pm_user_id = _get_request_pm_user_id(self.request)
        project_id = self.request.query_params.get('project_id')
        if pm_user_id is None:
            if project_id:
                # Support both legacy direct link (Client.project_id) and
                # canonical assignment (Project.client -> Client).
                return models.Client.objects.filter(
                    Q(project_id=project_id)
                    | Q(assigned_projects__project_id=project_id)
                ).distinct()
            return models.Client.objects.none()

        # Prefer explicit ownership; fall back to project ownership for older rows.
        queryset = models.Client.objects.filter(
            Q(created_by_id=pm_user_id) | Q(project_id__user_id=pm_user_id)
        ).distinct()

        if project_id:
            queryset = queryset.filter(project_id=project_id)
        return queryset

    def perform_create(self, serializer):
        pm_user_id = _get_request_pm_user_id(self.request)
        pm_user = _get_pm_user_or_none(pm_user_id)
        if pm_user is None:
            project = serializer.validated_data.get('project_id')
            if project is not None and getattr(project, 'user_id', None) is not None:
                pm_user = project.user
        serializer.save(created_by=pm_user)

    @action(
        detail=True,
        methods=['post'],
        url_path='upload-photo',
        parser_classes=[MultiPartParser, FormParser],
    )
    def upload_photo(self, request, pk=None):
        """Upload/replace a client photo.

        Accepts multipart form-data with `image` (preferred) or `photo`.
        Saves to MEDIA_ROOT/client_images/ with filename cl_<user_id>_<client_id>.<ext>
        """
        client = self.get_object()

        uploaded = request.FILES.get('image') or request.FILES.get('photo')
        if uploaded is None:
            return Response(
                {'detail': 'No file provided. Use multipart field "image".'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Verify face presence before mutating existing state.
        image_bytes = uploaded.read()
        try:
            uploaded.seek(0)
        except Exception:
            pass

        if not verify_image_has_human_face(image_bytes):
            return Response(
                {
                    'image_verification': 'REJECT',
                    'detail': 'No human face detected in the uploaded image.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Delete existing photo so the next save reuses the same name.
        if getattr(client, 'photo', None):
            try:
                client.photo.delete(save=False)
            except Exception:
                # Best-effort cleanup; continue with overwrite.
                pass

        ext = os.path.splitext(getattr(uploaded, 'name', '') or '')[1].lower()
        if not ext:
            ext = '.jpg'

        pm_user_id = getattr(client, 'created_by_id', None) or _get_request_pm_user_id(request) or 0
        filename = f'cl_{pm_user_id}_{client.client_id}{ext}'
        client.photo.save(filename, uploaded, save=True)

        data = self.get_serializer(client).data
        data['image_verification'] = 'ACCEPT'
        return Response(
            data,
            status=status.HTTP_200_OK,
        )


class BackJobReviewViewSet(viewsets.ModelViewSet):
    queryset = models.BackJobReview.objects.select_related('project', 'client').all()
    serializer_class = BackJobReviewSerializer

    def get_queryset(self):
        queryset = self.queryset
        project_id = self.request.query_params.get('project_id')
        client_id = self.request.query_params.get('client_id')
        is_resolved = self.request.query_params.get('is_resolved')

        if project_id:
            queryset = queryset.filter(project_id=project_id)
        if client_id:
            queryset = queryset.filter(client_id=client_id)
        if is_resolved in ['true', 'false']:
            queryset = queryset.filter(is_resolved=(is_resolved == 'true'))
        return queryset

    def create(self, request, *args, **kwargs):
        mutable_data = request.data.copy()
        project_id = mutable_data.get('project')
        client_id = mutable_data.get('client')
        client_user_id = mutable_data.get('client_user_id')

        if not project_id:
            return Response(
                {'detail': 'project is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        project = models.Project.objects.filter(project_id=project_id).first()
        if project is None:
            return Response(
                {'detail': 'Project not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        client = None

        # 1) Preferred: explicit client_id
        if client_id not in [None, '']:
            client = models.Client.objects.filter(client_id=client_id).first()
            # Legacy fallback: some clients send User.user_id instead of Client.client_id.
            if client is None:
                client = (
                    models.Client.objects.filter(user_id_id=client_id).first()
                    or models.Client.objects.filter(project_id=project).first()
                )

        # 2) Fallback: explicit client_user_id from mobile app
        if client is None and client_user_id not in [None, '']:
            client = models.Client.objects.filter(user_id_id=client_user_id).first()

        # 3) Fallback: project assignment links
        if client is None:
            if project.client_id:
                client = models.Client.objects.filter(client_id=project.client_id).first()
            if client is None:
                client = models.Client.objects.filter(project_id=project).first()

        if client is None:
            return Response(
                {'detail': 'Client not found for this project.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        assigned_via_client_fk = client.project_id_id == project.project_id
        assigned_via_project_fk = project.client_id == client.client_id

        if not assigned_via_client_fk and not assigned_via_project_fk:
            return Response(
                {'detail': 'Client is not assigned to this project.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        mutable_data['project'] = project.project_id
        mutable_data['client'] = client.client_id

        serializer = self.get_serializer(data=mutable_data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)


# Phase ViewSet
class PhaseViewSet(viewsets.ModelViewSet):
    queryset = models.Phase.objects.all()
    serializer_class = PhaseSerializer

    def get_queryset(self):
        queryset = models.Phase.objects.all().order_by('-created_at', '-phase_id')
        project_id = self.request.query_params.get('project_id')
        if project_id:
            queryset = queryset.filter(project_id=project_id)
        return queryset


# Subtask ViewSet
class SubtaskViewSet(viewsets.ModelViewSet):
    queryset = models.Subtask.objects.all()
    serializer_class = SubtaskSerializer

    def get_queryset(self):
        queryset = models.Subtask.objects.all()
        phase_id = self.request.query_params.get('phase_id')
        project_id = self.request.query_params.get('project_id')
        if phase_id:
            queryset = queryset.filter(phase_id=phase_id)
        if project_id:
            queryset = queryset.filter(phase__project_id=project_id)
        return queryset

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()

        previous_status = instance.status
        previous_notes = (instance.progress_notes or '').strip()

        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)

        updated_subtask = serializer.instance

        uploaded_photos = []
        if hasattr(request, 'FILES') and request.FILES:
            uploaded_photos.extend(request.FILES.getlist('images'))
            uploaded_photos.extend(request.FILES.getlist('photos'))
            single_image = request.FILES.get('image')
            single_photo = request.FILES.get('photo')
            if single_image is not None:
                uploaded_photos.append(single_image)
            if single_photo is not None:
                uploaded_photos.append(single_photo)

        if uploaded_photos:
            existing_count = updated_subtask.update_photos.count()
            available_slots = max(0, 5 - existing_count)
            for uploaded in uploaded_photos[:available_slots]:
                models.SubtaskPhoto.objects.create(
                    subtask=updated_subtask,
                    photo=uploaded,
                )

        new_status = updated_subtask.status
        new_notes = (updated_subtask.progress_notes or '').strip()

        status_changed = previous_status != new_status
        notes_changed = previous_notes != new_notes
        has_photo_submission = bool(request.FILES) or any(
            key in request.data for key in ('photo', 'photos', 'image', 'images')
        )

        if status_changed or notes_changed or has_photo_submission:
            phase = getattr(updated_subtask, 'phase', None)
            project = getattr(phase, 'project', None) if phase is not None else None
            client = None
            if project is not None:
                if getattr(project, 'client', None) is not None:
                    client = project.client
                if client is None:
                    client = models.Client.objects.filter(project_id=project).first()

            if client is not None and (client.email or '').strip():
                supervisor_name = "Supervisor"
                supervisor_id_raw = (
                    request.query_params.get('supervisor_id')
                    or request.data.get('supervisor_id')
                    or request.headers.get('X-Supervisor-Id')
                )
                if supervisor_id_raw not in (None, ''):
                    try:
                        supervisor = models.Supervisors.objects.filter(
                            supervisor_id=int(supervisor_id_raw)
                        ).first()
                        if supervisor is not None:
                            full_name = f"{(supervisor.first_name or '').strip()} {(supervisor.last_name or '').strip()}".strip()
                            if full_name:
                                supervisor_name = full_name
                    except (TypeError, ValueError):
                        pass

                queue_key = (
                    "phase_update_email_queue:"
                    f"{getattr(client, 'client_id', 'unknown')}:"
                    f"{getattr(phase, 'phase_id', 'unknown')}"
                )
                _queue_phase_update_notification(
                    queue_key=queue_key,
                    summary_payload={
                        'to_email': client.email,
                        'client_first_name': getattr(client, 'first_name', None),
                        'project_name': getattr(project, 'project_name', None),
                        'phase_name': getattr(phase, 'phase_name', None),
                        'subtask_title': getattr(updated_subtask, 'title', None),
                        'subtask_status': (new_status or '').replace('_', ' ').title(),
                        'update_action': (
                            'Unsubmitted'
                            if previous_status == 'completed' and new_status == 'pending'
                            else 'Submitted'
                            if previous_status != 'completed' and new_status == 'completed'
                            else 'Updated'
                        ),
                        'progress_notes': updated_subtask.progress_notes,
                        'supervisor_name': supervisor_name,
                        'has_photo': has_photo_submission,
                    },
                )

        return Response(serializer.data)


# SubtaskFieldWorker ViewSet
class SubtaskFieldWorkerViewSet(viewsets.ModelViewSet):
    queryset = models.SubtaskFieldWorker.objects.all()
    serializer_class = SubtaskFieldWorkerSerializer

    def get_queryset(self):
        queryset = models.SubtaskFieldWorker.objects.all()
        subtask_id = self.request.query_params.get('subtask_id')
        if subtask_id:
            queryset = queryset.filter(subtask_id=subtask_id)
        return queryset

    def create(self, request, *args, **kwargs):
        # Support bulk assignment
        if isinstance(request.data, list):
            serializer = self.get_serializer(data=request.data, many=True)
            serializer.is_valid(raise_exception=True)
            self.perform_create(serializer)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return super().create(request, *args, **kwargs)

    def destroy(self, request, *args, **kwargs):
        # Allow deleting all assignments for a subtask via query param
        subtask_id = request.query_params.get('subtask_id')
        if subtask_id:
            deleted_count = models.SubtaskFieldWorker.objects.filter(
                subtask_id=subtask_id
            ).delete()[0]
            return Response(
                {'deleted': deleted_count},
                status=status.HTTP_204_NO_CONTENT
            )
        return super().destroy(request, *args, **kwargs)


# Attendance ViewSet
class AttendanceViewSet(viewsets.ModelViewSet):
    queryset = models.Attendance.objects.all()
    serializer_class = AttendanceSerializer

    def get_queryset(self):
        queryset = models.Attendance.objects.all()
        project_id = self.request.query_params.get('project_id')
        attendance_date = self.request.query_params.get('attendance_date')
        field_worker_id = self.request.query_params.get('field_worker_id')
        
        if project_id:
            queryset = queryset.filter(project_id=project_id)
        if attendance_date:
            queryset = queryset.filter(attendance_date=attendance_date)
        if field_worker_id:
            queryset = queryset.filter(field_worker_id=field_worker_id)
        
        return queryset.select_related('field_worker', 'project').order_by('-attendance_date')

    @action(detail=False, methods=['get'], url_path='supervisor-overview')
    def supervisor_overview(self, request):
        project_id_raw = request.query_params.get('project_id')
        attendance_date = request.query_params.get('attendance_date')
        supervisor_id_raw = request.query_params.get('supervisor_id')

        if not project_id_raw:
            return Response(
                {'detail': 'project_id is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            project_id = int(project_id_raw)
        except (TypeError, ValueError):
            return Response(
                {'detail': 'project_id must be an integer'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        workers_qs = models.FieldWorker.objects.filter(
            Q(project_id=project_id)
            | Q(subtask_assignments__subtask__phase__project_id=project_id)
        )

        if supervisor_id_raw:
            try:
                supervisor_id = int(supervisor_id_raw)
            except (TypeError, ValueError):
                return Response(
                    {'detail': 'supervisor_id must be an integer'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            supervisor_project_ids = models.Project.objects.filter(
                Q(supervisor_id=supervisor_id) | Q(supervisors__supervisor_id=supervisor_id)
            ).values_list('project_id', flat=True)

            workers_qs = workers_qs.filter(
                Q(project_id__in=supervisor_project_ids)
                | Q(subtask_assignments__subtask__phase__project_id__in=supervisor_project_ids)
            )

        workers_qs = workers_qs.select_related('project_id').distinct()

        attendance_qs = models.Attendance.objects.filter(project_id=project_id)
        if attendance_date:
            attendance_qs = attendance_qs.filter(attendance_date=attendance_date)

        attendance_qs = attendance_qs.select_related('field_worker', 'project').order_by('-attendance_date')

        shift_assignments = models.SubtaskFieldWorker.objects.filter(
            field_worker__in=workers_qs,
            subtask__phase__project_id=project_id,
            shift_start__isnull=False,
            shift_end__isnull=False
        ).order_by('field_worker_id', 'shift_start', 'assignment_id')
        
        worker_shifts = {}
        for sa in shift_assignments:
            if sa.field_worker_id not in worker_shifts:
                worker_shifts[sa.field_worker_id] = {
                    'shift_start': sa.shift_start.strftime('%H:%M:%S'),
                    'shift_end': sa.shift_end.strftime('%H:%M:%S')
                }

        field_workers_payload = [
            {
                'fieldworker_id': worker.fieldworker_id,
                'project_id': worker.project_id_id,
                'first_name': worker.first_name,
                'last_name': worker.last_name,
                'role': worker.role,
                'photo': worker.photo.url if getattr(worker, 'photo', None) else None,
                'shift_start': worker_shifts.get(worker.fieldworker_id, {}).get('shift_start'),
                'shift_end': worker_shifts.get(worker.fieldworker_id, {}).get('shift_end'),
                'current_project_shift_start': worker_shifts.get(worker.fieldworker_id, {}).get('shift_start'),
                'current_project_shift_end': worker_shifts.get(worker.fieldworker_id, {}).get('shift_end'),
            }
            for worker in workers_qs.order_by('first_name', 'last_name', 'fieldworker_id')
        ]

        return Response(
            {
                'project_id': project_id,
                'attendance_date': attendance_date,
                'field_workers': field_workers_payload,
                'attendance': AttendanceSerializer(attendance_qs, many=True).data,
            },
            status=status.HTTP_200_OK,
        )


@csrf_exempt
@api_view(['GET'])
def pm_dashboard_summary(request):
    """Return a summary payload for the Project Manager dashboard."""
    user_id_raw = request.query_params.get('user_id')
    if not user_id_raw:
        return Response(
            {'success': False, 'message': 'user_id is required'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        user_id = int(user_id_raw)
    except (TypeError, ValueError):
        return Response(
            {'success': False, 'message': 'user_id must be an integer'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Projects (recent)
    projects_qs = (
        models.Project.objects.filter(user_id=user_id)
        .select_related('barangay', 'city', 'province')
        .annotate(
            total_subtasks=Count('phases__subtasks', distinct=True),
            completed_subtasks=Count(
                'phases__subtasks',
                filter=Q(phases__subtasks__status='completed'),
                distinct=True,
            ),
        )
        .order_by('-created_at')
    )

    total_projects = projects_qs.count()
    recent_projects = []
    for p in projects_qs[:3]:
        location_parts = []
        if p.street:
            location_parts.append(p.street)
        if p.barangay_id and getattr(p.barangay, 'name', None):
            location_parts.append(p.barangay.name)
        if p.city_id and getattr(p.city, 'name', None):
            location_parts.append(p.city.name)
        if p.province_id and getattr(p.province, 'name', None):
            location_parts.append(p.province.name)
        location = ', '.join(location_parts) if location_parts else 'N/A'

        total_subtasks = int(getattr(p, 'total_subtasks', 0) or 0)
        completed_subtasks = int(getattr(p, 'completed_subtasks', 0) or 0)
        progress = (completed_subtasks / total_subtasks) if total_subtasks else 0.0

        recent_projects.append(
            {
                'project_id': p.project_id,
                'project_name': p.project_name,
                'location': location,
                'progress': float(progress),
                'tasks_completed': completed_subtasks,
                'total_tasks': total_subtasks,
                'created_at': p.created_at.isoformat() if p.created_at else None,
            }
        )

    # Tasks summary
    subtasks_qs = models.Subtask.objects.filter(phase__project__user_id=user_id)
    task_counts = subtasks_qs.aggregate(
        total=Count('subtask_id'),
        completed=Count('subtask_id', filter=Q(status='completed')),
        in_progress=Count('subtask_id', filter=Q(status='in_progress')),
        pending=Count('subtask_id', filter=Q(status='pending')),
    )
    total_subtasks = int(task_counts.get('total') or 0)
    completed_subtasks = int(task_counts.get('completed') or 0)
    in_progress_subtasks = int(task_counts.get('in_progress') or 0)
    pending_subtasks = int(task_counts.get('pending') or 0)
    assigned_subtasks = (
        subtasks_qs.filter(assigned_workers__isnull=False).distinct().count()
    )

    completion_rate = (
        (completed_subtasks / total_subtasks) * 100.0 if total_subtasks else 0.0
    )

    # Activity (completed tasks per day for last 7 days)
    start_day = timezone.localdate() - timedelta(days=6)
    end_day = timezone.localdate()

    completed_by_day = (
        subtasks_qs.filter(status='completed', updated_at__date__gte=start_day)
        .annotate(day=TruncDate('updated_at'))
        .values('day')
        .annotate(count=Count('subtask_id'))
        .order_by('day')
    )
    completed_map = {
        row['day'].isoformat(): int(row['count']) for row in completed_by_day
    }

    activity_series = []
    for i in range(7):
        day = start_day + timedelta(days=i)
        day_key = day.isoformat()
        activity_series.append({'day': day_key, 'completed': completed_map.get(day_key, 0)})

    # Workers summary
    supervisors_count = models.Supervisors.objects.filter(project_id__user_id=user_id).count()
    field_workers_qs = models.FieldWorker.objects.filter(project_id__user_id=user_id)
    field_workers_total = field_workers_qs.count()
    field_workers_by_role = (
        field_workers_qs.values('role')
        .annotate(count=Count('fieldworker_id'))
        .order_by('-count')
    )
    by_role = {row['role']: int(row['count']) for row in field_workers_by_role}

    # Notifications / Task Today are derived from most recently updated open subtasks
    open_subtasks_qs = subtasks_qs.exclude(status='completed')
    open_subtasks_count = open_subtasks_qs.count()

    recent_open_subtasks = list(
        open_subtasks_qs
        .select_related('phase__project')
        .prefetch_related(
            Prefetch(
                'assigned_workers',
                queryset=models.SubtaskFieldWorker.objects.select_related('field_worker'),
            )
        )
        .order_by('-updated_at')[:20]
    )

    recent_open_items = []
    for st in recent_open_subtasks:
        assigned_workers = []
        for assignment in st.assigned_workers.all():
            w = assignment.field_worker
            if w is None:
                continue
            assigned_workers.append(
                {
                    'assignment_id': assignment.assignment_id,
                    'fieldworker_id': w.fieldworker_id,
                    'first_name': w.first_name,
                    'last_name': w.last_name,
                    'role': w.role,
                }
            )

        recent_open_items.append(
            {
                'subtask_id': st.subtask_id,
                'title': st.title,
                'status': st.status,
                'project_id': st.phase.project.project_id if st.phase_id else None,
                'project_name': st.phase.project.project_name if st.phase_id else None,
                'updated_at': st.updated_at.isoformat() if st.updated_at else None,
                'assigned_workers': assigned_workers,
            }
        )

    tasks_today = recent_open_items[:5]

    return Response(
        {
            'success': True,
            'projects': {
                'total': total_projects,
                'recent': recent_projects,
            },
            'tasks': {
                'total': total_subtasks,
                'completed': completed_subtasks,
                'in_progress': in_progress_subtasks,
                'pending': pending_subtasks,
                'assigned': assigned_subtasks,
                'completion_rate': float(completion_rate),
            },
            'activity': {
                'start_day': start_day.isoformat(),
                'end_day': end_day.isoformat(),
                'series': activity_series,
            },
            'workers': {
                'supervisors': supervisors_count,
                'field_workers_total': field_workers_total,
                'by_role': by_role,
            },
            'tasks_today': tasks_today,
            'notifications': {
                'count': int(open_subtasks_count),
                'items': recent_open_items,
            },
        },
        status=status.HTTP_200_OK,
    )


# ── Inventory ViewSets ───────────────────────────────────────────────────────

class InventoryItemViewSet(viewsets.ModelViewSet):
    serializer_class = InventoryItemSerializer

    def destroy(self, request, *args, **kwargs):
        item = self.get_object()
        assigned_count = item.units.exclude(current_project__isnull=True).count()
        if assigned_count > 0:
            return Response(
                {
                    'error': (
                        'Cannot delete this item while units are assigned to projects. '
                        'Unassign all units first.'
                    ),
                },
                status=400,
            )
        return super().destroy(request, *args, **kwargs)

    @staticmethod
    def _unit_prefix(name):
        base = re.sub(r'[^A-Z0-9]+', '-', (name or '').upper()).strip('-')
        return base or 'ITEM'

    def _next_unit_codes(self, item_name, quantity):
        prefix = self._unit_prefix(item_name)
        last_code = (
            models.InventoryUnit.objects.filter(unit_code__startswith=f'{prefix}-')
            .order_by('-unit_code')
            .values_list('unit_code', flat=True)
            .first()
        )
        start = 1
        if last_code:
            suffix = last_code.split('-')[-1]
            if suffix.isdigit():
                start = int(suffix) + 1
        return [f'{prefix}-{str(i).zfill(3)}' for i in range(start, start + quantity)]

    def _refresh_item_status_from_units(self, item):
        if item.units.filter(status='Checked Out').exists():
            next_status = 'Checked Out'
        elif item.units.filter(status='Maintenance').exists():
            next_status = 'Maintenance'
        elif item.units.filter(status='Unavailable').exists():
            next_status = 'Unavailable'
        else:
            next_status = 'Available'

        if item.status != next_status:
            item.status = next_status
            item.save(update_fields=['status', 'updated_at'])

    def get_queryset(self):
        pm_user_id = _get_request_pm_user_id(self.request)
        supervisor_id = self.request.query_params.get('supervisor_id')

        # Supervisor accessing inventory: show items assigned to projects
        # the supervisor is assigned to.
        if supervisor_id:
            try:
                sv = models.Supervisors.objects.get(supervisor_id=int(supervisor_id))
            except (models.Supervisors.DoesNotExist, ValueError, TypeError):
                return models.InventoryItem.objects.none()
            # Find project IDs the supervisor is assigned to
            project_ids = list(
                models.Project.objects
                .filter(supervisor_id=sv.supervisor_id)
                .values_list('project_id', flat=True)
            )
            return models.InventoryItem.objects.filter(
                Q(units__current_project_id__in=project_ids)
                | Q(project_id__in=project_ids)
            ).distinct()

        # PM accessing inventory
        if pm_user_id is not None:
            return models.InventoryItem.objects.filter(created_by_id=pm_user_id)

        return models.InventoryItem.objects.none()

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx['request'] = self.request
        return ctx

    @transaction.atomic
    def perform_create(self, serializer):
        pm_user_id = _get_request_pm_user_id(self.request)
        pm_user = _get_pm_user_or_none(pm_user_id)
        if pm_user is None:
            from rest_framework.exceptions import ValidationError
            raise ValidationError('A valid user_id (ProjectManager) is required.')

        quantity_raw = self.request.data.get('quantity')
        try:
            quantity = max(1, int(quantity_raw or 1))
        except (TypeError, ValueError):
            quantity = 1

        save_kwargs = {'created_by': pm_user, 'status': 'Available', 'quantity': 0}

        project_id = self.request.data.get('project_id') or self.request.data.get('project')
        project = None
        if project_id:
            try:
                project = models.Project.objects.get(project_id=int(project_id))
                save_kwargs['project'] = project
            except (models.Project.DoesNotExist, ValueError, TypeError):
                pass

        item = serializer.save(**save_kwargs)

        serial_number = (self.request.data.get('serial_number') or '').strip()
        serial_numbers = self.request.data.get('serial_numbers')

        provided_codes = []
        if isinstance(serial_numbers, list):
            provided_codes = [str(code).strip() for code in serial_numbers if str(code).strip()]
        elif isinstance(serial_numbers, str) and serial_numbers.strip():
            try:
                parsed = json.loads(serial_numbers)
                if isinstance(parsed, list):
                    provided_codes = [str(code).strip() for code in parsed if str(code).strip()]
            except Exception:
                provided_codes = []

        if not provided_codes and quantity == 1 and serial_number:
            provided_codes = [serial_number]

        existing_codes = set(
            models.InventoryUnit.objects.filter(unit_code__in=provided_codes)
            .values_list('unit_code', flat=True)
        )
        if existing_codes:
            raise ValidationError(
                f'Serial number(s) already in use: {", ".join(sorted(existing_codes))}'
            )

        if len(provided_codes) > quantity:
            provided_codes = provided_codes[:quantity]

        generated_needed = max(0, quantity - len(provided_codes))
        generated_codes = self._next_unit_codes(item.name, generated_needed) if generated_needed else []
        unit_codes = provided_codes + generated_codes

        for code in unit_codes:
            unit = models.InventoryUnit.objects.create(
                inventory_item=item,
                unit_code=code,
                status='Available',
                current_project=project,
            )
            if project:
                models.InventoryUnitMovement.objects.create(
                    unit=unit,
                    from_project=None,
                    to_project=project,
                    action='Assigned',
                    moved_by=pm_user,
                    notes='Initial assignment during profile creation',
                )

        item.sync_quantity_from_units()

    @action(detail=True, methods=['post'], url_path='add_units')
    @transaction.atomic
    def add_units(self, request, pk=None):
        item = self.get_object()
        pm_user_id = _get_request_pm_user_id(request)
        pm_user = _get_pm_user_or_none(pm_user_id)
        if pm_user is None:
            return Response({'error': 'A valid user_id is required.'}, status=400)

        count_raw = request.data.get('count', 1)
        try:
            count = max(1, int(count_raw))
        except (TypeError, ValueError):
            return Response({'error': 'count must be a positive integer.'}, status=400)

        serial_numbers = request.data.get('serial_numbers')
        provided_codes = []
        if isinstance(serial_numbers, list):
            provided_codes = [str(code).strip() for code in serial_numbers if str(code).strip()]
        elif isinstance(serial_numbers, str) and serial_numbers.strip():
            try:
                parsed = json.loads(serial_numbers)
                if isinstance(parsed, list):
                    provided_codes = [str(code).strip() for code in parsed if str(code).strip()]
            except Exception:
                provided_codes = []

        if len(provided_codes) > count:
            provided_codes = provided_codes[:count]

        existing_codes = set(
            models.InventoryUnit.objects.filter(unit_code__in=provided_codes)
            .values_list('unit_code', flat=True)
        )
        if existing_codes:
            return Response(
                {
                    'error': f'Serial number(s) already in use: {", ".join(sorted(existing_codes))}',
                },
                status=400,
            )

        generated_needed = max(0, count - len(provided_codes))
        generated_codes = self._next_unit_codes(item.name, generated_needed) if generated_needed else []
        unit_codes = provided_codes + generated_codes

        created_units = []
        default_project = item.project
        for code in unit_codes:
            unit = models.InventoryUnit.objects.create(
                inventory_item=item,
                unit_code=code,
                status='Available',
                current_project=default_project,
            )
            created_units.append(unit)
            if default_project:
                models.InventoryUnitMovement.objects.create(
                    unit=unit,
                    from_project=None,
                    to_project=default_project,
                    action='Assigned',
                    moved_by=pm_user,
                    notes='Added unit from manage modal',
                )

        item.sync_quantity_from_units()
        self._refresh_item_status_from_units(item)

        return Response(
            {
                'message': f'Added {len(created_units)} unit(s) to {item.name}',
                'created_units': InventoryUnitSerializer(created_units, many=True).data,
                'item': InventoryItemSerializer(item, context={'request': request}).data,
            }
        )

    @action(detail=True, methods=['post'], url_path='remove_units')
    @transaction.atomic
    def remove_units(self, request, pk=None):
        item = self.get_object()

        count_raw = request.data.get('count', 1)
        try:
            count = max(1, int(count_raw))
        except (TypeError, ValueError):
            return Response({'error': 'count must be a positive integer.'}, status=400)

        removable_units = (
            item.units.filter(
                status__in=['Available', 'Returned'],
                current_project__isnull=True,
            )
            .exclude(usages__status='Checked Out')
            .order_by('-created_at', '-unit_id')
            .distinct()
        )

        available_count = removable_units.count()
        if count > available_count:
            return Response(
                {
                    'error': (
                        f'Cannot remove {count} unit(s). '
                        f'Only {available_count} unassigned removable unit(s) are available.'
                    ),
                },
                status=400,
            )

        units_to_remove = list(removable_units[:count])
        removed_codes = [u.unit_code for u in units_to_remove]
        for unit in units_to_remove:
            unit.delete()

        item.refresh_from_db()
        item.sync_quantity_from_units()
        self._refresh_item_status_from_units(item)

        return Response(
            {
                'message': f'Removed {len(removed_codes)} unit(s) from {item.name}',
                'removed_unit_codes': removed_codes,
                'item': InventoryItemSerializer(item, context={'request': request}).data,
            }
        )

    @action(detail=True, methods=['get'], url_path='units')
    def units(self, request, pk=None):
        item = self.get_object()
        queryset = item.units.select_related('current_project')
        data = InventoryUnitSerializer(queryset, many=True).data
        return Response(data)

    @action(detail=True, methods=['post'], url_path='assign_unit')
    def assign_unit(self, request, pk=None):
        item = self.get_object()
        pm_user_id = _get_request_pm_user_id(request)
        pm_user = _get_pm_user_or_none(pm_user_id)
        if pm_user is None:
            return Response({'error': 'A valid user_id is required.'}, status=400)

        unit_id = request.data.get('unit_id')
        project_id_raw = request.data.get('project_id')
        if not unit_id:
            return Response({'error': 'unit_id is required.'}, status=400)

        try:
            unit = item.units.get(unit_id=int(unit_id))
        except (models.InventoryUnit.DoesNotExist, ValueError, TypeError):
            return Response({'error': 'Invalid unit_id.'}, status=404)

        target_project = None
        if project_id_raw not in (None, '', 'null', 'None'):
            try:
                target_project = models.Project.objects.get(project_id=int(project_id_raw))
            except (models.Project.DoesNotExist, ValueError, TypeError):
                return Response({'error': 'Invalid project_id.'}, status=404)

        previous_project = unit.current_project
        if (previous_project is None and target_project is None) or (
            previous_project and target_project and previous_project.project_id == target_project.project_id
        ):
            if target_project:
                return Response(
                    {
                        'message': f'{unit.unit_code} is already assigned to {target_project.project_name}',
                        'unit': InventoryUnitSerializer(unit).data,
                    }
                )
            return Response(
                {
                    'message': f'{unit.unit_code} is already unassigned',
                    'unit': InventoryUnitSerializer(unit).data,
                }
            )

        if unit.status == 'Checked Out':
            return Response(
                {
                    'error': (
                        'This unit is currently checked out and cannot be reassigned. '
                        'Return it first before changing project assignment.'
                    ),
                },
                status=400,
            )

        unit.current_project = target_project
        if target_project and unit.status == 'Returned':
            unit.status = 'Available'
        unit.save(update_fields=['current_project', 'status', 'updated_at'])

        if previous_project and target_project:
            action_name = 'Transferred'
            notes = f'Transferred from {previous_project.project_name} to {target_project.project_name}'
        elif previous_project and not target_project:
            action_name = 'Transferred'
            notes = f'Unassigned from {previous_project.project_name}'
        else:
            action_name = 'Assigned'
            notes = f'Assigned to {target_project.project_name}' if target_project else 'Assigned'

        models.InventoryUnitMovement.objects.create(
            unit=unit,
            from_project=previous_project,
            to_project=target_project,
            action=action_name,
            moved_by=pm_user,
            notes=notes,
        )

        self._refresh_item_status_from_units(item)
        if target_project:
            message = f'{unit.unit_code} assigned to {target_project.project_name}'
        else:
            message = f'{unit.unit_code} unassigned from project'

        return Response(
            {
                'message': message,
                'unit': InventoryUnitSerializer(unit).data,
            }
        )

    @action(detail=True, methods=['post'], url_path='set_unit_status')
    def set_unit_status(self, request, pk=None):
        item = self.get_object()
        pm_user_id = _get_request_pm_user_id(request)
        pm_user = _get_pm_user_or_none(pm_user_id)
        if pm_user is None:
            return Response({'error': 'A valid user_id is required.'}, status=400)

        unit_id = request.data.get('unit_id')
        status_raw = (request.data.get('status') or '').strip().lower()

        if not unit_id or not status_raw:
            return Response({'error': 'unit_id and status are required.'}, status=400)

        allowed_statuses = {
            'available': 'Available',
            'maintenance': 'Maintenance',
            'unavailable': 'Unavailable',
        }
        next_status = allowed_statuses.get(status_raw)
        if not next_status:
            return Response(
                {
                    'error': 'Invalid status. Allowed values: available, maintenance, unavailable.',
                },
                status=400,
            )

        try:
            unit = item.units.get(unit_id=int(unit_id))
        except (models.InventoryUnit.DoesNotExist, ValueError, TypeError):
            return Response({'error': 'Invalid unit_id.'}, status=404)

        if unit.status == 'Checked Out':
            return Response({'error': 'Cannot change status while unit is checked out.'}, status=400)

        previous_status = unit.status
        if previous_status == next_status:
            return Response(
                {
                    'message': f'{unit.unit_code} status is already {next_status}.',
                    'unit': InventoryUnitSerializer(unit).data,
                }
            )

        unit.status = next_status
        unit.save(update_fields=['status', 'updated_at'])

        models.InventoryUnitMovement.objects.create(
            unit=unit,
            from_project=unit.current_project,
            to_project=unit.current_project,
            action='Status Updated',
            moved_by=pm_user,
            notes=f'Status changed from {previous_status} to {next_status}',
        )

        self._refresh_item_status_from_units(item)

        return Response(
            {
                'message': f'{unit.unit_code} status changed to {next_status}',
                'unit': InventoryUnitSerializer(unit).data,
            }
        )

    @action(detail=True, methods=['get'], url_path='unit_movements')
    def unit_movements(self, request, pk=None):
        item = self.get_object()
        unit_id = request.query_params.get('unit_id')
        qs = models.InventoryUnitMovement.objects.filter(unit__inventory_item=item).select_related(
            'unit', 'from_project', 'to_project', 'moved_by'
        )
        if unit_id:
            qs = qs.filter(unit_id=unit_id)
        return Response(InventoryUnitMovementSerializer(qs, many=True).data)

    @action(
        detail=True,
        methods=['post'],
        url_path='upload_photo',
        parser_classes=[MultiPartParser, FormParser],
    )
    def upload_photo(self, request, pk=None):
        """Upload/replace an inventory item photo."""
        item = self.get_object()
        image_file = request.FILES.get('image')
        if not image_file:
            return Response({'error': 'No image file provided.'}, status=400)

        media_root = getattr(settings, 'MEDIA_ROOT', 'media')
        os.makedirs(os.path.join(media_root, 'inventory_images'), exist_ok=True)
        original_name = getattr(image_file, 'name', '') or ''
        ext = os.path.splitext(original_name)[1].lower() or '.jpg'
        filename = f'inv_{item.created_by_id}_{item.item_id}{ext}'
        file_path = os.path.join(media_root, 'inventory_images', filename)
        with open(file_path, 'wb+') as dest:
            for chunk in image_file.chunks():
                dest.write(chunk)

        rel_path = f'inventory_images/{filename}'
        item.photo = rel_path
        item.save()

        url = request.build_absolute_uri(settings.MEDIA_URL + rel_path)
        return Response({'url': url})

    @action(detail=True, methods=['post'], url_path='checkout')
    def checkout(self, request, pk=None):
        """Checkout one specific unit (or first available unit) of this item."""
        try:
            item = self.get_object()
            logger.info(f'Checkout request for item {pk}')
            
            supervisor_id = request.data.get('supervisor_id')
            if not supervisor_id:
                return Response({'error': 'supervisor_id is required.'}, status=400)
            try:
                supervisor_id_int = int(supervisor_id)
                supervisor = models.Supervisors.objects.get(supervisor_id=supervisor_id_int)
                logger.info(f'Found supervisor {supervisor_id_int}')
            except ValueError:
                logger.error(f'Invalid supervisor_id format: {supervisor_id}')
                return Response({'error': f'Invalid supervisor_id format: {supervisor_id}'}, status=400)
            except (models.Supervisors.DoesNotExist, TypeError) as e:
                logger.warning(f'Supervisor not found: {e}')
                return Response({'error': f'Supervisor {supervisor_id_int} not found.'}, status=404)

            supervisor_project_ids = list(
                models.Project.objects
                .filter(supervisor_id=supervisor.supervisor_id)
                .values_list('project_id', flat=True)
            )
            allowed_units_qs = item.units.filter(current_project_id__in=supervisor_project_ids)

            # Optional: field worker assignment
            field_worker = None
            field_worker_id = request.data.get('field_worker_id')
            if field_worker_id:
                try:
                    field_worker_id_int = int(field_worker_id)
                    field_worker = models.FieldWorker.objects.get(fieldworker_id=field_worker_id_int)
                    logger.info(f'Found field worker {field_worker_id_int}')
                except ValueError:
                    logger.error(f'Invalid field_worker_id format: {field_worker_id}')
                    return Response({'error': f'Invalid field_worker_id format: {field_worker_id}'}, status=400)
                except (models.FieldWorker.DoesNotExist, TypeError) as e:
                    logger.warning(f'Field worker not found: {e}')
                    return Response({'error': f'Field worker {field_worker_id_int} not found.'}, status=404)

            selected_project = None
            project_id_raw = request.data.get('project_id')
            if project_id_raw not in (None, '', 'null', 'None'):
                try:
                    selected_project_id = int(project_id_raw)
                except (TypeError, ValueError):
                    return Response({'error': f'Invalid project_id format: {project_id_raw}'}, status=400)

                if selected_project_id not in supervisor_project_ids:
                    return Response({'error': 'Selected project is not assigned to this supervisor.'}, status=403)

                if field_worker is not None:
                    worker_project_ids = set()
                    if field_worker.project_id_id is not None:
                        worker_project_ids.add(field_worker.project_id_id)

                    assigned_worker_project_ids = (
                        models.SubtaskFieldWorker.objects
                        .filter(
                            field_worker_id=field_worker.fieldworker_id,
                            subtask__phase__project_id__isnull=False,
                        )
                        .values_list('subtask__phase__project_id', flat=True)
                        .distinct()
                    )
                    worker_project_ids.update(assigned_worker_project_ids)

                    if selected_project_id not in worker_project_ids:
                        return Response(
                            {'error': 'Selected project is not one of this worker\'s assignments.'},
                            status=400,
                        )

                selected_project = models.Project.objects.filter(project_id=selected_project_id).first()
                if selected_project is None:
                    return Response({'error': 'Invalid project_id.'}, status=404)

            unit_id = request.data.get('unit_id')
            if unit_id:
                try:
                    unit = allowed_units_qs.get(unit_id=int(unit_id))
                except (models.InventoryUnit.DoesNotExist, ValueError, TypeError):
                    return Response({'error': 'Unit not found or not assigned to your project.'}, status=404)
                if unit.status == 'Checked Out':
                    return Response({'error': 'Selected unit is already checked out.'}, status=400)
            else:
                unit = (
                    allowed_units_qs.filter(status__in=['Available', 'Returned'])
                    .order_by('unit_code')
                    .first()
                )
                if not unit:
                    logger.warning(f'No available units for item {pk}')
                    return Response({'error': 'No available units assigned to your projects for checkout.'}, status=400)
            
            logger.info(f'Using unit {unit.unit_id} ({unit.unit_code})')

            project = selected_project or unit.current_project or item.project

            # Optional: expected return date - convert empty string to None
            expected_return_date = request.data.get('expected_return_date')
            if expected_return_date is not None and isinstance(expected_return_date, str) and not expected_return_date.strip():
                expected_return_date = None
            
            logger.info(f'Expected return date: {expected_return_date}')
            
            # Validate date format if provided
            from datetime import datetime
            if expected_return_date and isinstance(expected_return_date, str):
                try:
                    # Try to parse the date to ensure it's valid
                    datetime.strptime(expected_return_date, '%Y-%m-%d')
                    logger.info(f'Date validation passed: {expected_return_date}')
                except ValueError as de:
                    logger.error(f'Invalid date format: {expected_return_date}, error: {de}')
                    return Response({'error': f'Invalid date format: {expected_return_date}'}, status=400)

            # Create usage record
            usage = models.InventoryUsage.objects.create(
                inventory_item=item,
                inventory_unit=unit,
                checked_out_by=supervisor,
                field_worker=field_worker,
                project=project,
                expected_return_date=expected_return_date,
                notes=request.data.get('notes', '') or '',
            )
            logger.info(f'Created usage record {usage.usage_id}')
            
            unit.status = 'Checked Out'
            unit.save(update_fields=['status', 'updated_at'])
            logger.info(f'Updated unit status to Checked Out')
            
            self._refresh_item_status_from_units(item)
            logger.info(f'Refreshed item status')

            models.InventoryUnitMovement.objects.create(
                unit=unit,
                from_project=unit.current_project,
                to_project=unit.current_project,
                action='Checked Out',
                moved_by=_get_pm_user_or_none(_get_request_pm_user_id(request)),
                notes=request.data.get('notes', '') or '',
            )
            logger.info(f'Created unit movement record')

            assigned_to = f'{field_worker.first_name} {field_worker.last_name}' if field_worker else f'{supervisor.first_name} {supervisor.last_name}'
            return Response({
                'message': f'{unit.unit_code} checked out to {assigned_to}',
                'usage_id': usage.usage_id,
                'unit_id': unit.unit_id,
                'unit_code': unit.unit_code,
                'item': InventoryItemSerializer(item, context={'request': request}).data,
            })
        except Exception as e:
            logger.error(f'Checkout error: {str(e)}', exc_info=True)
            return Response({
                'error': f'Checkout failed: {str(e)}',
                'details': repr(e)
            }, status=500)

    @action(detail=True, methods=['post'], url_path='return_item')
    def return_item(self, request, pk=None):
        """Return this item (called by supervisor or PM)."""
        item = self.get_object()
        unit_id = request.data.get('unit_id')

        if unit_id:
            active_usage = item.usages.filter(
                inventory_unit_id=unit_id,
                status='Checked Out',
            ).order_by('-checkout_date').first()
        else:
            active_usage = item.usages.filter(status='Checked Out').order_by('-checkout_date').first()

        if not active_usage:
            return Response({'error': 'No active checkout found for this item.'}, status=400)

        active_usage.status = 'Returned'
        active_usage.actual_return_date = timezone.now()
        active_usage.save()

        unit = active_usage.inventory_unit
        if unit:
            unit.status = 'Returned'
            unit.save(update_fields=['status', 'updated_at'])
            models.InventoryUnitMovement.objects.create(
                unit=unit,
                from_project=unit.current_project,
                to_project=unit.current_project,
                action='Returned',
            )

        self._refresh_item_status_from_units(item)

        return Response({
            'message': f'{item.name} has been returned.',
            'unit_code': unit.unit_code if unit else '',
            'item': InventoryItemSerializer(item, context={'request': request}).data,
        })


class InventoryUsageViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = InventoryUsageSerializer

    def get_queryset(self):
        qs = models.InventoryUsage.objects.select_related(
            'inventory_item', 'checked_out_by'
        )
        pm_user_id = _get_request_pm_user_id(self.request)
        supervisor_id = self.request.query_params.get('supervisor_id')
        usage_status = self.request.query_params.get('status')

        if supervisor_id:
            qs = qs.filter(checked_out_by_id=int(supervisor_id))
        elif pm_user_id is not None:
            qs = qs.filter(inventory_item__created_by_id=pm_user_id)
        else:
            return models.InventoryUsage.objects.none()

        if usage_status:
            qs = qs.filter(status=usage_status)
        return qs