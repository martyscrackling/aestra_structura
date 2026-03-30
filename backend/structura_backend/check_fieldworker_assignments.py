#!/usr/bin/env python
"""
Quick script to check field worker assignments in the database.
Run: python check_fieldworker_assignments.py
"""

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'structura_backend.settings')
django.setup()

from app.models import FieldWorker, SubtaskFieldWorker, Phase

print("\n" + "="*80)
print("FIELD WORKER ASSIGNMENT CHECK")
print("="*80)

# Get all field workers
field_workers = FieldWorker.objects.all()
print(f"\nTotal Field Workers: {field_workers.count()}")

for fw in field_workers[:10]:  # Show first 10
    print(f"\n{'─'*80}")
    print(f"📌 {fw.first_name} {fw.last_name} (ID: {fw.fieldworker_id})")
    print(f"   Direct Project: {fw.project_id.project_name if fw.project_id else 'NONE'}")
    
    # Check subtask assignments
    subtask_assignments = SubtaskFieldWorker.objects.filter(
        field_worker_id=fw.fieldworker_id
    ).select_related('subtask__phase__project')
    
    print(f"   Subtask Assignments: {subtask_assignments.count()}")
    for i, assignment in enumerate(subtask_assignments, 1):
        project = assignment.subtask.phase.project
        phase = assignment.subtask.phase
        subtask = assignment.subtask
        print(f"     {i}. {project.project_name} > {phase.phase_name} > {subtask.title}")
    
    # Check direct project phases
    if fw.project_id:
        phases = Phase.objects.filter(project_id=fw.project_id.project_id)
        print(f"   Phases in Direct Project: {phases.count()}")
        for i, phase in enumerate(phases[:3], 1):
            print(f"     {i}. {phase.phase_name}")

print(f"\n{'='*80}")
print(f"Total SubtaskFieldWorker records in DB: {SubtaskFieldWorker.objects.count()}")
print(f"{'='*80}\n")
