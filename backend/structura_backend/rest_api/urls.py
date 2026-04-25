from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    health_check,
    verify_profile_photo,
    ListUser, 
    DetailUser, 
    login_user,
    send_signup_otp,
    verify_signup_otp,
    mark_quick_tour_completed,
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
    SubtaskCompletionRevertRequestViewSet,
    ClientViewSet,
    BackJobReviewViewSet,
    PhaseViewSet,
    SubtaskViewSet,
    SubtaskFieldWorkerViewSet,
    AttendanceViewSet,
    InventoryItemViewSet,
    InventoryUsageViewSet,
    PhaseMaterialPlanViewSet,
    pm_dashboard_summary,
    pm_inbox_mark_read,
    supervisor_inbox,
    supervisor_inbox_mark_read,
    pm_audit_trail,
    debug_projects,
    debug_all_data,
    SupervisorReportSubmissionViewSet,
    create_paymongo_checkout,
    paymongo_webhook,
)

router = DefaultRouter()
router.register(r'regions', RegionViewSet, basename='region')
router.register(r'provinces', ProvinceViewSet, basename='province')
router.register(r'cities', CityViewSet, basename='city')
router.register(r'barangays', BarangayViewSet, basename='barangay')
router.register(r'projects', ProjectViewSet, basename='project')
router.register(r'supervisors', SupervisorsViewSet, basename='supervisors')
router.register(r'field-workers', FieldWorkerViewSet, basename='fieldworker')
router.register(
    r'subtask-completion-revert-requests',
    SubtaskCompletionRevertRequestViewSet,
    basename='subtask-completion-revert',
)
router.register(r'clients', ClientViewSet, basename='client')
router.register(r'back-job-reviews', BackJobReviewViewSet, basename='back-job-review')
router.register(r'phases', PhaseViewSet, basename='phase')
router.register(r'subtasks', SubtaskViewSet, basename='subtask')
router.register(r'subtask-assignments', SubtaskFieldWorkerViewSet, basename='subtask-assignment')
router.register(r'attendance', AttendanceViewSet, basename='attendance')
router.register(r'inventory-items', InventoryItemViewSet, basename='inventory-item')
router.register(r'inventory-usage', InventoryUsageViewSet, basename='inventory-usage')
router.register(r'phase-material-plans', PhaseMaterialPlanViewSet, basename='phase-material-plan')
router.register(
    r'supervisor-reports',
    SupervisorReportSubmissionViewSet,
    basename='supervisor-report',
)

urlpatterns = [
    path('', include(router.urls)),
    path('health/', health_check, name='health_check'),
    path('users/', ListUser.as_view()),
    path('users/<int:pk>/', DetailUser.as_view()),
    path('login/', login_user, name='login'),
    path('signup/send-otp/', send_signup_otp, name='send_signup_otp'),
    path('signup/verify-otp/', verify_signup_otp, name='verify_signup_otp'),
    path('tutorial/complete/', mark_quick_tour_completed, name='mark_quick_tour_completed'),
    path('change-password/', change_password, name='change_password'),
    path('subscription/check/', check_subscription_status, name='check_subscription_status'),
    path('subscription/activate/', activate_subscription, name='activate_subscription'),
    path('subscription/paymongo-checkout/', create_paymongo_checkout, name='create_paymongo_checkout'),
    path('webhooks/paymongo/', paymongo_webhook, name='paymongo_webhook'),
    path('pm/dashboard/', pm_dashboard_summary, name='pm_dashboard_summary'),
    path(
        'pm/inbox/<int:notification_id>/read/',
        pm_inbox_mark_read,
        name='pm_inbox_mark_read',
    ),
    path('supervisor/inbox/', supervisor_inbox, name='supervisor_inbox'),
    path(
        'supervisor/inbox/<int:notification_id>/read/',
        supervisor_inbox_mark_read,
        name='supervisor_inbox_mark_read',
    ),
    path('pm/audit-trail/', pm_audit_trail, name='pm_audit_trail'),
    path('image-verification/', verify_profile_photo, name='verify_profile_photo'),
    path('debug/projects/', debug_projects, name='debug_projects'),
    path('debug/all/', debug_all_data, name='debug_all_data'),
]
