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
  final List<PmActivityMonthPoint> monthlySeries;

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
    required this.monthlySeries,
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
    final monthlySeriesRaw =
        (activity['monthly_series'] as List<dynamic>? ?? const []);

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
      monthlySeries: monthlySeriesRaw
          .whereType<Map<String, dynamic>>()
          .map(PmActivityMonthPoint.fromJson)
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
  final String? image;
  final String? budget;

  const PmRecentProject({
    required this.projectId,
    required this.name,
    required this.location,
    required this.progress,
    required this.tasksCompleted,
    required this.totalTasks,
    this.image,
    this.budget,
  });

  factory PmRecentProject.fromJson(Map<String, dynamic> json) {
    return PmRecentProject(
      projectId: (json['project_id'] as num?)?.toInt() ?? 0,
      name: (json['project_name'] as String?) ?? 'Untitled',
      location: (json['location'] as String?) ?? 'N/A',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      tasksCompleted: (json['tasks_completed'] as num?)?.toInt() ?? 0,
      totalTasks: (json['total_tasks'] as num?)?.toInt() ?? 0,
      image: json['project_image'] as String?,
      budget: json['budget']?.toString(),
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

class PmActivityMonthPoint {
  final int month;
  final int completed;

  const PmActivityMonthPoint({required this.month, required this.completed});

  factory PmActivityMonthPoint.fromJson(Map<String, dynamic> json) {
    return PmActivityMonthPoint(
      month: (json['month'] as num?)?.toInt() ?? 1,
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

class PmAuditTrailEntry {
  final String userName;
  final String userRole;
  final String action;
  final DateTime? timestamp;
  final String category;
  final String affectedRecord;
  final String oldValue;
  final String newValue;
  final String module;
  final String statusResult;

  const PmAuditTrailEntry({
    required this.userName,
    required this.userRole,
    required this.action,
    required this.timestamp,
    required this.category,
    required this.affectedRecord,
    required this.oldValue,
    required this.newValue,
    required this.module,
    required this.statusResult,
  });

  factory PmAuditTrailEntry.fromJson(Map<String, dynamic> json) {
    String _readString(String key, {String fallback = '—'}) {
      final raw = json[key];
      if (raw is String) {
        final trimmed = raw.trim();
        return trimmed.isEmpty ? fallback : trimmed;
      }
      return fallback;
    }

    return PmAuditTrailEntry(
      userName: _readString('user_name', fallback: 'Unknown'),
      userRole: _readString('user_role', fallback: 'User'),
      action: (json['action'] as String?) ?? '',
      timestamp: DateTime.tryParse((json['timestamp'] as String?) ?? ''),
      category: _readString('category', fallback: 'Event'),
      affectedRecord: _readString('affected_record'),
      oldValue: _readString('old_value'),
      newValue: _readString('new_value'),
      module: _readString('module', fallback: 'General'),
      statusResult: _readString('status_result', fallback: 'Success'),
    );
  }
}

class PmDashboardService {
  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _cacheTtl = Duration(seconds: 45);

  static final Map<int, _PmDashboardCacheEntry> _cacheByUser = {};
  static final Map<int, Future<PmDashboardSummary>> _inFlightByUser = {};

  Future<PmDashboardSummary> fetchSummary({
    required int userId,
    bool preferCache = true,
  }) async {
    if (preferCache) {
      final cached = _cacheByUser[userId];
      if (cached != null && DateTime.now().difference(cached.cachedAt) <= _cacheTtl) {
        return cached.summary;
      }
    }

    final inFlight = _inFlightByUser[userId];
    if (inFlight != null) {
      return inFlight;
    }

    final requestFuture = _fetchSummaryFromApi(userId: userId);
    _inFlightByUser[userId] = requestFuture;

    try {
      final summary = await requestFuture;
      _cacheByUser[userId] = _PmDashboardCacheEntry(
        summary: summary,
        cachedAt: DateTime.now(),
      );
      return summary;
    } finally {
      if (identical(_inFlightByUser[userId], requestFuture)) {
        _inFlightByUser.remove(userId);
      }
    }
  }

  Future<PmDashboardSummary> _fetchSummaryFromApi({required int userId}) async {
    final uri = AppConfig.apiUri('pm/dashboard/?user_id=$userId');

    final response = await http.get(uri).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to load dashboard: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Dashboard request failed');
    }

    final summary = PmDashboardSummary.fromJson(decoded);
    final workerCounts = await _fetchWorkerManagementCounts(userId: userId);

    return PmDashboardSummary(
      totalProjects: summary.totalProjects,
      recentProjects: summary.recentProjects,
      totalTasks: summary.totalTasks,
      completedTasks: summary.completedTasks,
      inProgressTasks: summary.inProgressTasks,
      pendingTasks: summary.pendingTasks,
      assignedTasks: summary.assignedTasks,
      completionRate: summary.completionRate,
      activitySeries: summary.activitySeries,
      monthlySeries: summary.monthlySeries,
      supervisorsCount: workerCounts.supervisorsCount,
      fieldWorkersTotal: workerCounts.fieldWorkersTotal,
      fieldWorkersByRole: workerCounts.fieldWorkersByRole,
      tasksToday: summary.tasksToday,
      notificationsCount: summary.notificationsCount,
      notificationsItems: summary.notificationsItems,
    );
  }

  Future<List<PmAuditTrailEntry>> fetchAuditTrail({
    required int userId,
    int limit = 100,
  }) async {
    final uri = AppConfig.apiUri(
      'pm/audit-trail/?user_id=$userId&limit=$limit',
    );

    final response = await http.get(uri).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to load audit trail: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Audit trail request failed');
    }

    final itemsRaw = (decoded['items'] as List<dynamic>? ?? const []);
    return itemsRaw
        .whereType<Map<String, dynamic>>()
        .map(PmAuditTrailEntry.fromJson)
        .toList(growable: false);
  }

  Future<_PmWorkerCounts> _fetchWorkerManagementCounts({
    required int userId,
  }) async {
    final supervisorsUri = AppConfig.apiUri('supervisors/?user_id=$userId');
    final fieldWorkersUri = AppConfig.apiUri('field-workers/?user_id=$userId');

    final responses = await Future.wait<http.Response>([
      http.get(supervisorsUri).timeout(_timeout),
      http.get(fieldWorkersUri).timeout(_timeout),
    ]);

    final supervisorsResponse = responses[0];
    final fieldWorkersResponse = responses[1];

    final supervisors = supervisorsResponse.statusCode == 200
        ? _extractListPayload(jsonDecode(supervisorsResponse.body))
        : const <Map<String, dynamic>>[];

    final fieldWorkers = fieldWorkersResponse.statusCode == 200
        ? _extractListPayload(jsonDecode(fieldWorkersResponse.body))
        : const <Map<String, dynamic>>[];

    final byRole = <String, int>{};
    for (final worker in fieldWorkers) {
      final role = (worker['role'] ?? 'Unknown').toString().trim();
      if (role.isEmpty) continue;
      byRole.update(role, (value) => value + 1, ifAbsent: () => 1);
    }

    return _PmWorkerCounts(
      supervisorsCount: supervisors.length,
      fieldWorkersTotal: fieldWorkers.length,
      fieldWorkersByRole: byRole,
    );
  }

  List<Map<String, dynamic>> _extractListPayload(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    if (decoded is Map<String, dynamic>) {
      final results = decoded['results'];
      if (results is List) {
        return results
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    }

    return const <Map<String, dynamic>>[];
  }
}

class _PmWorkerCounts {
  final int supervisorsCount;
  final int fieldWorkersTotal;
  final Map<String, int> fieldWorkersByRole;

  const _PmWorkerCounts({
    required this.supervisorsCount,
    required this.fieldWorkersTotal,
    required this.fieldWorkersByRole,
  });
}

class _PmDashboardCacheEntry {
  final PmDashboardSummary summary;
  final DateTime cachedAt;

  const _PmDashboardCacheEntry({
    required this.summary,
    required this.cachedAt,
  });
}
