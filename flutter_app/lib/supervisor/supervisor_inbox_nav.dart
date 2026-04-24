import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../services/app_config.dart';
import '../services/auth_service.dart';

/// Coerces JSON inbox id fields to [int?].
int? parseInboxId(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

int? supervisorIdFromAuth() {
  final u = AuthService().currentUser;
  if (u == null) return null;
  final raw = u['supervisor_id'] ?? u['user_id'];
  if (raw is int) return raw;
  return int.tryParse(raw?.toString() ?? '');
}

/// Marks one supervisor inbox row as read (best-effort).
Future<void> markSupervisorInboxRead(int notificationId) async {
  final sid = supervisorIdFromAuth();
  if (sid == null) return;
  try {
    await http.post(
      AppConfig.apiUri(
        'supervisor/inbox/$notificationId/read/?supervisor_id=$sid',
      ),
      headers: const {'Content-Type': 'application/json'},
      body: '{}',
    );
  } catch (_) {}
}

String _inboxQuery(Map<String, int?> parts) {
  final pairs = <String>[];
  for (final e in parts.entries) {
    final v = e.value;
    if (v == null) continue;
    pairs.add('${e.key}=$v');
  }
  if (pairs.isEmpty) return '';
  return '?${pairs.join('&')}';
}

/// After marking read, navigates to the screen related to the PM action, with
/// query parameters so the supervisor UI can deep-link (project, phase, item).
Future<void> openSupervisorInboxNotification(
  BuildContext context, {
  required int notificationId,
  String? target,
  int? projectId,
  int? phaseId,
  int? subtaskId,
  int? planId,
  int? itemId,
  int? unitId,
  bool markRead = true,
}) async {
  if (markRead) {
    await markSupervisorInboxRead(notificationId);
  }
  if (!context.mounted) return;
  final t = (target ?? '').toLowerCase();
  if (t == 'inventory') {
    final q = _inboxQuery({
      'project_id': projectId,
      'item_id': itemId,
      'unit_id': unitId,
    });
    context.go('/supervisor/inventory$q');
    return;
  }
  final q = _inboxQuery({
    'project_id': projectId,
    'phase_id': phaseId,
    'subtask_id': subtaskId,
    'plan_id': planId,
  });
  context.go('/supervisor/projects$q');
}
