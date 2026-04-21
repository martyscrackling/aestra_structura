from rest_framework import serializers
from django.db import IntegrityError, transaction
from decimal import Decimal, ROUND_HALF_UP
from .email_utils import send_invitation_email, send_project_assignment_email
from app import models
from app.image_verification import verify_image_has_human_face


_TWO_DP = Decimal('0.01')
_STANDARD_HOURS_PER_WEEK = Decimal('48')


def _q(value):
    return value.quantize(_TWO_DP, rounding=ROUND_HALF_UP)


def _to_decimal(value, default='0'):
    if value in (None, ''):
        return Decimal(default)
    if isinstance(value, Decimal):
        return value
    return Decimal(str(value))


def _weekly_statutory_minimums(weekly_salary):
    """Compute weekly employee-share statutory minimum deductions.

    These are intentionally centralized so rates/caps can be updated in one place.
    """
    weekly = _to_decimal(weekly_salary)
    monthly_equivalent = (weekly * Decimal('52')) / Decimal('12')

    # SSS employee share baseline: 5% of monthly equivalent, capped.
    sss_salary_base = min(monthly_equivalent, Decimal('35000'))
    sss_monthly_min = sss_salary_base * Decimal('0.05')

    # PhilHealth employee share: half of 5% premium with salary floor/ceiling.
    philhealth_base = max(Decimal('10000'), min(monthly_equivalent, Decimal('100000')))
    philhealth_monthly_min = (philhealth_base * Decimal('0.05')) / Decimal('2')

    # Pag-IBIG employee share with common mandatory cap behavior.
    pagibig_base = min(monthly_equivalent, Decimal('5000'))
    pagibig_rate = Decimal('0.01') if monthly_equivalent <= Decimal('1500') else Decimal('0.02')
    pagibig_monthly_min = pagibig_base * pagibig_rate

    return {
        'sss_weekly_min': _q((sss_monthly_min * Decimal('12')) / Decimal('52')),
        'philhealth_weekly_min': _q((philhealth_monthly_min * Decimal('12')) / Decimal('52')),
        'pagibig_weekly_min': _q((pagibig_monthly_min * Decimal('12')) / Decimal('52')),
    }


class UserSerializer(serializers.ModelSerializer):
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
        read_only_fields = ['user_id', 'created_at']
    
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
    client_first_name = serializers.CharField(source='client.first_name', read_only=True)
    client_last_name = serializers.CharField(source='client.last_name', read_only=True)
    client_email = serializers.CharField(source='client.email', read_only=True)
    client_phone_number = serializers.CharField(source='client.phone_number', read_only=True)
    client_photo = serializers.CharField(source='client.photo', read_only=True)
    
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
            'client_first_name',
            'client_last_name',
            'client_email',
            'client_phone_number',
            'client_photo',
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

        pm_user = getattr(project, 'user', None)
        pm_name = ''
        pm_email = ''
        if pm_user is not None:
            pm_name = f"{getattr(pm_user, 'first_name', '') or ''} {getattr(pm_user, 'last_name', '') or ''}".strip()
            pm_email = (getattr(pm_user, 'email', '') or '').strip()
        
        # Update supervisor's project_id if supervisor was assigned
        if validated_data.get('supervisor'):
            supervisor = validated_data['supervisor']
            supervisor.project_id = project
            supervisor.save()

            send_project_assignment_email(
                to_email=supervisor.email,
                first_name=getattr(supervisor, 'first_name', None),
                role='Supervisor',
                invited_by_email=pm_email,
                invited_by_name=pm_name,
                project_name=project.project_name,
            )
        
        # Update client's project_id if client was assigned
        if validated_data.get('client'):
            client = validated_data['client']
            client.project_id = project
            client.save()

            send_project_assignment_email(
                to_email=client.email,
                first_name=getattr(client, 'first_name', None),
                role='Client',
                invited_by_email=pm_email,
                invited_by_name=pm_name,
                project_name=project.project_name,
            )
        
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

        pm_user = getattr(instance, 'user', None)
        pm_name = ''
        pm_email = ''
        if pm_user is not None:
            pm_name = f"{getattr(pm_user, 'first_name', '') or ''} {getattr(pm_user, 'last_name', '') or ''}".strip()
            pm_email = (getattr(pm_user, 'email', '') or '').strip()

        # If a new assignment happened, notify the assignee.
        if new_supervisor and new_supervisor != old_supervisor:
            send_project_assignment_email(
                to_email=new_supervisor.email,
                first_name=getattr(new_supervisor, 'first_name', None),
                role='Supervisor',
                invited_by_email=pm_email,
                invited_by_name=pm_name,
                project_name=instance.project_name,
            )

        if new_client and new_client != old_client:
            send_project_assignment_email(
                to_email=new_client.email,
                first_name=getattr(new_client, 'first_name', None),
                role='Client',
                invited_by_email=pm_email,
                invited_by_name=pm_name,
                project_name=instance.project_name,
            )
        
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
            'created_by',
            'project_id',
            'first_name',
            'middle_name',
            'last_name',
            'email',
            'password_hash',
            'phone_number',
            'birthdate',
            'region',
            'province',
            'city',
            'barangay',
            'role',
            'sss_id',
            'philhealth_id',
            'pagibig_id',
            'payrate',
            'photo',
            'created_at',
        ]
        extra_kwargs = {
            'project_id': {'required': False, 'allow_null': True},
            'created_by': {'required': False, 'allow_null': True, 'read_only': True},
            'supervisor_id': {'read_only': True},
            'created_at': {'read_only': True},
            'password_hash': {'write_only': True},
            'role': {'read_only': True},  # Role is always Supervisor
            'first_name': {'required': False, 'allow_null': True},
            'last_name': {'required': False, 'allow_null': True},
            'middle_name': {'required': False, 'allow_null': True},
            'birthdate': {'required': False, 'allow_null': True},
            'region': {'required': False, 'allow_null': True},
            'province': {'required': False, 'allow_null': True},
            'city': {'required': False, 'allow_null': True},
            'barangay': {'required': False, 'allow_null': True},
            'sss_id': {'required': False, 'allow_null': True},
            'philhealth_id': {'required': False, 'allow_null': True},
            'pagibig_id': {'required': False, 'allow_null': True},
            'payrate': {'required': False, 'allow_null': True},
            'photo': {'required': False, 'allow_null': True},
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

    def validate_photo(self, value):
        if value is None:
            return value

        # Verify face presence before allowing any non-human photo.
        try:
            image_bytes = value.read()
            if hasattr(value, "seek"):
                value.seek(0)
        except Exception:
            return value  # Let model/save handle file errors; don't block unexpectedly.

        if not verify_image_has_human_face(image_bytes):
            raise serializers.ValidationError({
                'image_verification': 'REJECT',
                'detail': 'No human face detected. Please upload another photo containing the face of a human.',
            })
        return value


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
            'created_by',
            'project_id',
            'first_name',
            'middle_name',
            'last_name',
            'email',
            'password_hash',
            'phone_number',
            'birthdate',
            'region',
            'province',
            'city',
            'barangay',
            'role',
            'sss_id',
            'philhealth_id',
            'pagibig_id',
            'payrate',
            'photo',
            'created_at',
        ]
        extra_kwargs = {
            'project_id': {'required': False, 'allow_null': True},
            'created_by': {'required': False, 'allow_null': True, 'read_only': True},
            'supervisor_id': {'read_only': True},
            'created_at': {'read_only': True},
            'password_hash': {'write_only': True},
            'role': {'read_only': True},  # Role is always Supervisor
            'first_name': {'required': False, 'allow_null': True},
            'last_name': {'required': False, 'allow_null': True},
            'middle_name': {'required': False, 'allow_null': True},
            'birthdate': {'required': False, 'allow_null': True},
            'region': {'required': False, 'allow_null': True},
            'province': {'required': False, 'allow_null': True},
            'city': {'required': False, 'allow_null': True},
            'barangay': {'required': False, 'allow_null': True},
            'sss_id': {'required': False, 'allow_null': True},
            'philhealth_id': {'required': False, 'allow_null': True},
            'pagibig_id': {'required': False, 'allow_null': True},
            'payrate': {'required': False, 'allow_null': True},
            'photo': {'required': False, 'allow_null': True},
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

    def validate_photo(self, value):
        if value is None:
            return value

        try:
            image_bytes = value.read()
            if hasattr(value, "seek"):
                value.seek(0)
        except Exception:
            return value

        if not verify_image_has_human_face(image_bytes):
            raise serializers.ValidationError({
                'image_verification': 'REJECT',
                'detail': 'No human face detected. Please upload another photo containing the face of a human.',
            })
        return value


class FieldWorkerSerializer(serializers.ModelSerializer):
    assignment_status = serializers.SerializerMethodField()
    assigned_projects = serializers.SerializerMethodField()
    
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
            'region',
            'province',
            'city',
            'barangay',
            'role',
            'sss_id',
            'philhealth_id',
            'pagibig_id',
            'payrate',
            'cash_advance_balance',
            'deduction_per_salary',
            'weekly_salary',
            'sss_weekly_min',
            'philhealth_weekly_min',
            'pagibig_weekly_min',
            'sss_weekly_topup',
            'philhealth_weekly_topup',
            'pagibig_weekly_topup',
            'sss_weekly_total',
            'philhealth_weekly_total',
            'pagibig_weekly_total',
            'total_weekly_deduction',
            'net_weekly_pay',
            'photo',
            'assignment_status',
            'assigned_projects',
            'created_at',
        ]
        extra_kwargs = {
            'fieldworker_id': {'read_only': True},
            'created_at': {'read_only': True},
            'project_id': {'required': False, 'allow_null': True},
            'user_id': {'required': False, 'allow_null': True},
            'first_name': {'required': False, 'allow_null': True},
            'last_name': {'required': False, 'allow_null': True},
            'middle_name': {'required': False, 'allow_null': True},
            'birthdate': {'required': False, 'allow_null': True},
            'region': {'required': False, 'allow_null': True},
            'province': {'required': False, 'allow_null': True},
            'city': {'required': False, 'allow_null': True},
            'barangay': {'required': False, 'allow_null': True},
            'sss_id': {'required': False, 'allow_null': True},
            'philhealth_id': {'required': False, 'allow_null': True},
            'pagibig_id': {'required': False, 'allow_null': True},
            'payrate': {'required': False, 'allow_null': True},
            'cash_advance_balance': {'required': False, 'allow_null': True},
            'deduction_per_salary': {'required': False, 'allow_null': True},
            'weekly_salary': {'required': False, 'allow_null': True},
            'sss_weekly_topup': {'required': False, 'allow_null': True},
            'philhealth_weekly_topup': {'required': False, 'allow_null': True},
            'pagibig_weekly_topup': {'required': False, 'allow_null': True},
            'photo': {'required': False, 'allow_null': True},
        }

    def get_assignment_status(self, obj):
        """
        Determine if a field worker is 'Available' or 'Assigned' to another project.
        
        When viewing field workers for a specific project context:
        - If the worker is assigned to a subtask in ANY OTHER project -> 'Assigned'
        - Otherwise -> 'Available'
        """
        # Get the current project context from serializer context
        current_project_id = self.context.get('current_project_id')
        
        if current_project_id is None:
            # If no project context, always return 'Available'
            return 'Available'
        
        # Check if this worker is assigned to ANY subtask in OTHER projects
        from django.db.models import Q
        other_project_assignments = models.SubtaskFieldWorker.objects.filter(
            field_worker_id=obj.fieldworker_id
        ).filter(
            Q(subtask__phase__project_id__isnull=True) |  # Subtasks without a project
            ~Q(subtask__phase__project_id=current_project_id)  # OR subtasks in other projects
        ).exists()
        
        if other_project_assignments:
            return 'Assigned'
        return 'Available'

    def get_assigned_projects(self, obj):
        project_map = {}

        if obj.project_id is not None:
            project_map[obj.project_id.project_id] = obj.project_id.project_name

        assigned = (
            models.SubtaskFieldWorker.objects
            .filter(field_worker_id=obj.fieldworker_id)
            .select_related('subtask__phase__project')
        )
        for row in assigned:
            project = getattr(getattr(row.subtask, 'phase', None), 'project', None)
            if project is not None:
                project_map[project.project_id] = project.project_name

        return [
            {'project_id': pid, 'project_name': pname}
            for pid, pname in sorted(project_map.items(), key=lambda item: item[1].lower())
        ]

    def validate(self, attrs):
        cash_advance_balance = _to_decimal(
            attrs.get(
                'cash_advance_balance',
                self.instance.cash_advance_balance if self.instance is not None else Decimal('0'),
            )
        )
        deduction_per_salary = _to_decimal(
            attrs.get(
                'deduction_per_salary',
                self.instance.deduction_per_salary if self.instance is not None else Decimal('0'),
            )
        )

        if cash_advance_balance < 0:
            raise serializers.ValidationError({'cash_advance_balance': 'Cash advance cannot be negative.'})
        if deduction_per_salary < 0:
            raise serializers.ValidationError({'deduction_per_salary': 'Deduction per salary cannot be negative.'})

        attrs['cash_advance_balance'] = _q(cash_advance_balance)
        attrs['deduction_per_salary'] = _q(deduction_per_salary)

        payroll_keys = {
            'payrate',
            'weekly_salary',
            'sss_weekly_topup',
            'philhealth_weekly_topup',
            'pagibig_weekly_topup',
        }
        if self.instance is not None and not any(k in attrs for k in payroll_keys):
            return attrs

        weekly_salary = attrs.get('weekly_salary', None)
        payrate = attrs.get('payrate', None)
        hourly_payrate = None

        if weekly_salary in (None, '') and payrate not in (None, ''):
            hourly_payrate = _to_decimal(payrate)
            weekly_salary = hourly_payrate * _STANDARD_HOURS_PER_WEEK
        elif payrate not in (None, ''):
            hourly_payrate = _to_decimal(payrate)

        if weekly_salary in (None, '') and self.instance is not None:
            if self.instance.weekly_salary not in (None, ''):
                weekly_salary = self.instance.weekly_salary
            elif self.instance.payrate not in (None, ''):
                hourly_payrate = _to_decimal(self.instance.payrate)
                weekly_salary = hourly_payrate * _STANDARD_HOURS_PER_WEEK

        if hourly_payrate is None:
            hourly_payrate = _to_decimal(weekly_salary) / _STANDARD_HOURS_PER_WEEK

        if weekly_salary in (None, ''):
            raise serializers.ValidationError({'weekly_salary': 'Weekly salary is required.'})

        weekly_salary_dec = _to_decimal(weekly_salary)
        if weekly_salary_dec <= Decimal('0'):
            raise serializers.ValidationError({'weekly_salary': 'Weekly salary must be greater than zero.'})

        sss_topup = _to_decimal(attrs.get('sss_weekly_topup', Decimal('0')))
        philhealth_topup = _to_decimal(attrs.get('philhealth_weekly_topup', Decimal('0')))
        pagibig_topup = _to_decimal(attrs.get('pagibig_weekly_topup', Decimal('0')))

        if sss_topup < 0 or philhealth_topup < 0 or pagibig_topup < 0:
            raise serializers.ValidationError('Top-up deductions cannot be negative.')

        mins = _weekly_statutory_minimums(weekly_salary_dec)
        sss_total = _q(mins['sss_weekly_min'] + sss_topup)
        philhealth_total = _q(mins['philhealth_weekly_min'] + philhealth_topup)
        pagibig_total = _q(mins['pagibig_weekly_min'] + pagibig_topup)
        total_deduction = _q(sss_total + philhealth_total + pagibig_total)
        net_weekly = _q(weekly_salary_dec - total_deduction)

        attrs['weekly_salary'] = _q(weekly_salary_dec)
        attrs['payrate'] = _q(hourly_payrate)
        attrs['sss_weekly_min'] = mins['sss_weekly_min']
        attrs['philhealth_weekly_min'] = mins['philhealth_weekly_min']
        attrs['pagibig_weekly_min'] = mins['pagibig_weekly_min']
        attrs['sss_weekly_topup'] = _q(sss_topup)
        attrs['philhealth_weekly_topup'] = _q(philhealth_topup)
        attrs['pagibig_weekly_topup'] = _q(pagibig_topup)
        attrs['sss_weekly_total'] = sss_total
        attrs['philhealth_weekly_total'] = philhealth_total
        attrs['pagibig_weekly_total'] = pagibig_total
        attrs['total_weekly_deduction'] = total_deduction
        attrs['net_weekly_pay'] = net_weekly
        return attrs

    def validate_photo(self, value):
        if value is None:
            return value

        try:
            image_bytes = value.read()
            if hasattr(value, "seek"):
                value.seek(0)
        except Exception:
            return value

        if not verify_image_has_human_face(image_bytes):
            raise serializers.ValidationError({
                'image_verification': 'REJECT',
                'detail': 'No human face detected. Please upload another photo containing the face of a human.',
            })
        return value
    
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
            'created_by',
            'user_id',
            'project_id',
            'first_name',
            'middle_name',
            'last_name',
            'email',
            'password_hash',
            'phone_number',
            'birthdate',
            'region',
            'province',
            'city',
            'barangay',
            'photo',
            'status',
            'created_at',
        ]
        extra_kwargs = {
            'user_id': {'required': False, 'allow_null': True},
            'project_id': {'required': False, 'allow_null': True},
            'created_by': {'required': False, 'allow_null': True, 'read_only': True},
            'client_id': {'read_only': True},
            'created_at': {'read_only': True},
            'password_hash': {'write_only': True},  # Only accept on POST/PUT, don't return in GET
            'first_name': {'required': False, 'allow_null': True},
            'last_name': {'required': False, 'allow_null': True},
            'middle_name': {'required': False, 'allow_null': True},
            'birthdate': {'required': False, 'allow_null': True},
            'region': {'required': False, 'allow_null': True},
            'province': {'required': False, 'allow_null': True},
            'city': {'required': False, 'allow_null': True},
            'barangay': {'required': False, 'allow_null': True},
            'photo': {'required': False, 'allow_null': True},
        }
    
    def create(self, validated_data):
        invited_by_email = validated_data.pop('invited_by_email', '')
        invited_by_name = validated_data.pop('invited_by_name', '')
        project_name = validated_data.pop('project_name', '')

        plain_password = validated_data.get('password_hash', 'PASSWORD')
        try:
            with transaction.atomic():
                # Client creation should write only to app_client.
                # Ignore any incoming user_id to avoid creating/linking app_user rows.
                validated_data['user_id'] = None

                # Create client profile row.
                client = models.Client(**validated_data)
                client.save()
        except IntegrityError:
            raise serializers.ValidationError({
                'detail': 'A client/user with this email already exists.'
            })

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

    def validate_photo(self, value):
        if value is None:
            return value

        try:
            image_bytes = value.read()
            if hasattr(value, "seek"):
                value.seek(0)
        except Exception:
            return value

        if not verify_image_has_human_face(image_bytes):
            raise serializers.ValidationError({
                'image_verification': 'REJECT',
                'detail': 'No human face detected. Please upload another photo containing the face of a human.',
            })
        return value


class BackJobReviewSerializer(serializers.ModelSerializer):
    client_name = serializers.SerializerMethodField()
    project_name = serializers.CharField(source='project.project_name', read_only=True)

    class Meta:
        model = models.BackJobReview
        fields = [
            'review_id',
            'project',
            'project_name',
            'client',
            'client_name',
            'review_text',
            'is_resolved',
            'created_at',
            'updated_at',
        ]
        extra_kwargs = {
            'review_id': {'read_only': True},
            'created_at': {'read_only': True},
            'updated_at': {'read_only': True},
        }

    def get_client_name(self, obj):
        if obj.client is None:
            return 'Client'
        first = (obj.client.first_name or '').strip()
        last = (obj.client.last_name or '').strip()
        name = f'{first} {last}'.strip()
        if name:
            return name
        if obj.client.email:
            return obj.client.email
        return 'Client'


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
            if worker is None:
                continue
            worker_id = worker.fieldworker_id
            workers.append({
                'assignment_id': assignment.assignment_id,
                # Keep common id aliases for compatibility across app screens.
                'fieldworker_id': worker_id,
                'id': worker_id,
                'first_name': worker.first_name,
                'last_name': worker.last_name,
                'role': worker.role,
                'photo': worker.photo.url if worker.photo else None,
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

    def validate(self, attrs):
        attrs = super().validate(attrs)

        field_worker = attrs.get(
            'field_worker',
            self.instance.field_worker if self.instance is not None else None,
        )
        project = attrs.get(
            'project',
            self.instance.project if self.instance is not None else None,
        )
        incoming_check_in = attrs.get('check_in_time', serializers.empty)

        # Only guard when this request is attempting to time in.
        if field_worker is None or project is None or incoming_check_in in (serializers.empty, None):
            return attrs

        open_attendance_qs = models.Attendance.objects.filter(
            field_worker=field_worker,
            check_in_time__isnull=False,
            check_out_time__isnull=True,
        ).exclude(project=project)

        if self.instance is not None:
            open_attendance_qs = open_attendance_qs.exclude(pk=self.instance.pk)

        conflicting_open_record = open_attendance_qs.select_related('project').order_by('-attendance_date').first()
        if conflicting_open_record is not None:
            project_name = conflicting_open_record.project.project_name if conflicting_open_record.project else 'another project'
            raise serializers.ValidationError(
                {
                    'non_field_errors': [
                        (
                            'This worker is currently timed in on '
                            f'"{project_name}". Please time out first before '
                            'timing in to another project.'
                        )
                    ],
                    'conflict_project_name': project_name,
                    'conflict_project_id': conflicting_open_record.project_id,
                }
            )

        return attrs


class InventoryUsageSerializer(serializers.ModelSerializer):
    supervisor_name = serializers.SerializerMethodField()
    field_worker_name = serializers.SerializerMethodField()
    project_name = serializers.SerializerMethodField()
    unit_code = serializers.SerializerMethodField()

    class Meta:
        model = models.InventoryUsage
        fields = [
            'usage_id',
            'inventory_item',
            'inventory_unit',
            'unit_code',
            'checked_out_by',
            'supervisor_name',
            'field_worker',
            'field_worker_name',
            'project',
            'project_name',
            'checkout_date',
            'expected_return_date',
            'actual_return_date',
            'status',
            'purpose',
            'notes',
        ]
        extra_kwargs = {
            'usage_id': {'read_only': True},
            'checkout_date': {'read_only': True},
            'actual_return_date': {'read_only': True},
        }

    def get_supervisor_name(self, obj):
        sv = obj.checked_out_by
        return f"{sv.first_name} {sv.last_name}".strip() if sv else ''

    def get_field_worker_name(self, obj):
        fw = obj.field_worker
        return f"{fw.first_name} {fw.last_name}".strip() if fw else ''

    def get_project_name(self, obj):
        return obj.project.project_name if obj.project else ''

    def get_unit_code(self, obj):
        return obj.inventory_unit.unit_code if obj.inventory_unit else ''


class InventoryUnitMovementSerializer(serializers.ModelSerializer):
    from_project_name = serializers.SerializerMethodField()
    to_project_name = serializers.SerializerMethodField()
    moved_by_name = serializers.SerializerMethodField()

    class Meta:
        model = models.InventoryUnitMovement
        fields = [
            'movement_id',
            'unit',
            'from_project',
            'from_project_name',
            'to_project',
            'to_project_name',
            'action',
            'moved_by',
            'moved_by_name',
            'notes',
            'created_at',
        ]

    def get_from_project_name(self, obj):
        return obj.from_project.project_name if obj.from_project else ''

    def get_to_project_name(self, obj):
        return obj.to_project.project_name if obj.to_project else ''

    def get_moved_by_name(self, obj):
        if not obj.moved_by:
            return ''
        return f"{obj.moved_by.first_name or ''} {obj.moved_by.last_name or ''}".strip()


class InventoryUnitSerializer(serializers.ModelSerializer):
    current_project_name = serializers.SerializerMethodField()
    active_usage = serializers.SerializerMethodField()

    class Meta:
        model = models.InventoryUnit
        fields = [
            'unit_id',
            'inventory_item',
            'unit_code',
            'status',
            'current_project',
            'current_project_name',
            'active_usage',
            'created_at',
            'updated_at',
        ]

    def get_current_project_name(self, obj):
        return obj.current_project.project_name if obj.current_project else ''

    def get_active_usage(self, obj):
        usage = obj.usages.filter(status='Checked Out').order_by('-checkout_date').first()
        if not usage:
            return None
        return InventoryUsageSerializer(usage).data


class InventoryItemSerializer(serializers.ModelSerializer):
    quantity = serializers.SerializerMethodField()
    created_by_name = serializers.SerializerMethodField()
    active_usages = serializers.SerializerMethodField()
    photo_url = serializers.SerializerMethodField()
    project_name = serializers.SerializerMethodField()
    units = serializers.SerializerMethodField()
    assigned_projects_count = serializers.SerializerMethodField()

    class Meta:
        model = models.InventoryItem
        fields = [
            'item_id',
            'name',
            'category',
            'serial_number',
            'quantity',
            'location',
            'notes',
            'photo',
            'photo_url',
            'status',
            'created_by',
            'created_by_name',
            'project',
            'project_name',
            'assigned_projects_count',
            'units',
            'active_usages',
            'created_at',
            'updated_at',
        ]
        extra_kwargs = {
            'item_id': {'read_only': True},
            'created_at': {'read_only': True},
            'updated_at': {'read_only': True},
            'photo': {'read_only': True},
        }

    def get_created_by_name(self, obj):
        u = obj.created_by
        return f"{u.first_name} {u.last_name}".strip() if u else ''

    def _get_supervisor_project_ids(self):
        request = self.context.get('request')
        if not request:
            return None
        supervisor_id = request.query_params.get('supervisor_id')
        if not supervisor_id:
            return None
        try:
            sv = models.Supervisors.objects.get(supervisor_id=int(supervisor_id))
        except (models.Supervisors.DoesNotExist, ValueError, TypeError):
            return []
        return list(
            models.Project.objects
            .filter(supervisor_id=sv.supervisor_id)
            .values_list('project_id', flat=True)
        )

    def _get_visible_units_queryset(self, obj):
        units_qs = obj.units.select_related('current_project').all()
        project_ids = self._get_supervisor_project_ids()
        if project_ids is None:
            return units_qs
        return units_qs.filter(current_project_id__in=project_ids)

    def get_quantity(self, obj):
        return self._get_visible_units_queryset(obj).count()

    def get_units(self, obj):
        units_qs = self._get_visible_units_queryset(obj)
        return InventoryUnitSerializer(units_qs, many=True).data

    def get_active_usages(self, obj):
        active = obj.usages.filter(status='Checked Out')
        project_ids = self._get_supervisor_project_ids()
        if project_ids is not None:
            active = active.filter(inventory_unit__current_project_id__in=project_ids)
        return InventoryUsageSerializer(active, many=True).data

    def get_project_name(self, obj):
        project_names = {
            u.current_project.project_name
            for u in self._get_visible_units_queryset(obj)
            if u.current_project
        }
        if len(project_names) == 1:
            return next(iter(project_names))
        if len(project_names) > 1:
            return 'Multiple Projects'
        return ''

    def get_assigned_projects_count(self, obj):
        return (
            self._get_visible_units_queryset(obj)
            .exclude(current_project__isnull=True)
            .values('current_project')
            .distinct()
            .count()
        )

    def get_photo_url(self, obj):
        if obj.photo and hasattr(obj.photo, 'url'):
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.photo.url)
            return obj.photo.url
        return None