from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    ListUser, 
    DetailUser, 
    login_user,
    RegionViewSet,
    ProvinceViewSet,
    CityViewSet,
    BarangayViewSet,
    ProjectViewSet,
    SupervisorViewSet,
    ClientViewSet,
    debug_projects,
    debug_all_data
)

router = DefaultRouter()
router.register(r'regions', RegionViewSet, basename='region')
router.register(r'provinces', ProvinceViewSet, basename='province')
router.register(r'cities', CityViewSet, basename='city')
router.register(r'barangays', BarangayViewSet, basename='barangay')
router.register(r'projects', ProjectViewSet, basename='project')
router.register(r'supervisors', SupervisorViewSet, basename='supervisor')
router.register(r'clients', ClientViewSet, basename='client')

urlpatterns = [
    path('', include(router.urls)),
    path('users/', ListUser.as_view()),
    path('users/<int:pk>/', DetailUser.as_view()),
    path('login/', login_user, name='login'),
    path('debug/projects/', debug_projects, name='debug_projects'),
    path('debug/all/', debug_all_data, name='debug_all_data'),
]
