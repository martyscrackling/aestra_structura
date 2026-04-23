from django.core.exceptions import ObjectDoesNotExist
from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver

from . import models


@receiver(post_save, sender=models.Subtask)
@receiver(post_delete, sender=models.Subtask)
def subtask_changed_refresh_overdue(sender, instance, **kwargs):
    try:
        project = instance.phase.project
    except (ObjectDoesNotExist, AttributeError):
        return
    project.refresh_overdue_status()


@receiver(post_save, sender=models.Phase)
@receiver(post_delete, sender=models.Phase)
def phase_changed_refresh_overdue(sender, instance, **kwargs):
    if not getattr(instance, 'project_id', None):
        return
    try:
        project = models.Project.objects.get(project_id=instance.project_id)
    except models.Project.DoesNotExist:
        return
    project.refresh_overdue_status()
