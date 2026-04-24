import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../services/app_config.dart';
import '../services/auth_service.dart';
import 'phase_subtask_models.dart';
import 'subtask_manage.dart';

/// Marks the inbox row read and opens PM Inventory (e.g. supervisor returned an item).
Future<void> openPmInboxInventory(
  BuildContext context, {
  required int notificationId,
  bool markRead = true,
}) async {
  final uid = AuthService().currentUser?['user_id'];
  final pm = uid is int ? uid : int.tryParse(uid?.toString() ?? '');

  if (markRead && pm != null) {
    try {
      await http.post(
        AppConfig.apiUri('pm/inbox/$notificationId/read/?user_id=$pm'),
        headers: const {'Content-Type': 'application/json'},
        body: '{}',
      );
    } catch (_) {
      // still navigate
    }
  }

  if (!context.mounted) return;
  context.go('/inventory');
}

/// Marks the inbox row read and opens PM Reports (supervisor submitted a report).
Future<void> openPmInboxReports(
  BuildContext context, {
  required int notificationId,
  bool markRead = true,
}) async {
  final uid = AuthService().currentUser?['user_id'];
  final pm = uid is int ? uid : int.tryParse(uid?.toString() ?? '');

  if (markRead && pm != null) {
    try {
      await http.post(
        AppConfig.apiUri('pm/inbox/$notificationId/read/?user_id=$pm'),
        headers: const {'Content-Type': 'application/json'},
        body: '{}',
      );
    } catch (_) {
      // still navigate
    }
  }

  if (!context.mounted) return;
  context.go('/reports');
}

/// Opens the phase subtask list and highlights the subtask (from PM in-app notification).
Future<void> openPmInboxSubtask(
  BuildContext context, {
  required int notificationId,
  required int subtaskId,
  int? phaseId,
  bool markRead = true,
}) async {
  final uid = AuthService().currentUser?['user_id'];
  final pm = uid is int ? uid : int.tryParse(uid?.toString() ?? '');

  if (markRead && pm != null) {
    try {
      await http.post(
        AppConfig.apiUri('pm/inbox/$notificationId/read/?user_id=$pm'),
        headers: const {'Content-Type': 'application/json'},
        body: '{}',
      );
    } catch (_) {
      // still navigate
    }
  }

  if (!context.mounted) return;

  var resolvedPhaseId = phaseId;
  if (resolvedPhaseId == null) {
    try {
      final r = await http.get(AppConfig.apiUri('subtasks/$subtaskId/'));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is Map<String, dynamic>) {
          final ph = decoded['phase'];
          if (ph is int) {
            resolvedPhaseId = ph;
          } else if (ph is Map && ph['phase_id'] != null) {
            resolvedPhaseId = (ph['phase_id'] as num?)?.toInt();
          }
        }
      }
    } catch (_) {
      // fall through
    }
  }

  if (resolvedPhaseId == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this subtask (phase not found).'),
        ),
      );
    }
    return;
  }

  final phaseRes = await http.get(
    AppConfig.apiUri('phases/$resolvedPhaseId/'),
  );
  if (phaseRes.statusCode != 200) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load phase (${phaseRes.statusCode})'),
        ),
      );
    }
    return;
  }

  final phase = Phase.fromJson(
    jsonDecode(phaseRes.body) as Map<String, dynamic>,
  );

  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (ctx) => SubtaskManagePage(
        phase: phase,
        viewOnly: false,
        focusSubtaskId: subtaskId,
      ),
    ),
  );
}
