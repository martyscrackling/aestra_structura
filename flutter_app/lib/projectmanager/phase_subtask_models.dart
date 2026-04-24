/// Shared [Phase] / [Subtask] / [WeeklyTask] models for PM project & subtask screens.
/// Keep in sync with Django `PhaseSerializer` / `SubtaskSerializer` field names.

int _jsonInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? 0}') ?? 0;
}

class WeeklyTask {
  final String weekTitle;
  final String description;
  final String status;
  final String date;
  final double progress;

  const WeeklyTask({
    required this.weekTitle,
    required this.description,
    required this.status,
    required this.date,
    required this.progress,
  });
}

class Subtask {
  final int subtaskId;
  final String title;
  final String status;
  final String? progressNotes;
  final List<Map<String, dynamic>> updatePhotos;
  final DateTime? updatedAt;
  final Map<String, dynamic>? pendingRevertRequest;

  Subtask({
    required this.subtaskId,
    required this.title,
    required this.status,
    this.progressNotes,
    this.updatePhotos = const [],
    this.updatedAt,
    this.pendingRevertRequest,
  });

  factory Subtask.fromJson(Map<String, dynamic> json) {
    final updatePhotosRaw = (json['update_photos'] is List)
        ? (json['update_photos'] as List)
        : const [];
    final updatePhotos = updatePhotosRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final updatedAtStr = json['updated_at'] as String?;
    final pendingRaw = json['pending_revert_request'];
    return Subtask(
      subtaskId: _jsonInt(json['subtask_id']),
      title: (json['title'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      progressNotes: json['progress_notes'] as String?,
      updatePhotos: updatePhotos,
      updatedAt: updatedAtStr != null ? DateTime.tryParse(updatedAtStr) : null,
      pendingRevertRequest: pendingRaw is Map
          ? Map<String, dynamic>.from(pendingRaw)
          : null,
    );
  }
}

class Phase {
  final int phaseId;
  final int projectId;
  final String phaseName;
  final String? description;
  final String status;
  final int? daysDuration;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final double allocatedBudget;
  final double usedBudget;
  final List<Subtask> subtasks;

  Phase({
    required this.phaseId,
    required this.projectId,
    required this.phaseName,
    this.description,
    required this.status,
    this.daysDuration,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.allocatedBudget = 0,
    this.usedBudget = 0,
    this.subtasks = const [],
  });

  /// When the phase is done, or every subtask is done, PM cannot add/change assignees.
  bool get isWorkerAssignmentLocked {
    if (status.toLowerCase().trim() == 'completed') {
      return true;
    }
    if (subtasks.isEmpty) {
      return false;
    }
    return subtasks.every(
      (s) => s.status.toLowerCase().trim() == 'completed',
    );
  }

  double calculateProgress() {
    if (subtasks.isEmpty) return 1.0;
    final completed = subtasks.where((s) => s.status == 'completed').length;
    return completed / subtasks.length;
  }

  factory Phase.fromJson(Map<String, dynamic> json) {
    final rawSubtasks = json['subtasks'];
    final List<Subtask> subtasks;
    if (rawSubtasks is List) {
      subtasks = rawSubtasks
          .whereType<Map>()
          .map((e) => Subtask.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      subtasks = const [];
    }

    final projectRaw = json['project_id'] ?? json['project'];
    int projectId = 0;
    if (projectRaw is int) {
      projectId = projectRaw;
    } else if (projectRaw is num) {
      projectId = projectRaw.toInt();
    } else if (projectRaw != null) {
      projectId = int.tryParse(projectRaw.toString()) ?? 0;
    }

    return Phase(
      phaseId: _jsonInt(json['phase_id']),
      projectId: projectId,
      phaseName: (json['phase_name'] ?? '').toString(),
      description: json['description'] as String?,
      status: (json['status'] ?? 'not_started').toString(),
      daysDuration: _optInt(json['days_duration']),
      startDate: _optDateTime(json['start_date']),
      endDate: _optDateTime(json['end_date']),
      createdAt: _optDateTime(json['created_at']),
      allocatedBudget: _asDouble(json['allocated_budget']),
      usedBudget: _asDouble(json['used_budget']),
      subtasks: subtasks,
    );
  }

  static int? _optInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static DateTime? _optDateTime(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
