import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_config.dart';

class PmDashboardSummary {
  final int totalProjects;
  final List<PmRecentProject> recentProjects;

  final int totalTasks;
  final int completedTasks;
  final int inProgressTasks;
  final int pendingTasks;
  final int assignedTasks;
  final double completionRate;

  final List<PmActivityPoint> activitySeries;

  final int supervisorsCount;
  final int fieldWorkersTotal;
  final Map<String, int> fieldWorkersByRole;

  final List<PmTaskTodayItem> tasksToday;

  final int notificationsCount;
  final List<PmTaskTodayItem> notificationsItems;

  const PmDashboardSummary({
    required this.totalProjects,
    required this.recentProjects,
    required this.totalTasks,
    required this.completedTasks,
    required this.inProgressTasks,
    required this.pendingTasks,
    required this.assignedTasks,
    required this.completionRate,
    required this.activitySeries,
    required this.supervisorsCount,
    required this.fieldWorkersTotal,
    required this.fieldWorkersByRole,
    required this.tasksToday,
    required this.notificationsCount,
    required this.notificationsItems,
  });

  factory PmDashboardSummary.fromJson(Map<String, dynamic> json) {
    final projects = (json['projects'] as Map<String, dynamic>? ?? const {});
    final tasks = (json['tasks'] as Map<String, dynamic>? ?? const {});
    final activity = (json['activity'] as Map<String, dynamic>? ?? const {});
    final workers = (json['workers'] as Map<String, dynamic>? ?? const {});
    final notifications =
        (json['notifications'] as Map<String, dynamic>? ?? const {});

    final recentProjectsRaw =
        (projects['recent'] as List<dynamic>? ?? const []);
    final tasksTodayRaw = (json['tasks_today'] as List<dynamic>? ?? const []);
    final activitySeriesRaw =
        (activity['series'] as List<dynamic>? ?? const []);

    final notificationsItemsRaw = (notifications['items'] as List<dynamic>?);

    final byRoleRaw = (workers['by_role'] as Map<String, dynamic>? ?? const {});

    final totalTasks = (tasks['total'] as num?)?.toInt() ?? 0;
    final completedTasks = (tasks['completed'] as num?)?.toInt() ?? 0;
    final fallbackOpenTasks = (totalTasks - completedTasks).clamp(0, 1 << 30);

    final notificationsCount =
        (notifications['count'] as num?)?.toInt() ?? fallbackOpenTasks;

    return PmDashboardSummary(
      totalProjects: (projects['total'] as num?)?.toInt() ?? 0,
      recentProjects: recentProjectsRaw
          .whereType<Map<String, dynamic>>()
          .map(PmRecentProject.fromJson)
          .toList(),
      totalTasks: totalTasks,
      completedTasks: completedTasks,
      inProgressTasks: (tasks['in_progress'] as num?)?.toInt() ?? 0,
      pendingTasks: (tasks['pending'] as num?)?.toInt() ?? 0,
      assignedTasks: (tasks['assigned'] as num?)?.toInt() ?? 0,
      completionRate: (tasks['completion_rate'] as num?)?.toDouble() ?? 0.0,
      activitySeries: activitySeriesRaw
          .whereType<Map<String, dynamic>>()
          .map(PmActivityPoint.fromJson)
          .toList(),
      supervisorsCount: (workers['supervisors'] as num?)?.toInt() ?? 0,
      fieldWorkersTotal: (workers['field_workers_total'] as num?)?.toInt() ?? 0,
      fieldWorkersByRole: byRoleRaw.map(
        (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
      ),
      tasksToday: tasksTodayRaw
          .whereType<Map<String, dynamic>>()
          .map(PmTaskTodayItem.fromJson)
          .toList(),
      notificationsCount: notificationsCount,
      notificationsItems: (notificationsItemsRaw ?? tasksTodayRaw)
          .whereType<Map<String, dynamic>>()
          .map(PmTaskTodayItem.fromJson)
          .toList(),
    );
  }
}

class PmRecentProject {
  final int projectId;
  final String name;
  final String location;
  final double progress;
  final int tasksCompleted;
  final int totalTasks;

  const PmRecentProject({
    required this.projectId,
    required this.name,
    required this.location,
    required this.progress,
    required this.tasksCompleted,
    required this.totalTasks,
  });

  factory PmRecentProject.fromJson(Map<String, dynamic> json) {
    return PmRecentProject(
      projectId: (json['project_id'] as num?)?.toInt() ?? 0,
      name: (json['project_name'] as String?) ?? 'Untitled',
      location: (json['location'] as String?) ?? 'N/A',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      tasksCompleted: (json['tasks_completed'] as num?)?.toInt() ?? 0,
      totalTasks: (json['total_tasks'] as num?)?.toInt() ?? 0,
    );
  }
}

class PmActivityPoint {
  final DateTime day;
  final int completed;

  const PmActivityPoint({required this.day, required this.completed});

  factory PmActivityPoint.fromJson(Map<String, dynamic> json) {
    final dayStr = (json['day'] as String?) ?? '';
    final parsedDay =
        DateTime.tryParse(dayStr) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return PmActivityPoint(
      day: DateTime(parsedDay.year, parsedDay.month, parsedDay.day),
      completed: (json['completed'] as num?)?.toInt() ?? 0,
    );
  }
}

class PmAssignedWorker {
  final int fieldWorkerId;
  final String firstName;
  final String lastName;
  final String role;

  const PmAssignedWorker({
    required this.fieldWorkerId,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  factory PmAssignedWorker.fromJson(Map<String, dynamic> json) {
    return PmAssignedWorker(
      fieldWorkerId: (json['fieldworker_id'] as num?)?.toInt() ?? 0,
      firstName: (json['first_name'] as String?) ?? '',
      lastName: (json['last_name'] as String?) ?? '',
      role: (json['role'] as String?) ?? '',
    );
  }

  String get fullName {
    final name = ('$firstName $lastName').trim();
    return name.isEmpty ? 'Unknown' : name;
  }
}

class PmTaskTodayItem {
  final int subtaskId;
  final String title;
  final String status;
  final int? projectId;
  final String? projectName;
  final DateTime? updatedAt;
  final List<PmAssignedWorker> assignedWorkers;

  const PmTaskTodayItem({
    required this.subtaskId,
    required this.title,
    required this.status,
    required this.projectId,
    required this.projectName,
    required this.updatedAt,
    required this.assignedWorkers,
  });

  factory PmTaskTodayItem.fromJson(Map<String, dynamic> json) {
    final workersRaw = (json['assigned_workers'] as List<dynamic>? ?? const []);
    return PmTaskTodayItem(
      subtaskId: (json['subtask_id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? 'Untitled task',
      status: (json['status'] as String?) ?? 'pending',
      projectId: (json['project_id'] as num?)?.toInt(),
      projectName: json['project_name'] as String?,
      updatedAt: DateTime.tryParse((json['updated_at'] as String?) ?? ''),
      assignedWorkers: workersRaw
          .whereType<Map<String, dynamic>>()
          .map(PmAssignedWorker.fromJson)
          .toList(),
    );
  }
}

class PmDashboardService {
  static const Duration _timeout = Duration(seconds: 30);

  Future<PmDashboardSummary> fetchSummary({required int userId}) async {
    final uri = AppConfig.apiUri('pm/dashboard/?user_id=$userId');

    final response = await http.get(uri).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to load dashboard: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Dashboard request failed');
    }

    return PmDashboardSummary.fromJson(decoded);
  }
}
