from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    health_check,
    verify_profile_photo,
    ListUser, 
    DetailUser, 
    login_user,
    change_password,
    check_subscription_status,
    activate_subscription,
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
    InventoryItemViewSet,
    InventoryUsageViewSet,
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
router.register(r'inventory-items', InventoryItemViewSet, basename='inventory-item')
router.register(r'inventory-usage', InventoryUsageViewSet, basename='inventory-usage')

urlpatterns = [
    path('', include(router.urls)),
    path('health/', health_check, name='health_check'),
    path('users/', ListUser.as_view()),
    path('users/<int:pk>/', DetailUser.as_view()),
    path('login/', login_user, name='login'),
    path('change-password/', change_password, name='change_password'),
    path('subscription/check/', check_subscription_status, name='check_subscription_status'),
    path('subscription/activate/', activate_subscription, name='activate_subscription'),
    path('pm/dashboard/', pm_dashboard_summary, name='pm_dashboard_summary'),
    path('image-verification/', verify_profile_photo, name='verify_profile_photo'),
    path('debug/projects/', debug_projects, name='debug_projects'),
    path('debug/all/', debug_all_data, name='debug_all_data'),
]
