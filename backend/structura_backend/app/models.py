from django.db import models
from django.contrib.auth.hashers import make_password


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

    created_at = models.DateTimeField(auto_now_add=True)

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='Active'
    )

    def save(self, *args, **kwargs):
        if self.password_hash and not self.password_hash.startswith('pbkdf2_'):
            self.password_hash = make_password(self.password_hash)
        super().save(*args, **kwargs)

    def __str__(self):
        return self.email


# Project Model
class Project(models.Model):
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
    status = models.CharField(max_length=50)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.project_name


# Supervisors Model
class Supervisors(models.Model):
    ROLE_CHOICES = [
        ('Supervisor', 'Supervisor'),
    ]
    
    supervisor_id = models.AutoField(primary_key=True)
    project_id = models.ForeignKey(Project, on_delete=models.SET_NULL, null=True, blank=True, related_name='supervisors')

    first_name = models.CharField(max_length=100, null=True, blank=True)
    middle_name = models.CharField(max_length=100, null=True, blank=True)
    last_name = models.CharField(max_length=100, null=True, blank=True)
    email = models.EmailField(max_length=100, unique=True)
    password_hash = models.CharField(max_length=255, default='PASSWORD')
    phone_number = models.CharField(max_length=20)
    birthdate = models.DateField(null=True, blank=True)
    
    # Supervisor-specific fields
    role = models.CharField(max_length=50, choices=ROLE_CHOICES, default='Supervisor')
    sss_id = models.CharField(max_length=20, null=True, blank=True)
    philhealth_id = models.CharField(max_length=20, null=True, blank=True)
    pagibig_id = models.CharField(max_length=20, null=True, blank=True)
    payrate = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)

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
    
    role = models.CharField(max_length=50, default='Mason')
    sss_id = models.CharField(max_length=20, null=True, blank=True)
    philhealth_id = models.CharField(max_length=20, null=True, blank=True)
    pagibig_id = models.CharField(max_length=20, null=True, blank=True)
    payrate = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    
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
    user_id = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='client_profile')
    project_id = models.ForeignKey(Project, on_delete=models.SET_NULL, null=True, blank=True, related_name='clients')

    first_name = models.CharField(max_length=100, null=True, blank=True)
    middle_name = models.CharField(max_length=100, null=True, blank=True)
    last_name = models.CharField(max_length=100, null=True, blank=True)
    email = models.EmailField(max_length=100, unique=True)
    password_hash = models.CharField(max_length=255, default='PASSWORD')
    phone_number = models.CharField(max_length=20)
    birthdate = models.DateField(null=True, blank=True)

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
    phase_name = models.CharField(max_length=100, choices=PHASE_CHOICES)
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
        unique_together = ('field_worker', 'attendance_date')
        ordering = ['-attendance_date']

    def __str__(self):
        return f"{self.field_worker.first_name} {self.field_worker.last_name} - {self.attendance_date}"
