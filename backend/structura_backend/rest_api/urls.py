from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    health_check,
    ListUser, 
    DetailUser, 
    login_user,
    RegionViewSet,
    ProvinceViewSet,
    CityViewSet,
    BarangayViewSet,
    ProjectViewSet,
    SupervisorViewSet,
    SupervisorsViewSet,
    FieldWorkerViewSet,
    ClientViewSet,
    PhaseViewSet,
    SubtaskViewSet,
    SubtaskFieldWorkerViewSet,
    AttendanceViewSet,
    pm_dashboard_summary,
    debug_projects,
    debug_all_data
)

router = DefaultRouter()
router.register(r'regions', RegionViewSet, basename='region')
router.register(r'provinces', ProvinceViewSet, basename='province')
router.register(r'cities', CityViewSet, basename='city')
router.register(r'barangays', BarangayViewSet, basename='barangay')
router.register(r'projects', ProjectViewSet, basename='project')
router.register(r'supervisors', SupervisorsViewSet, basename='supervisors')
router.register(r'field-workers', FieldWorkerViewSet, basename='fieldworker')
router.register(r'clients', ClientViewSet, basename='client')
router.register(r'phases', PhaseViewSet, basename='phase')
router.register(r'subtasks', SubtaskViewSet, basename='subtask')
router.register(r'subtask-assignments', SubtaskFieldWorkerViewSet, basename='subtask-assignment')
router.register(r'attendance', AttendanceViewSet, basename='attendance')

urlpatterns = [
    path('', include(router.urls)),
    path('health/', health_check, name='health_check'),
    path('users/', ListUser.as_view()),
    path('users/<int:pk>/', DetailUser.as_view()),
    path('login/', login_user, name='login'),
    path('pm/dashboard/', pm_dashboard_summary, name='pm_dashboard_summary'),
    path('debug/projects/', debug_projects, name='debug_projects'),
    path('debug/all/', debug_all_data, name='debug_all_data'),
]
