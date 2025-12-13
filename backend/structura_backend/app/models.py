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

    first_name = models.CharField(max_length=100)
    middle_name = models.CharField(max_length=100, null=True, blank=True)
    last_name = models.CharField(max_length=100)

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
    client_id = models.IntegerField()
    supervisor_id = models.IntegerField()
    budget = models.DecimalField(max_digits=12, decimal_places=2)
    status = models.CharField(max_length=50)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.project_name


# Supervisor Model
class Supervisor(models.Model):
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('deactivated', 'Deactivated'),
        ('fired', 'Fired'),
    ]
    supervisor_id = models.AutoField(primary_key=True)
    user_id = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='supervisor_profile')
    project_id = models.ForeignKey(Project, on_delete=models.SET_NULL, null=True, blank=True, related_name='supervisors')

    first_name = models.CharField(max_length=100)
    middle_name = models.CharField(max_length=100, null=True, blank=True)
    last_name = models.CharField(max_length=100)
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


# Client Model
class Client(models.Model):
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('deactivated', 'Deactivated'),
    ]
    client_id = models.AutoField(primary_key=True)
    user_id = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='client_profile')
    project_id = models.ForeignKey(Project, on_delete=models.SET_NULL, null=True, blank=True, related_name='clients')

    first_name = models.CharField(max_length=100)
    middle_name = models.CharField(max_length=100, null=True, blank=True)
    last_name = models.CharField(max_length=100)
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
