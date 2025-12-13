from rest_framework import serializers
from app import models


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
    
    def create(self, validated_data):
        # Ensure password is hashed when creating
        user = models.User(**validated_data)
        user.save()
        return user
    
    def update(self, instance, validated_data):
        # Handle password hashing on update
        if 'password_hash' in validated_data:
            instance.password_hash = validated_data['password_hash']
            validated_data.pop('password_hash')
        
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
    class Meta:
        model = models.Project
        fields = [
            'project_id',
            'project_image',
            'project_name',
            'description',
            'region',
            'province',
            'city',
            'barangay',
            'street',
            'project_type',
            'start_date',
            'end_date',
            'client_id',
            'supervisor_id',
            'budget',
            'status',
            'created_at',
        ]


class SupervisorSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.Supervisor
        fields = [
            'supervisor_id',
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
            'supervisor_id': {'read_only': True},
            'created_at': {'read_only': True},
            'password_hash': {'write_only': True},  # Only accept on POST/PUT, don't return in GET
        }
    
    def create(self, validated_data):
        # Ensure password is hashed when creating
        supervisor = models.Supervisor(**validated_data)
        supervisor.save()
        return supervisor


class ClientSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.Client
        fields = [
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
        }
    
    def create(self, validated_data):
        # Ensure password is hashed when creating
        client = models.Client(**validated_data)
        client.save()
        return client