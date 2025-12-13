from django.shortcuts import render
from rest_framework import generics, status, viewsets
from rest_framework.decorators import api_view
from rest_framework.response import Response
from django.contrib.auth.hashers import check_password
from django.views.decorators.csrf import csrf_exempt
import json

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
    ClientSerializer
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
    Can login as either a User (ProjectManager), Supervisor, or Client.
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
            pass  # Not a User, check if it's a Supervisor or Client
        
        # If not a regular user, check if they're a Supervisor
        try:
            supervisor = models.Supervisor.objects.get(email=email)
            # Check password
            if check_password(password, supervisor.password_hash):
                return Response({
                    'success': True,
                    'message': 'Login successful',
                    'user': {
                        'supervisor_id': supervisor.supervisor_id,
                        'email': supervisor.email,
                        'first_name': supervisor.first_name,
                        'last_name': supervisor.last_name,
                        'role': 'Supervisor',
                        'type': 'supervisor',  # Indicate this is a supervisor
                    }
                }, status=status.HTTP_200_OK)
            else:
                return Response(
                    {'success': False, 'message': 'Invalid password'},
                    status=status.HTTP_401_UNAUTHORIZED
                )
        except models.Supervisor.DoesNotExist:
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
                        'email': client.email,
                        'first_name': client.first_name,
                        'last_name': client.last_name,
                        'role': 'Client',
                        'type': 'client',  # Indicate this is a client
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
        
        print(f"🔍 ProjectViewSet get_queryset called")
        print(f"🔍 Received user_id: {user_id}")
        
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
        'total_supervisors': models.Supervisor.objects.count(),
        'total_clients': models.Client.objects.count(),
        'sample_users': list(models.User.objects.all().values('user_id', 'email')[:5]),
        'sample_projects': list(models.Project.objects.all().values('project_id', 'project_name', 'user_id')[:5]),
    })


# Supervisor ViewSet
class SupervisorViewSet(viewsets.ModelViewSet):
    queryset = models.Supervisor.objects.all()
    serializer_class = SupervisorSerializer


# Client ViewSet
class ClientViewSet(viewsets.ModelViewSet):
    queryset = models.Client.objects.all()
    serializer_class = ClientSerializer