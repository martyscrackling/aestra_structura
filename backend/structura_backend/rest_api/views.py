from django.shortcuts import render
from rest_framework import generics, status, viewsets
from rest_framework.decorators import api_view
from rest_framework.response import Response
from django.contrib.auth.hashers import check_password
from django.views.decorators.csrf import csrf_exempt
from django.db.models import Count, Q
from django.db.models.functions import TruncDate
from django.utils import timezone
import json
from datetime import timedelta

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
    AttendanceSerializer
)

class ListUser(generics.ListCreateAPIView):
    queryset = models.User.objects.all()
    serializer_class = UserSerializer

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
                return Response({
                    'success': True,
                    'message': 'Login successful',
                    'user': {
                        'supervisor_id': supervisor.supervisor_id,
                        'user_id': supervisor.supervisor_id,  # Use supervisor_id as user_id
                        'project_id': supervisor.project_id.project_id if supervisor.project_id else None,
                        'email': supervisor.email,
                        'first_name': supervisor.first_name,
                        'last_name': supervisor.last_name,
                        'role': 'Supervisor',
                        'type': 'Supervisor',  # Indicate this is a supervisor
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
class ProjectViewSet(viewsets.ModelViewSet):
    serializer_class = ProjectSerializer
    
    def get_queryset(self):
        """
        Get projects only for the logged-in user
        SELECT * FROM projects WHERE user_id = user_id
        """
        # For now, get user_id from request headers or query params
        # In production, use authentication tokens
        user_id = self.request.query_params.get('user_id')
        client_id = self.request.query_params.get('client_id')
        
        print(f"🔍 ProjectViewSet get_queryset called")
        print(f"🔍 Received user_id: {user_id}")
        
        if client_id:
            queryset = models.Project.objects.filter(client_id=client_id).order_by('-created_at')
            print(f"✅ Filtered projects by client_id count: {queryset.count()}")
            return queryset

        if user_id:
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


# Supervisor ViewSet (alias for backwards compatibility)
class SupervisorViewSet(viewsets.ModelViewSet):
    queryset = models.Supervisors.objects.all()
    serializer_class = SupervisorSerializer


# FieldWorker ViewSet
class FieldWorkerViewSet(viewsets.ModelViewSet):
    queryset = models.FieldWorker.objects.all()
    serializer_class = FieldWorkerSerializer

    def get_queryset(self):
        queryset = models.FieldWorker.objects.all()
        project_id = self.request.query_params.get('project_id')
        if project_id:
            queryset = queryset.filter(project_id=project_id)
        return queryset


# Client ViewSet
class ClientViewSet(viewsets.ModelViewSet):
    queryset = models.Client.objects.all()
    serializer_class = ClientSerializer


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