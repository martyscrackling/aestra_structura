from django.contrib import admin
from .models import User

class UserAdmin(admin.ModelAdmin):
    readonly_fields = ('password_hash',)

admin.site.register(User, UserAdmin)
