from rest_framework import serializers
from .email_utils import send_invitation_email
from app import models


class UserSerializer(serializers.ModelSerializer):
    user_id = serializers.IntegerField(read_only=True)
    created_at = serializers.DateTimeField(read_only=True)
    first_name = serializers.CharField(required=False, allow_blank=True, default='')
    last_name = serializers.CharField(required=False, allow_blank=True, default='')
    
    class Meta:
        model = models.User
        fields = [
            'user_id',
            'email',
            'password_hash',
            'first_name',
            'middle_name',
            'last_name',
            'birthdate',
            'phone',
            'region',
            'province',
            'city',
            'barangay',
            'street',
            'role',
            'created_at',
            'status',
        ]
    
    def create(self, validated_data):
        user = models.User(**validated_data)
        user.save()
        return user
    
    def update(self, instance, validated_data):
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        return instance


class RegionSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.Region
        fields = ['id', 'code', 'name']


class ProvinceSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.Province
        fields = ['id', 'code', 'name', 'region']


class CitySerializer(serializers.ModelSerializer):
    class Meta:
        model = models.City
        fields = ['id', 'code', 'name', 'province']


class BarangaySerializer(serializers.ModelSerializer):
    class Meta:
        model = models.Barangay
        fields = ['id', 'code', 'name', 'city']


class ProjectSerializer(serializers.ModelSerializer):
    region_name = serializers.CharField(source='region.name', read_only=True)
    province_name = serializers.CharField(source='province.name', read_only=True)
    city_name = serializers.CharField(source='city.name', read_only=True)
    barangay_name = serializers.CharField(source='barangay.name', read_only=True)
    
    class Meta:
        model = models.Project
        fields = [
            'project_id',
            'project_image',
            'project_name',
            'description',
            'user',
            'region',
            'province',
            'city',
            'barangay',
            'region_name',
            'province_name',
            'city_name',
            'barangay_name',
            'street',
            'project_type',
            'start_date',
            'end_date',
            'duration_days',
            'client',
            'supervisor',
            'budget',
            'status',
            'created_at',
        ]
        extra_kwargs = {
            'user': {'required': False, 'allow_null': True},
            'project_id': {'read_only': True},
            'created_at': {'read_only': True},
        }
    
    def create(self, validated_data):
        # Create the project first
        project = models.Project.objects.create(**validated_data)
        
        # Update supervisor's project_id if supervisor was assigned
        if validated_data.get('supervisor'):
            supervisor = validated_data['supervisor']
            supervisor.project_id = project
            supervisor.save()
        
        # Update client's project_id if client was assigned
        if validated_data.get('client'):
            client = validated_data['client']
            client.project_id = project
            client.save()
        
        return project
    
    def update(self, instance, validated_data):
        # If supervisor changed, update both old and new
        new_supervisor = validated_data.get('supervisor')
        old_supervisor = instance.supervisor
        
        if new_supervisor != old_supervisor:
            # Clear old supervisor's project_id
            if old_supervisor:
                old_supervisor.project_id = None
                old_supervisor.save()
            
            # Set new supervisor's project_id
            if new_supervisor:
                new_supervisor.project_id = instance
                new_supervisor.save()
        
        # If client changed, update both old and new
        new_client = validated_data.get('client')
        old_client = instance.client
        
        if new_client != old_client:
            # Clear old client's project_id
            if old_client:
                old_client.project_id = None
                old_client.save()
            
            # Set new client's project_id
            if new_client:
                new_client.project_id = instance
                new_client.save()
        
        # Update the project instance
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        return instance


class SupervisorsSerializer(serializers.ModelSerializer):
    invited_by_email = serializers.EmailField(
        write_only=True,
        required=False,
        allow_blank=True,
    )
    invited_by_name = serializers.CharField(
        write_only=True,
        required=False,
        allow_blank=True,
    )
    project_name = serializers.CharField(
        write_only=True,
        required=False,
        allow_blank=True,
    )

    class Meta:
        model = models.Supervisors
        fields = [
            'invited_by_email',
            'invited_by_name',
            'project_name',
            'supervisor_id',
            'project_id',
            'first_name',
            'middle_name',
            'last_name',
            'email',
            'password_hash',
            'phone_number',
            'birthdate',
            'role',
            'sss_id',
            'philhealth_id',
            'pagibig_id',
            'payrate',
            'created_at',
        ]
        extra_kwargs = {
            'project_id': {'required': False, 'allow_null': True},
            'supervisor_id': {'read_only': True},
            'created_at': {'read_only': True},
            'password_hash': {'write_only': True},
            'role': {'read_only': True},  # Role is always Supervisor
            'middle_name': {'required': False, 'allow_null': True},
            'birthdate': {'required': False, 'allow_null': True},
            'sss_id': {'required': False, 'allow_null': True},
            'philhealth_id': {'required': False, 'allow_null': True},
            'pagibig_id': {'required': False, 'allow_null': True},
            'payrate': {'required': False, 'allow_null': True},
        }
    
    def create(self, validated_data):
        invited_by_email = validated_data.pop('invited_by_email', '')
        invited_by_name = validated_data.pop('invited_by_name', '')
        project_name = validated_data.pop('project_name', '')

        plain_password = validated_data.get('password_hash', 'PASSWORD')
        # Create supervisor with all fields
        supervisor = models.Supervisors(**validated_data)
        supervisor.save()

        send_invitation_email(
            to_email=supervisor.email,
            first_name=supervisor.first_name,
            role='Supervisor',
            temp_password=str(plain_password),
            invited_by_email=invited_by_email,
            invited_by_name=invited_by_name,
            project_name=project_name,
        )
        return supervisor


class SupervisorSerializer(serializers.ModelSerializer):
    invited_by_email = serializers.EmailField(
        write_only=True,
        required=False,
        allow_blank=True,
    )
    invited_by_name = serializers.CharField(
        write_only=True,
        required=False,
        allow_blank=True,
    )
    project_name = serializers.CharField(
        write_only=True,
        required=False,
        allow_blank=True,
    )

    class Meta:
        model = models.Supervisors
        fields = [
            'invited_by_email',
            'invited_by_name',
            'project_name',
            'supervisor_id',
            'project_id',
            'first_name',
            'middle_name',
            'last_name',
            'email',
            'password_hash',
            'phone_number',
            'birthdate',
            'role',
            'sss_id',
            'philhealth_id',
            'pagibig_id',
            'payrate',
            'created_at',
        ]
        extra_kwargs = {
            'project_id': {'required': False, 'allow_null': True},
            'supervisor_id': {'read_only': True},
            'created_at': {'read_only': True},
            'password_hash': {'write_only': True},
            'role': {'read_only': True},  # Role is always Supervisor
            'middle_name': {'required': False, 'allow_null': True},
            'birthdate': {'required': False, 'allow_null': True},
            'sss_id': {'required': False, 'allow_null': True},
            'philhealth_id': {'required': False, 'allow_null': True},
            'pagibig_id': {'required': False, 'allow_null': True},
            'payrate': {'required': False, 'allow_null': True},
        }
    
    def create(self, validated_data):
        invited_by_email = validated_data.pop('invited_by_email', '')
        invited_by_name = validated_data.pop('invited_by_name', '')
        project_name = validated_data.pop('project_name', '')

        plain_password = validated_data.get('password_hash', 'PASSWORD')
        # Create supervisor with all fields
        supervisor = models.Supervisors(**validated_data)
        supervisor.save()

        send_invitation_email(
            to_email=supervisor.email,
            role='Supervisor',
            temp_password=str(plain_password),
            invited_by_email=invited_by_email,
            invited_by_name=invited_by_name,
            project_name=project_name,
        )
        return supervisor


class FieldWorkerSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.FieldWorker
        fields = [
            'fieldworker_id',
            'user_id',
            'project_id',
            'first_name',
            'middle_name',
            'last_name',
            'phone_number',
            'birthdate',
            'role',
            'sss_id',
            'philhealth_id',
            'pagibig_id',
            'payrate',
            'created_at',
        ]
        extra_kwargs = {
            'fieldworker_id': {'read_only': True},
            'created_at': {'read_only': True},
            'project_id': {'required': False, 'allow_null': True},
            'user_id': {'required': False, 'allow_null': True},
        }
    
    def create(self, validated_data):
        # If the client doesn't send a user_id (common for Supervisor logins where
        # user_id is not a real User PK), infer it from the project when possible.
        if validated_data.get('user_id') is None:
            project = validated_data.get('project_id')
            if project is not None and getattr(project, 'user', None) is not None:
                validated_data['user_id'] = project.user

        field_worker = models.FieldWorker(**validated_data)
        field_worker.save()
        return field_worker


class ClientSerializer(serializers.ModelSerializer):
    invited_by_email = serializers.EmailField(
        write_only=True,
        required=False,
        allow_blank=True,
    )
    invited_by_name = serializers.CharField(
        write_only=True,
        required=False,
        allow_blank=True,
    )
    project_name = serializers.CharField(
        write_only=True,
        required=False,
        allow_blank=True,
    )

    class Meta:
        model = models.Client
        fields = [
            'invited_by_email',
            'invited_by_name',
            'project_name',
            'client_id',
            'user_id',
            'project_id',
            'first_name',
            'middle_name',
            'last_name',
            'email',
            'password_hash',
            'phone_number',
            'birthdate',
            'status',
            'created_at',
        ]
        extra_kwargs = {
            'user_id': {'required': False, 'allow_null': True},
            'project_id': {'required': False, 'allow_null': True},
            'client_id': {'read_only': True},
            'created_at': {'read_only': True},
            'password_hash': {'write_only': True},  # Only accept on POST/PUT, don't return in GET
            'middle_name': {'required': False, 'allow_null': True},
            'birthdate': {'required': False, 'allow_null': True},
        }
    
    def create(self, validated_data):
        invited_by_email = validated_data.pop('invited_by_email', '')
        invited_by_name = validated_data.pop('invited_by_name', '')
        project_name = validated_data.pop('project_name', '')

        plain_password = validated_data.get('password_hash', 'PASSWORD')
        # Auto-create User account if user_id is not provided
        if 'user_id' not in validated_data or validated_data.get('user_id') is None:
            user = models.User.objects.create(
                email=validated_data['email'],
                password_hash=validated_data['password_hash'],
                first_name=validated_data['first_name'],
                middle_name=validated_data.get('middle_name'),
                last_name=validated_data['last_name'],
                birthdate=validated_data.get('birthdate'),
                phone=validated_data.get('phone_number'),
                role='Client',
                status='Active'
            )
            validated_data['user_id'] = user
        
        # Create client with all fields
        client = models.Client(**validated_data)
        client.save()

        send_invitation_email(
            to_email=client.email,
            first_name=client.first_name,
            role='Client',
            temp_password=str(plain_password),
            invited_by_email=invited_by_email,
            invited_by_name=invited_by_name,
            project_name=project_name,
        )
        return client


class SubtaskSerializer(serializers.ModelSerializer):
    assigned_workers = serializers.SerializerMethodField()

    class Meta:
        model = models.Subtask
        fields = [
            'subtask_id',
            'phase',
            'title',
            'status',
            'progress_notes',
            'created_at',
            'updated_at',
            'assigned_workers',
        ]
        extra_kwargs = {
            'subtask_id': {'read_only': True},
            'phase': {'required': False},
            'created_at': {'read_only': True},
            'updated_at': {'read_only': True},
            'progress_notes': {'required': False, 'allow_blank': True, 'allow_null': True},
        }

    def get_assigned_workers(self, obj):
        assignments = obj.assigned_workers.select_related('field_worker')
        workers = []
        for assignment in assignments:
            worker = assignment.field_worker
            workers.append({
                'assignment_id': assignment.assignment_id,
                'fieldworker_id': worker.fieldworker_id,
                'first_name': worker.first_name,
                'last_name': worker.last_name,
                'role': worker.role,
            })
        return workers


class PhaseSerializer(serializers.ModelSerializer):
    subtasks = SubtaskSerializer(many=True, required=False)
    project_id = serializers.IntegerField(source='project.project_id', read_only=True)

    class Meta:
        model = models.Phase
        fields = [
            'phase_id',
            'project_id',
            'project',
            'phase_name',
            'description',
            'days_duration',
            'status',
            'created_at',
            'updated_at',
            'subtasks',
        ]
        extra_kwargs = {
            'phase_id': {'read_only': True},
            'created_at': {'read_only': True},
            'updated_at': {'read_only': True},
        }

    def create(self, validated_data):
        subtasks_data = validated_data.pop('subtasks', [])
        phase = models.Phase.objects.create(**validated_data)
        
        for subtask_data in subtasks_data:
            models.Subtask.objects.create(phase=phase, **subtask_data)
        
        return phase

    def update(self, instance, validated_data):
        subtasks_data = validated_data.pop('subtasks', None)
        
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        if subtasks_data is not None:
            # Delete existing subtasks and recreate
            instance.subtasks.all().delete()
            for subtask_data in subtasks_data:
                models.Subtask.objects.create(phase=instance, **subtask_data)
        
        return instance


class SubtaskFieldWorkerSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.SubtaskFieldWorker
        fields = [
            'assignment_id',
            'subtask',
            'field_worker',
            'assigned_at',
        ]
        extra_kwargs = {
            'assignment_id': {'read_only': True},
            'assigned_at': {'read_only': True},
        }


class AttendanceSerializer(serializers.ModelSerializer):
    field_worker_name = serializers.SerializerMethodField()
    
    class Meta:
        model = models.Attendance
        fields = [
            'attendance_id',
            'field_worker',
            'field_worker_name',
            'project',
            'attendance_date',
            'check_in_time',
            'check_out_time',
            'break_in_time',
            'break_out_time',
            'status',
            'created_at',
            'updated_at',
        ]
        extra_kwargs = {
            'attendance_id': {'read_only': True},
            'created_at': {'read_only': True},
            'updated_at': {'read_only': True},
        }
    
    def get_field_worker_name(self, obj):
        return f"{obj.field_worker.first_name} {obj.field_worker.last_name}"