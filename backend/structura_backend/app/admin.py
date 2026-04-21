from django import forms
from django.contrib import admin
from django.http import JsonResponse
from django.utils.html import format_html
from django.utils import timezone
from django.db.models import Q
from django.urls import path, reverse
from django.utils.http import urlencode
from datetime import datetime, time, timedelta
from .models import (
    User, SubscriptionWarning, PaymentHistory, 
    Project, Client, Supervisors, FieldWorker
)


# Custom filters (must be defined before UserAdmin)
class TrialExpiringFilter(admin.SimpleListFilter):
    title = 'Trial Expiring Soon'
    parameter_name = 'trial_expiring'

    def lookups(self, request, model_admin):
        return (
            ('7days', 'Expiring in 7 days'),
            ('3days', 'Expiring in 3 days'),
            ('1day', 'Expiring in 1 day'),
            ('expired', 'Expired'),
        )

    def queryset(self, request, queryset):
        now = timezone.now()
        if self.value() == '7days':
            end_date = now + timedelta(days=7)
            return queryset.filter(
                subscription_status='trial',
                trial_end_date__lte=end_date,
                trial_end_date__gt=now
            )
        elif self.value() == '3days':
            end_date = now + timedelta(days=3)
            return queryset.filter(
                subscription_status='trial',
                trial_end_date__lte=end_date,
                trial_end_date__gt=now
            )
        elif self.value() == '1day':
            end_date = now + timedelta(days=1)
            return queryset.filter(
                subscription_status='trial',
                trial_end_date__lte=end_date,
                trial_end_date__gt=now
            )
        elif self.value() == 'expired':
            return queryset.filter(
                subscription_status='trial',
                trial_end_date__lte=now
            )


class SubscriptionStatusFilter(admin.SimpleListFilter):
    title = 'Subscription Status'
    parameter_name = 'sub_status'

    def lookups(self, request, model_admin):
        return (
            ('active_trial', 'Active Trial'),
            ('active_paid', 'Active Paid'),
            ('expired', 'Expired'),
        )

    def queryset(self, request, queryset):
        now = timezone.now()
        if self.value() == 'active_trial':
            return queryset.filter(
                subscription_status='trial',
                trial_end_date__gt=now
            )
        elif self.value() == 'active_paid':
            return queryset.filter(
                subscription_status='active',
                subscription_end_date__gt=now
            )
        elif self.value() == 'expired':
            return queryset.filter(
                Q(subscription_status='expired') |
                Q(subscription_status='trial', trial_end_date__lte=now) |
                Q(subscription_status='active', subscription_end_date__lte=now)
            )


class SubscriptionWarningInline(admin.TabularInline):
    model = SubscriptionWarning
    extra = 0
    readonly_fields = ('warning_type', 'sent_at', 'email_sent_successfully', 'error_message')
    can_delete = False

    def has_add_permission(self, request, obj=None):
        return False


class PaymentHistoryInline(admin.TabularInline):
    model = PaymentHistory
    extra = 0
    readonly_fields = ('payment_date', 'amount', 'subscription_years', 'payment_status')
    fields = ('payment_date', 'amount', 'subscription_years', 'payment_status', 'notes')


class SubscriptionActivationForm(forms.Form):
    subscription_start_date = forms.DateField()
    subscription_years = forms.IntegerField(min_value=1)
    payment_date = forms.DateField()


def _add_years_to_date(start_date, years):
    try:
        return start_date.replace(year=start_date.year + years)
    except ValueError:
        # Handle leap day edge case by capping to Feb 28 on non-leap years.
        return start_date.replace(month=2, day=28, year=start_date.year + years)


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = (
        'email', 'full_name', 'role', 'subscription_status_badge',
        'trial_days_remaining', 'subscription_days_remaining',
        'status', 'created_at'
    )
    list_filter = (
        'role', 'subscription_status', 'status',
        'warning_7days_sent', 'warning_3days_sent', 'warning_1day_sent',
        TrialExpiringFilter, SubscriptionStatusFilter
    )
    search_fields = ('email', 'first_name', 'last_name', 'phone')
    readonly_fields = (
        'password_hash', 'created_at', 'trial_days_remaining_display',
        'subscription_days_remaining_display', 'subscription_status_indicator'
    )
    
    fieldsets = (
        ('Basic Information', {
            'fields': ('email', 'password_hash', 'role', 'status')
        }),
        ('Personal Details', {
            'fields': ('first_name', 'middle_name', 'last_name', 'birthdate', 'phone'),
            'classes': ('collapse',)
        }),
        ('Address', {
            'fields': ('region', 'province', 'city', 'barangay', 'street'),
            'classes': ('collapse',)
        }),
        ('Trial & Subscription', {
            'fields': (
                'subscription_status', 'subscription_status_indicator',
                'trial_start_date', 'trial_end_date', 'trial_days_remaining_display',
                'subscription_days_remaining_display',
            )
        }),
        ('Email Warnings', {
            'fields': ('warning_7days_sent', 'warning_3days_sent', 'warning_1day_sent'),
            'classes': ('collapse',)
        }),
        ('System Info', {
            'fields': ('created_at',),
            'classes': ('collapse',)
        }),
    )
    
    inlines = [PaymentHistoryInline, SubscriptionWarningInline]
    
    actions = [
        'send_trial_warning_bulk', 'extend_trial_7days', 'extend_trial_14days',
        'activate_subscription_1year', 'mark_subscription_expired'
    ]

    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path(
                '<path:object_id>/activate-subscription/',
                self.admin_site.admin_view(self.activate_subscription_view),
                name='app_user_activate_subscription',
            ),
        ]
        return custom_urls + urls

    def change_view(self, request, object_id, form_url='', extra_context=None):
        extra_context = extra_context or {}
        if request.user.is_superuser and object_id:
            extra_context['show_subscription_modal'] = True
            extra_context['subscription_activate_url'] = reverse(
                'admin:app_user_activate_subscription',
                args=[object_id],
            )
        return super().change_view(request, object_id, form_url, extra_context=extra_context)

    def activate_subscription_view(self, request, object_id):
        if not request.user.is_superuser:
            return JsonResponse({'ok': False, 'message': 'Forbidden'}, status=403)

        user_obj = self.get_object(request, object_id)
        if user_obj is None:
            return JsonResponse({'ok': False, 'message': 'User not found'}, status=404)

        if request.method != 'POST':
            return JsonResponse({'ok': False, 'message': 'Method not allowed'}, status=405)

        form = SubscriptionActivationForm(request.POST)
        if not form.is_valid():
            serialized_errors = {
                field: [str(error) for error in errors]
                for field, errors in form.errors.items()
            }
            return JsonResponse({'ok': False, 'errors': serialized_errors}, status=400)

        start_date = form.cleaned_data['subscription_start_date']
        years = form.cleaned_data['subscription_years']
        payment_date = form.cleaned_data['payment_date']
        end_date = _add_years_to_date(start_date, years)

        start_datetime = timezone.make_aware(datetime.combine(start_date, time.min))
        end_datetime = timezone.make_aware(datetime.combine(end_date, time.min))
        payment_datetime = timezone.make_aware(datetime.combine(payment_date, time.min))

        user_obj.subscription_status = 'active'
        user_obj.subscription_start_date = start_datetime
        user_obj.subscription_end_date = end_datetime
        user_obj.subscription_years = years
        user_obj.payment_date = payment_datetime
        user_obj.save(
            update_fields=[
                'subscription_status',
                'subscription_start_date',
                'subscription_end_date',
                'subscription_years',
                'payment_date',
            ]
        )

        return JsonResponse({'ok': True, 'message': 'Subscription activated successfully.'})

    def full_name(self, obj):
        """Display user's full name"""
        if obj.first_name and obj.last_name:
            return f"{obj.first_name} {obj.last_name}"
        return obj.email
    full_name.short_description = 'Name'

    def subscription_status_badge(self, obj):
        """Display subscription status with color badge"""
        color = obj.get_trial_status_color()
        status_colors = {
            'green': '#28a745',
            'yellow': '#ffc107',
            'red': '#dc3545',
            'gray': '#6c757d'
        }
        bg_color = status_colors.get(color, '#6c757d')
        
        if obj.subscription_status == 'trial':
            days = obj.get_trial_days_remaining()
            return format_html(
                '<span style="background-color: {}; color: white; padding: 3px 10px; '
                'border-radius: 3px; font-weight: bold;">{} ({} days)</span>',
                bg_color, obj.get_subscription_status_display(), days
            )
        elif obj.subscription_status == 'active':
            days = obj.get_subscription_days_remaining()
            return format_html(
                '<span style="background-color: #007bff; color: white; padding: 3px 10px; '
                'border-radius: 3px; font-weight: bold;">{} ({} days)</span>',
                obj.get_subscription_status_display(), days
            )
        else:
            return format_html(
                '<span style="background-color: {}; color: white; padding: 3px 10px; '
                'border-radius: 3px; font-weight: bold;">{}</span>',
                bg_color, obj.get_subscription_status_display()
            )
    subscription_status_badge.short_description = 'Subscription Status'

    def trial_days_remaining(self, obj):
        """Display trial days remaining"""
        if obj.subscription_status == 'trial':
            days = obj.get_trial_days_remaining()
            if days > 7:
                color = 'green'
            elif 3 <= days <= 7:
                color = 'orange'
            elif days > 0:
                color = 'red'
            else:
                return format_html('<span style="color: gray;">Expired</span>')
            return format_html('<span style="color: {}; font-weight: bold;">{} days</span>', color, days)
        return '-'
    trial_days_remaining.short_description = 'Trial Remaining'

    def subscription_days_remaining(self, obj):
        """Display subscription days remaining"""
        if obj.subscription_status == 'active':
            days = obj.get_subscription_days_remaining()
            return format_html('<span style="font-weight: bold;">{} days</span>', days)
        return '-'
    subscription_days_remaining.short_description = 'Subscription Remaining'

    def trial_days_remaining_display(self, obj):
        """Display trial days remaining in detail view"""
        if obj.subscription_status == 'trial' and obj.trial_end_date:
            days = obj.get_trial_days_remaining()
            color = obj.get_trial_status_color()
            return format_html(
                '<span style="color: {}; font-size: 14px; font-weight: bold;">{} days remaining</span>',
                color, days
            )
        return 'N/A'
    trial_days_remaining_display.short_description = 'Trial Days Remaining'

    def subscription_days_remaining_display(self, obj):
        """Display subscription days remaining in detail view"""
        if obj.subscription_status == 'active' and obj.subscription_end_date:
            days = obj.get_subscription_days_remaining()
            return format_html(
                '<span style="font-size: 14px; font-weight: bold;">{} days remaining</span>',
                days
            )
        return 'N/A'
    subscription_days_remaining_display.short_description = 'Subscription Days Remaining'

    def subscription_status_indicator(self, obj):
        """Visual indicator for subscription status"""
        color = obj.get_trial_status_color()
        status_colors = {
            'green': '#28a745',
            'yellow': '#ffc107',
            'red': '#dc3545',
            'gray': '#6c757d'
        }
        bg_color = status_colors.get(color, '#6c757d')
        
        if obj.subscription_status == 'trial':
            days = obj.get_trial_days_remaining()
            message = f"Trial: {days} days remaining"
        elif obj.subscription_status == 'active':
            days = obj.get_subscription_days_remaining()
            message = f"Active: {days} days remaining"
        else:
            message = "Expired"
            
        return format_html(
            '<div style="background-color: {}; color: white; padding: 10px; '
            'border-radius: 5px; text-align: center; font-weight: bold; font-size: 16px;">'
            '{}</div>',
            bg_color, message
        )
    subscription_status_indicator.short_description = 'Status Indicator'

    # Bulk Actions
    def send_trial_warning_bulk(self, request, queryset):
        """Send trial warning emails to selected users (manual send - bypasses duplicate checks)"""
        from .utils import send_trial_warning_email
        
        success_count = 0
        failed_count = 0
        skipped_count = 0
        error_messages = []
        
        for user in queryset:
            # Only send to ProjectManagers with trial status
            if user.role != 'ProjectManager':
                skipped_count += 1
                continue
            
            if user.subscription_status != 'trial':
                skipped_count += 1
                continue
            
            # Check if trial is still active or recently expired
            days_remaining = user.get_trial_days_remaining()
            if days_remaining < -7:  # Don't send for trials expired more than 7 days ago
                skipped_count += 1
                continue
            
            # Force send (bypasses "already sent" checks)
            try:
                result = send_trial_warning_email(user, force_send=True)
                if result:
                    success_count += 1
                else:
                    failed_count += 1
                    error_messages.append(f"{user.email} - Email send returned False")
            except Exception as e:
                failed_count += 1
                error_messages.append(f"{user.email} - {str(e)}")
        
        # Build result message
        messages = []
        if success_count:
            messages.append(f"✓ Successfully sent to {success_count} user(s)")
        if failed_count:
            messages.append(f"✗ Failed to send to {failed_count} user(s)")
        if skipped_count:
            messages.append(f"⊘ Skipped {skipped_count} user(s) (not ProjectManager/trial or expired >7 days)")
        
        if error_messages:
            messages.append("Errors: " + "; ".join(error_messages[:3]))  # Show first 3 errors
            if len(error_messages) > 3:
                messages.append(f"... and {len(error_messages) - 3} more errors")
        
        self.message_user(request, " | ".join(messages))
    send_trial_warning_bulk.short_description = "📧 Send trial warning emails (manual send)"

    def extend_trial_7days(self, request, queryset):
        """Extend trial by 7 days for selected users"""
        count = 0
        for user in queryset.filter(role='ProjectManager', subscription_status='trial'):
            user.trial_end_date = user.trial_end_date + timedelta(days=7)
            user.save()
            count += 1
        self.message_user(request, f"Extended trial by 7 days for {count} users.")
    extend_trial_7days.short_description = "Extend trial by 7 days"

    def extend_trial_14days(self, request, queryset):
        """Extend trial by 14 days for selected users"""
        count = 0
        for user in queryset.filter(role='ProjectManager', subscription_status='trial'):
            user.trial_end_date = user.trial_end_date + timedelta(days=14)
            user.save()
            count += 1
        self.message_user(request, f"Extended trial by 14 days for {count} users.")
    extend_trial_14days.short_description = "Extend trial by 14 days"

    def activate_subscription_1year(self, request, queryset):
        """Activate 1-year subscription for selected users"""
        count = 0
        for user in queryset.filter(role='ProjectManager'):
            user.subscription_status = 'active'
            user.subscription_start_date = timezone.now()
            user.subscription_end_date = timezone.now() + timedelta(days=365)
            user.subscription_years = 1
            user.payment_date = timezone.now()
            user.save()
            count += 1
        self.message_user(request, f"Activated 1-year subscription for {count} users.")
    activate_subscription_1year.short_description = "Activate 1-year subscription"

    def mark_subscription_expired(self, request, queryset):
        """Mark subscription as expired for selected users"""
        count = queryset.filter(role='ProjectManager').update(subscription_status='expired')
        self.message_user(request, f"Marked {count} users as expired.")
    mark_subscription_expired.short_description = "Mark as expired"


@admin.register(SubscriptionWarning)
class SubscriptionWarningAdmin(admin.ModelAdmin):
    list_display = ('user', 'warning_type', 'sent_at', 'email_sent_successfully')
    list_filter = ('warning_type', 'email_sent_successfully', 'sent_at')
    search_fields = ('user__email', 'user__first_name', 'user__last_name')
    readonly_fields = ('user', 'warning_type', 'sent_at', 'email_sent_successfully', 'error_message')
    
    def has_add_permission(self, request):
        return False


@admin.register(PaymentHistory)
class PaymentHistoryAdmin(admin.ModelAdmin):
    list_display = ('user', 'amount', 'subscription_years', 'payment_date', 'payment_status')
    list_filter = ('payment_status', 'payment_date', 'subscription_years')
    search_fields = ('user__email', 'user__first_name', 'user__last_name')
    readonly_fields = ('payment_date',)
    
    fieldsets = (
        ('Payment Information', {
            'fields': ('user', 'amount', 'subscription_years', 'payment_status')
        }),
        ('Details', {
            'fields': ('payment_date', 'notes')
        }),
    )


@admin.register(Supervisors)
class SupervisorsAdmin(admin.ModelAdmin):
    list_display = (
        'supervisor_id',
        'email',
        'first_name',
        'last_name',
        'role',
        'project_id',
        'created_by',
    )
    list_filter = ('role', 'project_id')
    search_fields = ('email', 'first_name', 'last_name', 'phone_number')
    readonly_fields = ('supervisor_id',)


@admin.register(Client)
class ClientAdmin(admin.ModelAdmin):
    list_display = (
        'client_id',
        'email',
        'first_name',
        'last_name',
        'project_id',
        'status',
        'created_by',
    )
    list_filter = ('status', 'project_id')
    search_fields = ('email', 'first_name', 'last_name', 'phone_number')
    readonly_fields = ('client_id', 'created_at')


def _build_admin_link(base_url, params=None):
    if not params:
        return base_url
    return f"{base_url}?{urlencode(params)}"


def _superadmin_dashboard_context(request):
    if not request.user.is_superuser:
        return {}

    user_changelist_url = reverse('admin:app_user_changelist')
    supervisors_changelist_url = reverse('admin:app_supervisors_changelist')
    clients_changelist_url = reverse('admin:app_client_changelist')
    payment_changelist_url = reverse('admin:app_paymenthistory_changelist')

    sidebar_sections = [
        {
            'title': 'Project Manager',
            'description': 'Manage all project manager accounts.',
            'url': _build_admin_link(user_changelist_url, {'role': 'ProjectManager'}),
            'count': User.objects.filter(role='ProjectManager').count(),
        },
        {
            'title': 'Supervisor',
            'description': 'Review and update supervisor records.',
            'url': supervisors_changelist_url,
            'count': Supervisors.objects.count(),
        },
        {
            'title': 'Client',
            'description': 'View all client user accounts.',
            'url': clients_changelist_url,
            'count': Client.objects.count(),
        },
        {
            'title': 'Payments',
            'description': 'Monitor payment records and status.',
            'url': payment_changelist_url,
            'count': PaymentHistory.objects.count(),
        },
    ]

    return {
        'superadmin_sidebar_sections': sidebar_sections,
    }


_original_each_context = admin.site.each_context


def _structura_each_context(request):
    context = _original_each_context(request)
    context.update(_superadmin_dashboard_context(request))
    return context


admin.site.each_context = _structura_each_context
admin.site.index_template = 'admin/superadmin_index.html'


# Customize admin site
admin.site.site_header = "Structura SuperAdmin Dashboard"
admin.site.site_title = "Structura Admin"
admin.site.index_title = "Trial & Subscription Management"
admin.site.enable_nav_sidebar = False
