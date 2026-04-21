from django.db import models
from django.contrib.auth.hashers import make_password
from django.utils import timezone
from datetime import timedelta


# Address Models (defined first so User can reference them)
class Region(models.Model):
    code = models.CharField(max_length=20, unique=True)
    name = models.CharField(max_length=255)

    def __str__(self):
        return self.name


class Province(models.Model):
    code = models.CharField(max_length=20, unique=True)
    name = models.CharField(max_length=255)
    region = models.ForeignKey(Region, on_delete=models.CASCADE)

    def __str__(self):
        return self.name


class City(models.Model):
    code = models.CharField(max_length=20, unique=True)
    name = models.CharField(max_length=255)
    province = models.ForeignKey(Province, on_delete=models.CASCADE)

    def __str__(self):
        return self.name


class Barangay(models.Model):
    code = models.CharField(max_length=20, unique=True)
    name = models.CharField(max_length=255)
    city = models.ForeignKey(City, on_delete=models.CASCADE)

    def __str__(self):
        return self.name


# User Model
class User(models.Model):
    ROLE_CHOICES = [
        ('SuperAdmin', 'SuperAdmin'),
        ('ProjectManager', 'ProjectManager'),
        ('Supervisor', 'Supervisor'),
        ('Client', 'Client'),
    ]

    STATUS_CHOICES = [
        ('Active', 'Active'),
        ('Inactive', 'Inactive'),
        ('Suspended', 'Suspended'),
    ]

    SUBSCRIPTION_STATUS_CHOICES = [
        ('trial', 'Trial Period'),
        ('active', 'Active Subscription'),
        ('expired', 'Expired'),
    ]

    user_id = models.AutoField(primary_key=True)
    email = models.EmailField(max_length=100, unique=True)
    password_hash = models.CharField(max_length=255)

    first_name = models.CharField(max_length=100, null=True, blank=True)
    middle_name = models.CharField(max_length=100, null=True, blank=True)
    last_name = models.CharField(max_length=100, null=True, blank=True)

    birthdate = models.DateField(null=True, blank=True)
    phone = models.CharField(max_length=20, null=True, blank=True)

    # Address Information
    region = models.ForeignKey(Region, on_delete=models.SET_NULL, null=True, blank=True)
    province = models.ForeignKey(Province, on_delete=models.SET_NULL, null=True, blank=True)
    city = models.ForeignKey(City, on_delete=models.SET_NULL, null=True, blank=True)
    barangay = models.ForeignKey(Barangay, on_delete=models.SET_NULL, null=True, blank=True)
    street = models.CharField(max_length=200, null=True, blank=True)

    role = models.CharField(
        max_length=20,
        choices=ROLE_CHOICES,
        default='ProjectManager'
    )

    # Subscription fields (present in the production DB schema)
    payment_date = models.DateTimeField(null=True, blank=True)
    subscription_start_date = models.DateTimeField(null=True, blank=True)
    subscription_end_date = models.DateTimeField(null=True, blank=True)
    subscription_status = models.CharField(max_length=50, default='trial')
    subscription_years = models.IntegerField(default=0)
    trial_start_date = models.DateTimeField(null=True, blank=True)
    trial_end_date = models.DateTimeField(null=True, blank=True)
    warning_1day_sent = models.BooleanField(default=False)
    warning_3days_sent = models.BooleanField(default=False)
    warning_7days_sent = models.BooleanField(default=False)

    created_at = models.DateTimeField(auto_now_add=True)

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='Active'
    )

    # Trial and Subscription Management
    trial_start_date = models.DateTimeField(null=True, blank=True)
    trial_end_date = models.DateTimeField(null=True, blank=True)
    subscription_status = models.CharField(
        max_length=20,
        choices=SUBSCRIPTION_STATUS_CHOICES,
        default='trial'
    )
    subscription_start_date = models.DateTimeField(null=True, blank=True)
    subscription_end_date = models.DateTimeField(null=True, blank=True)
    subscription_years = models.IntegerField(default=0, help_text="Number of years paid for")
    payment_date = models.DateTimeField(null=True, blank=True)
    
    # Email warning tracking
    warning_7days_sent = models.BooleanField(default=False)
    warning_3days_sent = models.BooleanField(default=False)
    warning_1day_sent = models.BooleanField(default=False)

    def save(self, *args, **kwargs):
        # Initialize trial for new ProjectManager users
        if not self.pk and self.role == 'ProjectManager':
            if not self.trial_start_date:
                self.trial_start_date = timezone.now()
                self.trial_end_date = timezone.now() + timedelta(days=14)
                self.subscription_status = 'trial'
        
        if self.password_hash and not self.password_hash.startswith('pbkdf2_'):
            self.password_hash = make_password(self.password_hash)
        super().save(*args, **kwargs)

    def get_trial_days_remaining(self):
        """Calculate days remaining in trial period"""
        if self.trial_end_date and self.subscription_status == 'trial':
            remaining = (self.trial_end_date - timezone.now()).days
            return max(0, remaining)
        return 0

    def get_subscription_days_remaining(self):
        """Calculate days remaining in subscription"""
        if self.subscription_end_date and self.subscription_status == 'active':
            remaining = (self.subscription_end_date - timezone.now()).days
            return max(0, remaining)
        return 0

    def is_subscription_valid(self):
        """Check if user has valid subscription or trial"""
        if self.role == 'SuperAdmin':
            return True
        
        if self.subscription_status == 'trial':
            return self.trial_end_date and timezone.now() <= self.trial_end_date
        elif self.subscription_status == 'active':
            return self.subscription_end_date and timezone.now() <= self.subscription_end_date
        return False

    def can_edit(self):
        """Check if user can create/edit content"""
        return self.is_subscription_valid()

    def get_trial_status_color(self):
        """Get color indicator for trial status"""
        days_remaining = self.get_trial_days_remaining()
        if self.subscription_status != 'trial':
            return 'gray'
        if days_remaining > 7:
            return 'green'
        elif 3 <= days_remaining <= 7:
            return 'yellow'
        elif 0 < days_remaining < 3:
            return 'red'
        return 'gray'

    def __str__(self):
        return self.email


# Subscription Warning Log Model
class SubscriptionWarning(models.Model):
    WARNING_TYPE_CHOICES = [
        ('7_days', '7 Days Warning'),
        ('3_days', '3 Days Warning'),
        ('1_day', '1 Day Warning'),
        ('expired', 'Expired Notification'),
    ]

    log_id = models.AutoField(primary_key=True)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='warning_logs')
    warning_type = models.CharField(max_length=20, choices=WARNING_TYPE_CHOICES)
    sent_at = models.DateTimeField(auto_now_add=True)
    email_sent_successfully = models.BooleanField(default=False)
    error_message = models.TextField(null=True, blank=True)

    class Meta:
        ordering = ['-sent_at']

    def __str__(self):
        return f"{self.user.email} - {self.warning_type} - {self.sent_at.strftime('%Y-%m-%d %H:%M')}"


# Subscription Payment History Model
class PaymentHistory(models.Model):
    PAYMENT_STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
    ]

    payment_id = models.AutoField(primary_key=True)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='payment_history')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    subscription_years = models.IntegerField(default=1)
    payment_date = models.DateTimeField(auto_now_add=True)
    payment_status = models.CharField(max_length=20, choices=PAYMENT_STATUS_CHOICES, default='pending')
    notes = models.TextField(null=True, blank=True)
    
    class Meta:
        ordering = ['-payment_date']

    def __str__(self):
        return f"{self.user.email} - {self.amount} - {self.payment_date.strftime('%Y-%m-%d')}"


# Project Model
class Project(models.Model):
    STATUS_CHOICES = [
        ('Active', 'Active'),
        ('On Hold', 'On Hold'),
        ('Completed', 'Completed'),
        ('Deactivated', 'Deactivated'),
    ]

    project_id = models.AutoField(primary_key=True)
    project_image = models.CharField(max_length=500, null=True, blank=True)
    project_name = models.CharField(max_length=200)
    description = models.TextField(null=True, blank=True)

    # User relationship
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='projects', null=True, blank=True)

    region = models.ForeignKey(Region, on_delete=models.SET_NULL, null=True, blank=True)
    province = models.ForeignKey(Province, on_delete=models.SET_NULL, null=True, blank=True)
    city = models.ForeignKey(City, on_delete=models.SET_NULL, null=True, blank=True)
    barangay = models.ForeignKey(Barangay, on_delete=models.SET_NULL, null=True, blank=True)
    street = models.CharField(max_length=200, null=True, blank=True)

    project_type = models.CharField(max_length=100)
    start_date = models.DateField()
    end_date = models.DateField(null=True, blank=True)
    duration_days = models.PositiveIntegerField(null=True, blank=True)
    client = models.ForeignKey('Client', on_delete=models.SET_NULL, null=True, blank=True, related_name='assigned_projects')
    supervisor = models.ForeignKey('Supervisors', on_delete=models.SET_NULL, null=True, blank=True, related_name='assigned_projects')
    budget = models.DecimalField(max_digits=12, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Active')
    created_at = models.DateTimeField(auto_now_add=True)

    def get_progress(self):
        """Calculate project progress based on subtask completion"""
        total_subtasks = 0
        completed_subtasks = 0
        
        for phase in self.phases.all():
            subtasks = phase.subtasks.all()
            total_subtasks += subtasks.count()
            completed_subtasks += subtasks.filter(status='completed').count()
        
        if total_subtasks == 0:
            return 0.0
        
        return completed_subtasks / total_subtasks

    def update_status_based_on_progress(self):
        """Automatically update status to Completed if progress reaches 100%"""
        progress = self.get_progress()
        if progress >= 1.0 and self.status != 'Completed':
            self.status = 'Completed'
            self.save(update_fields=['status'])
            return True
        return False

    def __str__(self):
        return self.project_name


# Supervisors Model
class Supervisors(models.Model):
    ROLE_CHOICES = [
        ('Supervisor', 'Supervisor'),
    ]
    
    supervisor_id = models.AutoField(primary_key=True)
    # Project Manager (User) that created/invited this supervisor.
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='created_supervisors',
    )
    project_id = models.ForeignKey(Project, on_delete=models.SET_NULL, null=True, blank=True, related_name='supervisors')

    first_name = models.CharField(max_length=100, null=True, blank=True)
    middle_name = models.CharField(max_length=100, null=True, blank=True)
    last_name = models.CharField(max_length=100, null=True, blank=True)
    email = models.EmailField(max_length=100, unique=True)
    password_hash = models.CharField(max_length=255, default='PASSWORD')
    phone_number = models.CharField(max_length=20)
    birthdate = models.DateField(null=True, blank=True)

    # Address Information
    region = models.ForeignKey(Region, on_delete=models.SET_NULL, null=True, blank=True)
    province = models.ForeignKey(Province, on_delete=models.SET_NULL, null=True, blank=True)
    city = models.ForeignKey(City, on_delete=models.SET_NULL, null=True, blank=True)
    barangay = models.ForeignKey(Barangay, on_delete=models.SET_NULL, null=True, blank=True)
    
    # Supervisor-specific fields
    role = models.CharField(max_length=50, choices=ROLE_CHOICES, default='Supervisor')
    sss_id = models.CharField(max_length=20, null=True, blank=True)
    philhealth_id = models.CharField(max_length=20, null=True, blank=True)
    pagibig_id = models.CharField(max_length=20, null=True, blank=True)
    payrate = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)

    photo = models.FileField(upload_to='supervisor_images/', null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        # Ensure role is always Supervisor
        self.role = 'Supervisor'
        if self.password_hash and not self.password_hash.startswith('pbkdf2_'):
            self.password_hash = make_password(self.password_hash)
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.first_name} {self.last_name} (Supervisor)"

 
class FieldWorker(models.Model):
    """Field workers on construction sites assigned to a user/supervisor"""
    ROLE_CHOICES = [
        ('Mason', 'Mason'),
        ('Painter', 'Painter'),
        ('Electrician', 'Electrician'),
        ('Carpenter', 'Carpenter'),
    ]
    
    fieldworker_id = models.AutoField(primary_key=True)
    user_id = models.ForeignKey(User, on_delete=models.CASCADE, related_name='field_workers', null=True, blank=True)
    project_id = models.ForeignKey(
        Project,
        on_delete=models.SET_NULL,
        related_name='field_workers',
        null=True,
        blank=True,
    )
    
    first_name = models.CharField(max_length=100, null=True, blank=True)
    middle_name = models.CharField(max_length=100, null=True, blank=True)
    last_name = models.CharField(max_length=100, null=True, blank=True)
    phone_number = models.CharField(max_length=20)
    birthdate = models.DateField(null=True, blank=True)

    # Address Information
    region = models.ForeignKey(Region, on_delete=models.SET_NULL, null=True, blank=True)
    province = models.ForeignKey(Province, on_delete=models.SET_NULL, null=True, blank=True)
    city = models.ForeignKey(City, on_delete=models.SET_NULL, null=True, blank=True)
    barangay = models.ForeignKey(Barangay, on_delete=models.SET_NULL, null=True, blank=True)
    
    role = models.CharField(max_length=50, default='Mason')
    sss_id = models.CharField(max_length=20, null=True, blank=True)
    philhealth_id = models.CharField(max_length=20, null=True, blank=True)
    pagibig_id = models.CharField(max_length=20, null=True, blank=True)
    payrate = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)

    # Cash advance controls used by payroll summary/reporting.
    cash_advance_balance = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    deduction_per_salary = models.DecimalField(max_digits=10, decimal_places=2, default=0)

    # Weekly salary and deduction snapshot values.
    weekly_salary = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)

    sss_weekly_min = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    philhealth_weekly_min = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    pagibig_weekly_min = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)

    sss_weekly_topup = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    philhealth_weekly_topup = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    pagibig_weekly_topup = models.DecimalField(max_digits=10, decimal_places=2, default=0)

    sss_weekly_total = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    philhealth_weekly_total = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    pagibig_weekly_total = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)

    total_weekly_deduction = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    net_weekly_pay = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)

    photo = models.FileField(upload_to='fieldworker_images/', null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        project_name = self.project_id.project_name if self.project_id else "Unassigned"
        return f"{self.first_name} {self.last_name} - {project_name}"


# Client Model
class Client(models.Model):
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('deactivated', 'Deactivated'),
    ]
    client_id = models.AutoField(primary_key=True)
    # Project Manager (User) that created/invited this client.
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='created_clients',
    )
    user_id = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='client_profile')
    project_id = models.ForeignKey(Project, on_delete=models.SET_NULL, null=True, blank=True, related_name='clients')

    first_name = models.CharField(max_length=100, null=True, blank=True)
    middle_name = models.CharField(max_length=100, null=True, blank=True)
    last_name = models.CharField(max_length=100, null=True, blank=True)
    email = models.EmailField(max_length=100, unique=True)
    password_hash = models.CharField(max_length=255, default='PASSWORD')
    phone_number = models.CharField(max_length=20)
    birthdate = models.DateField(null=True, blank=True)
    region = models.ForeignKey(Region, on_delete=models.SET_NULL, null=True, blank=True)
    province = models.ForeignKey(Province, on_delete=models.SET_NULL, null=True, blank=True)
    city = models.ForeignKey(City, on_delete=models.SET_NULL, null=True, blank=True)
    barangay = models.ForeignKey(Barangay, on_delete=models.SET_NULL, null=True, blank=True)

    photo = models.FileField(upload_to='client_images/', null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='active'
    )

    def save(self, *args, **kwargs):
        if self.password_hash and not self.password_hash.startswith('pbkdf2_'):
            self.password_hash = make_password(self.password_hash)
        super().save(*args, **kwargs)

    def __str__(self):
        project_name = self.project_id.project_name if self.project_id else "Unassigned"
        return f"{self.first_name} {self.last_name} - {project_name}"


class BackJobReview(models.Model):
    review_id = models.AutoField(primary_key=True)
    project = models.ForeignKey(
        Project,
        on_delete=models.CASCADE,
        related_name='back_job_reviews',
    )
    client = models.ForeignKey(
        Client,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='back_job_reviews',
    )
    review_text = models.TextField(max_length=2000)
    is_resolved = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        project_name = self.project.project_name if self.project else 'Unknown Project'
        return f"BackJobReview #{self.review_id} - {project_name}"


# Phase Model
class Phase(models.Model):
    PHASE_CHOICES = [
        ('PHASE 1 - Pre-Construction Phase', 'PHASE 1 - Pre-Construction Phase'),
        ('PHASE 2 - Design Phase', 'PHASE 2 - Design Phase'),
        ('PHASE 3 - Procurement Phase', 'PHASE 3 - Procurement Phase'),
        ('PHASE 4 - Construction Phase', 'PHASE 4 - Construction Phase'),
        ('PHASE 5 - Testing & Commissioning Phase', 'PHASE 5 - Testing & Commissioning Phase'),
        ('PHASE 6 - Turnover / Close-Out Phase', 'PHASE 6 - Turnover / Close-Out Phase'),
        ('PHASE 7 - Post-Construction / Operation Phase', 'PHASE 7 - Post-Construction / Operation Phase'),
    ]

    STATUS_CHOICES = [
        ('not_started', 'Not Started'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
    ]

    phase_id = models.AutoField(primary_key=True)
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name='phases')
    phase_name = models.CharField(max_length=100)
    description = models.TextField(null=True, blank=True)
    days_duration = models.IntegerField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='not_started')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f"{self.phase_name} - {self.project.project_name}"


# Subtask Model
class Subtask(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
    ]

    subtask_id = models.AutoField(primary_key=True)
    phase = models.ForeignKey(Phase, on_delete=models.CASCADE, related_name='subtasks')
    title = models.CharField(max_length=255)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    progress_notes = models.TextField(max_length=1000, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f"{self.title} - {self.phase.phase_name}"


# SubtaskFieldWorker Assignment Model
class SubtaskFieldWorker(models.Model):
    """Tracks which field workers are assigned to which subtasks"""
    assignment_id = models.AutoField(primary_key=True)
    subtask = models.ForeignKey(Subtask, on_delete=models.CASCADE, related_name='assigned_workers')
    field_worker = models.ForeignKey(FieldWorker, on_delete=models.CASCADE, related_name='subtask_assignments')
    assigned_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('subtask', 'field_worker')
        ordering = ['assigned_at']

    def __str__(self):
        return f"{self.field_worker.first_name} {self.field_worker.last_name} → {self.subtask.title}"


# Attendance Model
class Attendance(models.Model):
    STATUS_CHOICES = [
        ('on_site', 'On Site'),
        ('on_break', 'On Break'),
        ('absent', 'Absent'),
    ]

    attendance_id = models.AutoField(primary_key=True)
    field_worker = models.ForeignKey(FieldWorker, on_delete=models.CASCADE, related_name='attendance_records')
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name='attendance_records')
    
    attendance_date = models.DateField()
    check_in_time = models.TimeField(null=True, blank=True)
    check_out_time = models.TimeField(null=True, blank=True)
    break_in_time = models.TimeField(null=True, blank=True)
    break_out_time = models.TimeField(null=True, blank=True)
    
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='absent')
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('field_worker', 'project', 'attendance_date')
        ordering = ['-attendance_date']

    def __str__(self):
        return f"{self.field_worker.first_name} {self.field_worker.last_name} - {self.attendance_date}"


# Inventory Item Model
class InventoryItem(models.Model):
    STATUS_CHOICES = [
        ('Available', 'Available'),
        ('Checked Out', 'Checked Out'),
        ('Returned', 'Returned'),
        ('Maintenance', 'Maintenance'),
        ('Unavailable', 'Unavailable'),
    ]

    item_id = models.AutoField(primary_key=True)
    name = models.CharField(max_length=200)
    category = models.CharField(max_length=100)
    serial_number = models.CharField(max_length=100, null=True, blank=True)
    quantity = models.PositiveIntegerField(default=1)
    location = models.CharField(max_length=200, null=True, blank=True)
    notes = models.TextField(null=True, blank=True)
    photo = models.FileField(upload_to='inventory_images/', null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Available')
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='inventory_items')
    project = models.ForeignKey('Project', on_delete=models.SET_NULL, null=True, blank=True, related_name='inventory_items', db_column='project_id')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def sync_quantity_from_units(self):
        """Keep profile quantity aligned with the number of unit records."""
        units_count = self.units.count()
        if self.quantity != units_count:
            self.quantity = units_count
            self.save(update_fields=['quantity', 'updated_at'])

    def __str__(self):
        return f"{self.name} ({self.status})"


class InventoryUnit(models.Model):
    STATUS_CHOICES = [
        ('Available', 'Available'),
        ('Checked Out', 'Checked Out'),
        ('Returned', 'Returned'),
        ('Maintenance', 'Maintenance'),
        ('Unavailable', 'Unavailable'),
    ]

    unit_id = models.AutoField(primary_key=True)
    inventory_item = models.ForeignKey(
        InventoryItem,
        on_delete=models.CASCADE,
        related_name='units',
        db_column='item_id',
    )
    unit_code = models.CharField(max_length=120, unique=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Available')
    current_project = models.ForeignKey(
        'Project',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='inventory_units',
        db_column='project_id',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['unit_code']

    def save(self, *args, **kwargs):
        is_new = self._state.adding
        super().save(*args, **kwargs)
        if is_new:
            self.inventory_item.sync_quantity_from_units()

    def delete(self, *args, **kwargs):
        parent = self.inventory_item
        super().delete(*args, **kwargs)
        parent.sync_quantity_from_units()

    def __str__(self):
        return f"{self.unit_code} ({self.status})"


class InventoryUnitMovement(models.Model):
    ACTION_CHOICES = [
        ('Assigned', 'Assigned'),
        ('Transferred', 'Transferred'),
        ('Checked Out', 'Checked Out'),
        ('Returned', 'Returned'),
        ('Status Updated', 'Status Updated'),
    ]

    movement_id = models.AutoField(primary_key=True)
    unit = models.ForeignKey(
        InventoryUnit,
        on_delete=models.CASCADE,
        related_name='movements',
        db_column='unit_id',
    )
    from_project = models.ForeignKey(
        'Project',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='unit_movements_from',
    )
    to_project = models.ForeignKey(
        'Project',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='unit_movements_to',
    )
    action = models.CharField(max_length=30, choices=ACTION_CHOICES)
    moved_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='inventory_unit_movements',
    )
    notes = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.unit.unit_code} - {self.action}"


# Inventory Usage Model (tracks checkout/return by supervisors)
class InventoryUsage(models.Model):
    USAGE_STATUS_CHOICES = [
        ('Checked Out', 'Checked Out'),
        ('Returned', 'Returned'),
    ]

    usage_id = models.AutoField(primary_key=True)
    inventory_item = models.ForeignKey(InventoryItem, on_delete=models.CASCADE, related_name='usages', db_column='item_id')
    inventory_unit = models.ForeignKey(
        InventoryUnit,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='usages',
        db_column='unit_id',
    )
    checked_out_by = models.ForeignKey(Supervisors, on_delete=models.CASCADE, related_name='inventory_usages', db_column='supervisor_id')
    field_worker = models.ForeignKey(FieldWorker, on_delete=models.SET_NULL, null=True, blank=True, related_name='inventory_usages')
    checkout_date = models.DateTimeField(auto_now_add=True)
    expected_return_date = models.DateField(null=True, blank=True)
    actual_return_date = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=USAGE_STATUS_CHOICES, default='Checked Out')
    purpose = models.TextField(null=True, blank=True)
    notes = models.TextField(null=True, blank=True)
    project = models.ForeignKey('Project', on_delete=models.SET_NULL, null=True, blank=True, related_name='inventory_usages', db_column='project_id')

    class Meta:
        ordering = ['-checkout_date']

    def __str__(self):
        return f"{self.inventory_item.name} → {self.checked_out_by.first_name} ({self.status})"
