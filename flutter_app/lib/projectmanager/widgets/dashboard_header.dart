import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../services/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/pm_dashboard_service.dart';
import '../pm_subtask_notification_nav.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key, this.title = 'Dashboard'});

  final String title;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive breakpoints
    final isExtraSmallPhone = screenWidth <= 320;
    final isSmallPhone = screenWidth < 375;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    final horizontalPadding = isExtraSmallPhone
        ? 8.0
        : isSmallPhone
        ? 12.0
        : isMobile
        ? 16.0
        : isTablet
        ? 20.0
        : 24.0;
    final verticalPadding = isExtraSmallPhone
        ? 8.0
        : isSmallPhone
        ? 10.0
        : isMobile
        ? 12.0
        : 16.0;
    final titleSize = isExtraSmallPhone
        ? 14.0
        : isSmallPhone
        ? 16.0
        : isMobile
        ? 18.0
        : isTablet
        ? 22.0
        : 24.0;
    final spacing = isExtraSmallPhone
        ? 4.0
        : isSmallPhone
        ? 6.0
        : isMobile
        ? 8.0
        : 16.0;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                color: const Color(0xFF0C1935),
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            flex: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Notification bell
                const _NotificationMenu(),
                SizedBox(width: spacing),
                // User profile
                const _ProfileMenu(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MergedPreview {
  const _MergedPreview({required this.taskBanners});

  final List<_UiNotification> taskBanners;
}

class _NotificationMenu extends StatefulWidget {
  const _NotificationMenu();

  @override
  State<_NotificationMenu> createState() => _NotificationMenuState();
}

class _NotificationMenuState extends State<_NotificationMenu> {
  static const Duration _cacheTtl = Duration(seconds: 45);
  static const int _kViewAllValue = 1;
  static const int _kRevertValueBase = 10000;
  static const int _kInboxValueBase = 40000;
  static int? _cachedUserId;
  static DateTime? _cachedAt;
  static List<_UiNotification> _cachedItems = const [];
  static List<Map<String, dynamic>> _cachedReverts = const [];
  static List<PmInboxItem> _cachedInbox = const [];
  static int _cachedBadgeCount = 0;
  static Future<PmDashboardSummary>? _inFlightSummary;
  static int? _inFlightUserId;

  final PmDashboardService _dashboardService = PmDashboardService();

  bool _loading = true;
  String? _error;
  List<_UiNotification> _items = const [];
  List<Map<String, dynamic>> _revertItems = const [];
  List<PmInboxItem> _inboxItems = const [];
  int _badgeCount = 0;

  static void _invalidateCache() {
    _cachedAt = null;
  }

  /// Exposed for other PM screens (e.g. after marking inbox read on Notifications page).
  static void invalidateSharedCache() {
    _invalidateCache();
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    Future<PmDashboardSummary>? activeSummaryFuture;
    try {
      final authService = AuthService();
      final userIdRaw = authService.currentUser?['user_id'];
      final userId = userIdRaw is int
          ? userIdRaw
          : int.tryParse(userIdRaw?.toString() ?? '');

      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _items = const [];
          _revertItems = const [];
          _inboxItems = const [];
          _badgeCount = 0;
          _error = null;
          _loading = false;
        });
        return;
      }

      final now = DateTime.now();
      final hasFreshCache =
          _cachedUserId == userId &&
          _cachedAt != null &&
          now.difference(_cachedAt!) <= _cacheTtl;

      if (hasFreshCache) {
        if (!mounted) return;
        setState(() {
          _items = _cachedItems;
          _revertItems = _cachedReverts;
          _inboxItems = _cachedInbox;
          _badgeCount = _cachedBadgeCount;
          _error = null;
          _loading = false;
        });
        return;
      }

      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }

      Future<PmDashboardSummary> summaryFuture;
      if (_inFlightSummary != null && _inFlightUserId == userId) {
        summaryFuture = _inFlightSummary!;
      } else {
        final created = _dashboardService.fetchSummary(userId: userId);
        _inFlightSummary = created;
        _inFlightUserId = userId;
        summaryFuture = created;
      }
      activeSummaryFuture = summaryFuture;

      final summary = await summaryFuture;
      final revRes = await http.get(
        AppConfig.apiUri(
          'subtask-completion-revert-requests/?user_id=$userId&status=pending',
        ),
      );
      final reverts = _parseRevertList(revRes);
      final derived = _mergePreviewRows(summary, reverts);
      final inbox = summary.inboxItems;

      _cachedUserId = userId;
      _cachedAt = DateTime.now();
      _cachedItems = derived.taskBanners;
      _cachedReverts = reverts;
      _cachedInbox = inbox;
      _cachedBadgeCount = _combinedBadgeCount(
        summary.notificationsCount,
        reverts.length,
        summary.inboxUnreadCount,
      );

      if (!mounted) return;
      setState(() {
        _items = derived.taskBanners;
        _revertItems = reverts;
        _inboxItems = inbox;
        _badgeCount = _cachedBadgeCount;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _revertItems = const [];
        _inboxItems = const [];
        _badgeCount = 0;
        _error = e.toString();
        _loading = false;
      });
    } finally {
      if (activeSummaryFuture != null &&
          identical(_inFlightSummary, activeSummaryFuture)) {
        _inFlightSummary = null;
        _inFlightUserId = null;
      }
    }
  }

  List<_UiNotification> _deriveFromSummary(PmDashboardSummary summary) {
    final items = <_UiNotification>[];
    for (final task in summary.notificationsItems) {
      final time = _relativeTime(task.updatedAt);
      final status = task.status.toLowerCase();
      final color = switch (status) {
        'in_progress' || 'in progress' => const Color(0xFF2563EB),
        'assigned' => const Color(0xFFFF7A18),
        'pending' => const Color(0xFF6B7280),
        _ => const Color(0xFF6B7280),
      };

      final projectPrefix = (task.projectName ?? '').trim();
      final title = projectPrefix.isEmpty
          ? task.title
          : '$projectPrefix: ${task.title}';

      items.add(_UiNotification(title: title, time: time, color: color));
    }

    return items;
  }

  _MergedPreview _mergePreviewRows(
    PmDashboardSummary summary,
    List<Map<String, dynamic>> reverts,
  ) {
    final allTasks = _deriveFromSummary(summary);
    final nRev = min(3, reverts.length);
    var room = 3 - nRev;
    if (room < 0) room = 0;
    final nIn = min(room, summary.inboxItems.length);
    room -= nIn;
    if (room < 0) room = 0;
    final taskBanners = allTasks.take(room).toList(growable: false);
    return _MergedPreview(taskBanners: taskBanners);
  }

  List<Map<String, dynamic>> _parseRevertList(http.Response revRes) {
    if (revRes.statusCode != 200) return const [];
    try {
      final body = jsonDecode(revRes.body);
      if (body is List) {
        return body
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (body is Map && body['results'] is List) {
        return (body['results'] as List<dynamic>)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {
      // ignore
    }
    return const [];
  }

  int _combinedBadgeCount(
    int openTaskCount,
    int pendingReverts,
    int inboxUnread,
  ) {
    return openTaskCount + pendingReverts + inboxUnread;
  }

  int? _pmUserId() {
    final raw = AuthService().currentUser?['user_id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<void> _openRevertApprovalDialog(
    Map<String, dynamic> row,
  ) async {
    if (!mounted) return;
    final rootMessenger = ScaffoldMessenger.of(context);
    final ridRaw = row['revert_request_id'];
    final revertId = ridRaw is int
        ? ridRaw
        : int.tryParse(ridRaw?.toString() ?? '');
    if (revertId == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _PmRevertRequestDialog(
          data: row,
          onApprove: () async {
            final uid = _pmUserId();
            if (uid == null) return false;
            final r = await http.post(
              AppConfig.apiUri(
                'subtask-completion-revert-requests/$revertId/approve/?user_id=$uid',
              ),
              headers: const {'Content-Type': 'application/json'},
              body: '{}',
            );
            if (r.statusCode == 200) {
              if (mounted) {
                _invalidateCache();
                await _refresh();
                rootMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Subtask reverted to not complete.'),
                    backgroundColor: Color(0xFF059669),
                  ),
                );
              }
              return true;
            }
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(
                  content: Text('Approve failed (${r.statusCode})'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return false;
          },
          onDeny: () async {
            final uid = _pmUserId();
            if (uid == null) return false;
            final r = await http.post(
              AppConfig.apiUri(
                'subtask-completion-revert-requests/$revertId/deny/?user_id=$uid',
              ),
              headers: const {'Content-Type': 'application/json'},
              body: '{}',
            );
            if (r.statusCode == 200) {
              if (mounted) {
                _invalidateCache();
                await _refresh();
                rootMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Request dismissed. Subtask stays complete.'),
                  ),
                );
              }
              return true;
            }
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(
                  content: Text('Action failed (${r.statusCode})'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return false;
          },
        );
      },
    );
  }

  void _onMenuItemSelected(int value) {
    if (value == _kViewAllValue) {
      context.go('/notifications');
      return;
    }
    if (value >= _kInboxValueBase) {
      final nid = value - _kInboxValueBase;
      for (final e in _inboxItems) {
        if (e.notificationId == nid) {
          if (!e.read) {
            setState(() {
              _badgeCount = (_badgeCount - 1).clamp(0, 9999);
              _inboxItems = _inboxItems
                  .map(
                    (row) => row.notificationId == e.notificationId
                        ? PmInboxItem(
                            notificationId: row.notificationId,
                            kind: row.kind,
                            title: row.title,
                            body: row.body,
                            read: true,
                            createdAt: row.createdAt,
                            subtaskId: row.subtaskId,
                            projectId: row.projectId,
                            phaseId: row.phaseId,
                            supervisorName: row.supervisorName,
                            target: row.target,
                          )
                        : row,
                  )
                  .toList(growable: false);
            });
          }
          final goInventory = e.target == 'inventory' ||
              e.kind == 'supervisor_inventory_returned';
          if (goInventory) {
            unawaited(
              openPmInboxInventory(
                context,
                notificationId: e.notificationId,
              ),
            );
            if (mounted) {
              _invalidateCache();
              unawaited(_refresh());
            }
            return;
          }
          final goReports = e.target == 'reports' ||
              e.kind == 'supervisor_report_submitted';
          if (goReports) {
            unawaited(
              openPmInboxReports(
                context,
                notificationId: e.notificationId,
              ),
            );
            if (mounted) {
              _invalidateCache();
              unawaited(_refresh());
            }
            return;
          }
          final sid = e.subtaskId;
          if (sid == null) return;
          openPmInboxSubtask(
            context,
            notificationId: e.notificationId,
            subtaskId: sid,
            phaseId: e.phaseId,
          );
          if (mounted) {
            _invalidateCache();
            unawaited(_refresh());
          }
          return;
        }
      }
      return;
    }
    if (value >= _kRevertValueBase) {
      final rid = value - _kRevertValueBase;
      for (final e in _revertItems) {
        final id = e['revert_request_id'];
        final n = id is int
            ? id
            : int.tryParse('${id ?? ''}');
        if (n == rid) {
          _openRevertApprovalDialog(e);
          return;
        }
      }
    }
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
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

  @override
  Widget build(BuildContext context) {
    final count = _badgeCount;
    final nRev = min(3, _revertItems.length);
    var room = 3 - nRev;
    if (room < 0) room = 0;
    final nIn = min(room, _inboxItems.length);
    room -= nIn;
    if (room < 0) room = 0;
    final nTask = min(room, _items.length);
    final hasListBody =
        _error == null && !_loading && (nRev > 0 || nIn > 0 || nTask > 0);

    return PopupMenuButton<int>(
      color: Colors.white,
      tooltip: 'Notifications',
      offset: const Offset(0, 12),
      constraints: const BoxConstraints(minWidth: 300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onOpened: _refresh,
      onSelected: _onMenuItemSelected,
      itemBuilder: (context) {
        final subtitle = _loading
            ? 'Loading…'
            : _error != null
            ? 'Failed to load'
            : count == 0
            ? 'No updates'
            : '$count item${count == 1 ? '' : 's'} need attention';

        final entries = <PopupMenuEntry<int>>[
          PopupMenuItem(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0C1935),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ];

        if (_loading) {
          entries.add(
            const PopupMenuItem(
              enabled: false,
              child: Text(
                'Loading…',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ),
          );
        } else if (_error != null) {
          entries.add(
            const PopupMenuItem(
              enabled: false,
              child: Text(
                'Unable to load notifications.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ),
          );
        } else if (!hasListBody) {
          entries.add(
            const PopupMenuItem(
              enabled: false,
              child: Text(
                'No notifications.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ),
          );
        } else {
          for (var i = 0; i < nRev; i++) {
            final r = _revertItems[i];
            final idRaw = r['revert_request_id'];
            final rid = idRaw is int
                ? idRaw
                : int.tryParse(idRaw?.toString() ?? '');
            if (rid == null) continue;
            final st = (r['subtask_title'] ?? 'Subtask').toString();
            final project = (r['project_name'] ?? '').toString();
            final line = project.isNotEmpty ? '$project · $st' : st;
            entries.add(
              PopupMenuItem<int>(
                value: _kRevertValueBase + rid,
                child: _RevertBellTile(
                  line: 'Uncheck request: $line',
                  time: _relativeTime(_parseDate(r['created_at'])),
                ),
              ),
            );
          }
          for (var j = 0; j < nIn; j++) {
            final it = _inboxItems[j];
            final t = (it.title).trim();
            final line = t.isNotEmpty
                ? t
                : 'Supervisor subtask update';
            entries.add(
              PopupMenuItem<int>(
                value: _kInboxValueBase + it.notificationId,
                child: _InboxBellTile(
                  line: line,
                  body: (it.body).trim(),
                  time: _relativeTime(it.createdAt),
                  unread: !it.read,
                ),
              ),
            );
          }
          if (nTask > 0) {
            final taskRows = _items.take(nTask).toList(growable: false);
            entries.add(
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final n in taskRows) ...[
                      _NotificationTile(
                        title: n.title,
                        time: n.time,
                        color: n.color,
                      ),
                      if (n != taskRows.last) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            );
          }
        }

        entries.addAll([
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: _kViewAllValue,
            child: Row(
              children: [
                Icon(Icons.open_in_new, size: 16, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Text(
                  'View all notifications',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
        ]);
        return entries;
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_outlined, size: 24, color: Colors.grey[600]),
          if (!_loading && _error == null && count > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UiNotification {
  final String title;
  final String time;
  final Color color;

  const _UiNotification({
    required this.title,
    required this.time,
    required this.color,
  });
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.title,
    required this.time,
    required this.color,
  });

  final String title;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0C1935),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RevertBellTile extends StatelessWidget {
  const _RevertBellTile({required this.line, required this.time});

  final String line;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 4),
          decoration: const BoxDecoration(
            color: Color(0xFFFF7A18),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0C1935),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time.isNotEmpty
                    ? '$time · Tap to review'
                    : 'Tap to approve or dismiss',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, size: 18, color: Color(0xFFEA580C)),
      ],
    );
  }
}

class _InboxBellTile extends StatelessWidget {
  const _InboxBellTile({
    required this.line,
    required this.body,
    required this.time,
    required this.unread,
  });

  final String line;
  final String body;
  final String time;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: unread
                ? const Color(0xFF2563EB)
                : const Color(0xFF94A3B8),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0C1935),
                ),
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4B5563),
                    height: 1.25,
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                time.isNotEmpty
                    ? '$time · Open subtask'
                    : 'Tap to open subtask',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, size: 18, color: Color(0xFF2563EB)),
      ],
    );
  }
}

class _PmRevertRequestDialog extends StatefulWidget {
  const _PmRevertRequestDialog({
    required this.data,
    required this.onApprove,
    required this.onDeny,
  });

  final Map<String, dynamic> data;
  final Future<bool> Function() onApprove;
  final Future<bool> Function() onDeny;

  @override
  State<_PmRevertRequestDialog> createState() => _PmRevertRequestDialogState();
}

class _PmRevertRequestDialogState extends State<_PmRevertRequestDialog> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final title = (widget.data['subtask_title'] ?? 'Subtask').toString();
    final project = (widget.data['project_name'] ?? '').toString();
    final phase = (widget.data['phase_name'] ?? '').toString();
    final sup = (widget.data['supervisor_name'] ?? '').toString();
    final reason = (widget.data['reason'] ?? '').toString();
    final headline = project.isNotEmpty ? '$project · $title' : title;

    return AlertDialog(
      title: const Text('Supervisor asked to uncheck a subtask'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              headline,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF0C1935),
              ),
            ),
            if (phase.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Phase: $phase',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
            if (sup.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Supervisor: $sup',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Reason',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reason,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  final ok = await widget.onDeny();
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() => _busy = false);
                  }
                },
          child: const Text('Dismiss'),
        ),
        ElevatedButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  final ok = await widget.onApprove();
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() => _busy = false);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEA580C),
            foregroundColor: Colors.white,
          ),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Approve uncheck'),
        ),
      ],
    );
  }
}

enum _ProfileAction { settings, notifications, logout }

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu();

  String _displayName(Map<String, dynamic>? user) {
    if (user == null) return 'Project Manager';

    // Try first and last name
    final first = (user['first_name'] as String?)?.trim() ?? '';
    final last = (user['last_name'] as String?)?.trim() ?? '';
    final full = ('$first $last').trim();
    if (full.isNotEmpty) return full;

    // Try full_name field
    final fullName = (user['full_name'] as String?)?.trim() ?? '';
    if (fullName.isNotEmpty) return fullName;

    // Try name field
    final name = (user['name'] as String?)?.trim() ?? '';
    if (name.isNotEmpty) return name;

    // Try email as fallback
    final email = (user['email'] as String?)?.trim() ?? '';
    if (email.isNotEmpty) return email;

    // Try username
    final username = (user['username'] as String?)?.trim() ?? '';
    if (username.isNotEmpty) return username;

    return 'Project Manager';
  }

  String _displayRole(Map<String, dynamic>? user) {
    if (user == null) return 'Project Manager';

    final role = (user['role'] as String?)?.trim();
    if (role != null && role.isNotEmpty) return role;

    final type = (user['type'] as String?)?.trim();
    if (type != null && type.isNotEmpty) return type;

    return 'Project Manager';
  }

  void _handleAction(BuildContext context, _ProfileAction action) {
    switch (action) {
      case _ProfileAction.settings:
        context.go('/settings');
        break;
      case _ProfileAction.notifications:
        context.go('/notifications');
        break;
      case _ProfileAction.logout:
        _performLogout(context);
        break;
    }
  }

  Future<void> _performLogout(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Call logout on auth service
      final authService = AuthService();
      await authService.logout();

      // Close the loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Navigate to login page using GoRouter
      if (context.mounted) {
        context.go('/login');
      }
    } catch (e) {
      // Close the loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return AnimatedBuilder(
      animation: authService,
      builder: (context, _) {
        final user = authService.currentUser;
        final name = _displayName(user);
        final role = _displayRole(user);

        return PopupMenuButton<_ProfileAction>(
          color: Colors.white,
          tooltip: 'Profile menu',
          offset: const Offset(0, 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (action) => _handleAction(context, action),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _ProfileAction.settings,
              child: _MenuRow(icon: Icons.settings_outlined, label: 'Settings'),
            ),
            PopupMenuItem(
              value: _ProfileAction.notifications,
              child: _MenuRow(
                icon: Icons.notifications_none_outlined,
                label: 'Notifications',
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: _ProfileAction.logout,
              child: _MenuRow(
                icon: Icons.logout,
                label: 'Logout',
                isDestructive: true,
              ),
            ),
          ],
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFF0C1935),
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0C1935),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    role,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Icon(
                Icons.keyboard_arrow_down,
                color: Colors.grey[600],
                size: 20,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? const Color(0xFFF43F5E)
        : const Color(0xFF0C1935);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Call after changing inbox read state from outside the header (e.g. [NotificationPage]).
void invalidatePmNotificationBellCache() {
  _NotificationMenuState.invalidateSharedCache();
}
