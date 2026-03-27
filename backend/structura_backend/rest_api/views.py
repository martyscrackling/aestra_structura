from django.shortcuts import render
from rest_framework import generics, status, viewsets
from rest_framework.decorators import api_view, action
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from django.contrib.auth.hashers import check_password
from django.views.decorators.csrf import csrf_exempt
from django.db.models import Count, Q
from django.db.models.functions import TruncDate
from django.utils import timezone
import json
import os
from datetime import timedelta
import logging

logger = logging.getLogger(__name__)


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
    PhaseSerializer,
    SubtaskSerializer,
    SubtaskFieldWorkerSerializer,
    AttendanceSerializer,
    InventoryItemSerializer,
    InventoryUsageSerializer,
)

class ListUser(generics.ListCreateAPIView):
    queryset = models.User.objects.all()
    serializer_class = UserSerializer
    
    def create(self, request, *args, **kwargs):
        try:
            return super().create(request, *args, **kwargs)
        except Exception as e:
            logger.error(f"User creation error: {str(e)}", exc_info=True)
            return Response(
                {'success': False, 'message': f'Error creating user: {str(e)}'},
                status=status.HTTP_400_BAD_REQUEST
            )

class DetailUser(generics.RetrieveUpdateDestroyAPIView):
    queryset = models.User.objects.all()
    serializer_class = UserSerializer

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

        return Response(
            self.get_serializer(supervisor).data,
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

        return Response(
            self.get_serializer(supervisor).data,
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
            queryset = models.FieldWorker.objects.filter(project_id__in=sv_project_ids)
            if project_id:
                queryset = queryset.filter(project_id=project_id)
            return queryset.distinct()

        if pm_user_id is None:
            if project_id:
                return models.FieldWorker.objects.filter(project_id=project_id)
            return models.FieldWorker.objects.none()

        queryset = models.FieldWorker.objects.filter(
            Q(user_id=pm_user_id) | Q(project_id__user_id=pm_user_id)
        ).distinct()
        if project_id:
            queryset = queryset.filter(project_id=project_id)
        return queryset

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

        return Response(
            self.get_serializer(field_worker).data,
            status=status.HTTP_200_OK,
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
                return models.Client.objects.filter(project_id=project_id)
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

        return Response(
            self.get_serializer(client).data,
            status=status.HTTP_200_OK,
        )


# Phase ViewSet
class PhaseViewSet(viewsets.ModelViewSet):
    queryset = models.Phase.objects.all()
    serializer_class = PhaseSerializer

    def get_queryset(self):
        queryset = models.Phase.objects.all()
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
        
        return queryset.order_by('-attendance_date')


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
    total_subtasks = subtasks_qs.count()
    completed_subtasks = subtasks_qs.filter(status='completed').count()
    in_progress_subtasks = subtasks_qs.filter(status='in_progress').count()
    pending_subtasks = subtasks_qs.filter(status='pending').count()
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
    open_subtasks_count = subtasks_qs.exclude(status='completed').count()

    recent_open_subtasks = list(
        subtasks_qs.exclude(status='completed')
        .select_related('phase__project')
        .prefetch_related('assigned_workers__field_worker')
        .order_by('-updated_at')[:20]
    )

    recent_open_items = []
    for st in recent_open_subtasks:
        assigned_workers = []
        for assignment in st.assigned_workers.select_related('field_worker').all():
            w = assignment.field_worker
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
            return models.InventoryItem.objects.filter(project_id__in=project_ids)

        # PM accessing inventory
        if pm_user_id is not None:
            return models.InventoryItem.objects.filter(created_by_id=pm_user_id)

        return models.InventoryItem.objects.none()

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx['request'] = self.request
        return ctx

    def perform_create(self, serializer):
        pm_user_id = _get_request_pm_user_id(self.request)
        pm_user = _get_pm_user_or_none(pm_user_id)
        if pm_user is None:
            from rest_framework.exceptions import ValidationError
            raise ValidationError('A valid user_id (ProjectManager) is required.')
        # Always default to Available
        save_kwargs = {'created_by': pm_user, 'status': 'Available'}
        # Assign project if provided
        project_id = self.request.data.get('project_id') or self.request.data.get('project')
        if project_id:
            try:
                project = models.Project.objects.get(project_id=int(project_id))
                save_kwargs['project'] = project
            except (models.Project.DoesNotExist, ValueError, TypeError):
                pass
        serializer.save(**save_kwargs)

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
        """Checkout this item to a supervisor, optionally assigning to a field worker."""
        item = self.get_object()
        supervisor_id = request.data.get('supervisor_id')
        if not supervisor_id:
            return Response({'error': 'supervisor_id is required.'}, status=400)
        try:
            supervisor = models.Supervisors.objects.get(supervisor_id=int(supervisor_id))
        except (models.Supervisors.DoesNotExist, ValueError, TypeError):
            return Response({'error': 'Supervisor not found.'}, status=404)

        # Optional: field worker assignment
        field_worker = None
        field_worker_id = request.data.get('field_worker_id')
        if field_worker_id:
            try:
                field_worker = models.FieldWorker.objects.get(fieldworker_id=int(field_worker_id))
            except (models.FieldWorker.DoesNotExist, ValueError, TypeError):
                return Response({'error': 'Field worker not found.'}, status=404)

        # Use the item's assigned project
        project = item.project

        # Optional: expected return date
        expected_return_date = request.data.get('expected_return_date')

        # Create usage record
        usage = models.InventoryUsage.objects.create(
            inventory_item=item,
            checked_out_by=supervisor,
            field_worker=field_worker,
            project=project,
            expected_return_date=expected_return_date,
            notes=request.data.get('notes', ''),
        )
        item.status = 'Checked Out'
        item.save()

        assigned_to = f'{field_worker.first_name} {field_worker.last_name}' if field_worker else f'{supervisor.first_name} {supervisor.last_name}'
        return Response({
            'message': f'{item.name} checked out to {assigned_to}',
            'usage_id': usage.usage_id,
            'item': InventoryItemSerializer(item, context={'request': request}).data,
        })

    @action(detail=True, methods=['post'], url_path='return_item')
    def return_item(self, request, pk=None):
        """Return this item (called by supervisor or PM)."""
        item = self.get_object()
        # Find the active usage for this item
        active_usage = item.usages.filter(status='Checked Out').order_by('-checkout_date').first()
        if not active_usage:
            return Response({'error': 'No active checkout found for this item.'}, status=400)

        active_usage.status = 'Returned'
        active_usage.actual_return_date = timezone.now()
        active_usage.save()

        item.status = 'Returned'
        item.save()

        return Response({
            'message': f'{item.name} has been returned.',
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