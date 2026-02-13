import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'auth_service.dart';

class ClientProjectCardData {
  const ClientProjectCardData({
    required this.projectId,
    required this.title,
    required this.location,
    required this.progress,
    required this.startDate,
    required this.endDate,
    required this.tasksCompleted,
    required this.totalTasks,
    required this.imageUrl,
  });

  final int projectId;
  final String title;
  final String location;
  final double progress;
  final String startDate;
  final String endDate;
  final int tasksCompleted;
  final int totalTasks;
  final String imageUrl;
}

class ClientNotificationItem {
  const ClientNotificationItem({required this.title, required this.time});

  final String title;
  final String time;
}

class ClientNotificationsPayload {
  const ClientNotificationsPayload({required this.count, required this.items});

  final int count;
  final List<ClientNotificationItem> items;
}

class ClientDashboardService {
  static const int _notificationPreviewLimit = 3;
  static const int _notificationListLimit = 20;

  Future<List<ClientProjectCardData>> fetchClientProjects() async {
    final auth = AuthService();
    final user = auth.currentUser;

    final clientIdRaw = user?['client_id'];
    final projectIdRaw = user?['project_id'];

    final clientId = clientIdRaw is int
        ? clientIdRaw
        : int.tryParse(clientIdRaw?.toString() ?? '');
    final singleProjectId = projectIdRaw is int
        ? projectIdRaw
        : int.tryParse(projectIdRaw?.toString() ?? '');

    List<Map<String, dynamic>> projects;

    if (clientId != null) {
      final response = await http.get(
        AppConfig.apiUri('projects/?client_id=$clientId'),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to load projects');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) throw Exception('Unexpected projects response');
      projects = decoded.whereType<Map<String, dynamic>>().toList();
    } else if (singleProjectId != null) {
      final response = await http.get(
        AppConfig.apiUri('projects/$singleProjectId/'),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to load project');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected project response');
      }
      projects = [decoded];
    } else {
      return const [];
    }

    final results = await Future.wait(
      projects.map((p) async {
        final projectId = (p['project_id'] as int?) ?? 0;
        final name = (p['project_name'] as String?) ?? 'Untitled project';
        final image = (p['project_image'] as String?) ?? '';

        final location = _projectLocation(p);

        final startDate = (p['start_date'] as String?) ?? '';
        final endDate = (p['end_date'] as String?) ?? '';

        final taskStats = await _fetchTaskStats(projectId);
        final total = taskStats.total;
        final completed = taskStats.completed;
        final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);

        return ClientProjectCardData(
          projectId: projectId,
          title: name,
          location: location,
          progress: progress,
          startDate: _formatYmd(startDate),
          endDate: _formatYmd(endDate),
          tasksCompleted: completed,
          totalTasks: total,
          imageUrl: image,
        );
      }).toList(),
    );

    return results;
  }

  Future<ClientNotificationsPayload> fetchClientNotifications({
    int previewLimit = _notificationPreviewLimit,
  }) async {
    final projects = await fetchClientProjects();
    if (projects.isEmpty) {
      return const ClientNotificationsPayload(count: 0, items: []);
    }

    final openTasks = <Map<String, dynamic>>[];
    final projectNameById = {for (final p in projects) p.projectId: p.title};

    for (final p in projects) {
      final response = await http.get(
        AppConfig.apiUri('subtasks/?project_id=${p.projectId}'),
      );
      if (response.statusCode != 200) {
        continue;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) continue;

      for (final raw in decoded.whereType<Map<String, dynamic>>()) {
        final status = (raw['status']?.toString().toLowerCase() ?? '');
        if (status == 'completed') continue;
        raw['__project_id'] = p.projectId;
        openTasks.add(raw);
      }
    }

    openTasks.sort((a, b) {
      final aUpdated = (a['updated_at'] as String?) ?? '';
      final bUpdated = (b['updated_at'] as String?) ?? '';
      return bUpdated.compareTo(aUpdated);
    });

    final items = <ClientNotificationItem>[];
    for (final t in openTasks.take(_notificationListLimit)) {
      final projectId = (t['__project_id'] as int?) ?? 0;
      final projectName = projectNameById[projectId] ?? 'Project';
      final title = (t['title'] as String?) ?? 'Task update';
      final updatedAt = DateTime.tryParse((t['updated_at'] as String?) ?? '');

      items.add(
        ClientNotificationItem(
          title: '$projectName: $title',
          time: _relativeTime(updatedAt),
        ),
      );
    }

    return ClientNotificationsPayload(
      count: openTasks.length,
      items: items.take(previewLimit).toList(growable: false),
    );
  }

  Future<_TaskStats> _fetchTaskStats(int projectId) async {
    if (projectId == 0) return const _TaskStats(total: 0, completed: 0);

    final response = await http.get(
      AppConfig.apiUri('subtasks/?project_id=$projectId'),
    );
    if (response.statusCode != 200) {
      return const _TaskStats(total: 0, completed: 0);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const _TaskStats(total: 0, completed: 0);

    final tasks = decoded.whereType<Map<String, dynamic>>().toList();
    final total = tasks.length;
    final completed = tasks
        .where(
          (t) => (t['status']?.toString().toLowerCase() ?? '') == 'completed',
        )
        .length;

    return _TaskStats(total: total, completed: completed);
  }

  String _projectLocation(Map<String, dynamic> p) {
    final street = (p['street'] as String?)?.trim();
    final barangay = (p['barangay_name'] as String?)?.trim();
    final city = (p['city_name'] as String?)?.trim();
    final province = (p['province_name'] as String?)?.trim();

    final parts = <String>[];
    if (street != null && street.isNotEmpty) parts.add(street);
    if (barangay != null && barangay.isNotEmpty) parts.add(barangay);
    if (city != null && city.isNotEmpty) parts.add(city);
    if (province != null && province.isNotEmpty) parts.add(province);

    return parts.isEmpty ? '—' : parts.join(', ');
  }

  String _formatYmd(String raw) {
    // Backend returns ISO `YYYY-MM-DD`. Keep it human-readable and stable.
    return raw;
  }

  String _relativeTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }
}

class _TaskStats {
  final int total;
  final int completed;

  const _TaskStats({required this.total, required this.completed});
}
