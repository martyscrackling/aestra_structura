import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'pm_subtask_notification_nav.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/responsive_page_layout.dart';

import '../services/app_config.dart';
import '../services/auth_service.dart';
import '../services/pm_dashboard_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final PmDashboardService _dashboardService = PmDashboardService();

  bool _loading = true;
  String? _error;
  List<NotificationItem> _notifications = const [];
  List<PmInboxItem> _inboxItems = const [];
  List<Map<String, dynamic>> _revertRequests = const [];
  bool _revertActionBusy = false;
  bool _markInboxReadBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_loading || _error != null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final authService = AuthService();
      final userIdRaw = authService.currentUser?['user_id'];
      final userId = userIdRaw is int
          ? userIdRaw
          : int.tryParse(userIdRaw?.toString() ?? '');

      if (userId == null) {
        setState(() {
          _notifications = const [];
          _inboxItems = const [];
          _revertRequests = const [];
          _loading = false;
        });
        return;
      }

      final summary = await _dashboardService.fetchSummary(
        userId: userId,
        preferCache: false,
      );
      final items = summary.notificationsItems.map(_toNotification).toList();
      final inbox = List<PmInboxItem>.from(summary.inboxItems);

      List<Map<String, dynamic>> revs = const [];
      try {
        final revRes = await http.get(
          AppConfig.apiUri(
            'subtask-completion-revert-requests/?user_id=$userId&status=pending',
          ),
        );
        if (revRes.statusCode == 200) {
          final body = jsonDecode(revRes.body);
          if (body is List) {
            revs = body
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          } else if (body is Map && body['results'] is List) {
            revs = (body['results'] as List<dynamic>)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }
      } catch (_) {
        revs = const [];
      }

      if (!mounted) return;
      setState(() {
        _notifications = items;
        _inboxItems = inbox;
        _revertRequests = revs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notifications = const [];
        _inboxItems = const [];
        _error = e.toString();
        _loading = false;
      });
    }
  }

  NotificationItem _toNotification(PmTaskTodayItem task) {
    final status = task.status.toLowerCase();
    final notifStatus = switch (status) {
      'in_progress' || 'in progress' => NotificationStatus.info,
      'assigned' => NotificationStatus.warning,
      'pending' => NotificationStatus.urgent,
      _ => NotificationStatus.info,
    };

    final project = (task.projectName ?? '').trim();
    final title = project.isEmpty ? task.title : '$project: ${task.title}';

    final workers = task.assignedWorkers.isEmpty
        ? ''
        : 'Assigned: ${task.assignedWorkers.map((w) => w.fullName).join(', ')}';

    final description = workers.isEmpty
        ? 'Status: ${task.status}'
        : 'Status: ${task.status}. $workers';

    return NotificationItem(
      title: title,
      description: description,
      time: _relativeTime(task.updatedAt),
      status: notifStatus,
    );
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

  int? _pmUserId() {
    final raw = AuthService().currentUser?['user_id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<void> _approveRevert(int revertRequestId) async {
    final uid = _pmUserId();
    if (uid == null) return;
    setState(() => _revertActionBusy = true);
    try {
      final r = await http.post(
        AppConfig.apiUri(
          'subtask-completion-revert-requests/$revertRequestId/approve/?user_id=$uid',
        ),
        headers: const {'Content-Type': 'application/json'},
        body: '{}',
      );
      if (!mounted) return;
      if (r.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subtask reverted to not complete.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approve failed (${r.statusCode})'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _revertActionBusy = false);
    }
  }

  Future<void> _denyRevert(int revertRequestId) async {
    final uid = _pmUserId();
    if (uid == null) return;
    setState(() => _revertActionBusy = true);
    try {
      final r = await http.post(
        AppConfig.apiUri(
          'subtask-completion-revert-requests/$revertRequestId/deny/?user_id=$uid',
        ),
        headers: const {'Content-Type': 'application/json'},
        body: '{}',
      );
      if (!mounted) return;
      if (r.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request dismissed. Subtask stays complete.'),
          ),
        );
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed (${r.statusCode})'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _revertActionBusy = false);
    }
  }

  Future<void> _openInboxItem(PmInboxItem e) async {
    if (!e.read) {
      setState(() {
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
    invalidatePmNotificationBellCache();
    final goInv = e.target == 'inventory' ||
        e.kind == 'supervisor_inventory_returned';
    if (goInv) {
      await openPmInboxInventory(
        context,
        notificationId: e.notificationId,
      );
      return;
    }
    final goRep =
        e.target == 'reports' || e.kind == 'supervisor_report_submitted';
    if (goRep) {
      await openPmInboxReports(
        context,
        notificationId: e.notificationId,
      );
      return;
    }
    final sid = e.subtaskId;
    if (sid != null) {
      await openPmInboxSubtask(
        context,
        notificationId: e.notificationId,
        subtaskId: sid,
        phaseId: e.phaseId,
      );
    }
  }

  Future<void> _markAllInboxRead() async {
    final uid = _pmUserId();
    if (uid == null) return;
    final unread = _inboxItems.where((e) => !e.read).toList();
    if (unread.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No unread inbox items.')),
        );
      }
      return;
    }
    setState(() => _markInboxReadBusy = true);
    try {
      final results = await Future.wait(
        unread.map(
          (e) => http.post(
            AppConfig.apiUri('pm/inbox/${e.notificationId}/read/?user_id=$uid'),
            headers: const {'Content-Type': 'application/json'},
            body: '{}',
          ),
        ),
      );
      final failed = results.where((r) => r.statusCode != 200).length;
      PmDashboardService.clearUserCache(uid);
      invalidatePmNotificationBellCache();
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      if (failed == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked all inbox items as read.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Some items could not be updated ($failed).'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _markInboxReadBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final hasInbox = _inboxItems.isNotEmpty;
    final hasTasks = _notifications.isNotEmpty;
    final hasReverts = _revertRequests.isNotEmpty;
    final hasAny = hasInbox || hasTasks || hasReverts;
    final canMarkInboxRead =
        _inboxItems.any((e) => !e.read) && !_markInboxReadBusy;

    return ResponsivePageLayout(
      currentPage: 'Notifications',
      title: 'Notifications',
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: isMobile ? 16 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              onMarkAllInboxRead: _markAllInboxRead,
              markReadEnabled: canMarkInboxRead,
              markReadBusy: _markInboxReadBusy,
            ),
            const SizedBox(height: 24),
            _NotificationFilters(),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.04 * 255).round()),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Failed to load notifications.\n$_error',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _load,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0C1935),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else ...[
            if (hasReverts) ...[
              const Text(
                'Supervisor: uncheck completed subtask',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C1935),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Approve to move the subtask back to not complete, or dismiss the request.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              ..._revertRequests.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RevertRequestCard(
                    title: (r['subtask_title'] ?? 'Subtask').toString(),
                    project: (r['project_name'] ?? '').toString(),
                    phase: (r['phase_name'] ?? '').toString(),
                    supervisor: (r['supervisor_name'] ?? '').toString(),
                    reason: (r['reason'] ?? '').toString(),
                    busy: _revertActionBusy,
                    onApprove: () {
                      final id = r['revert_request_id'];
                      final n = id is int ? id : int.tryParse(id.toString());
                      if (n != null) _approveRevert(n);
                    },
                    onDeny: () {
                      final id = r['revert_request_id'];
                      final n = id is int ? id : int.tryParse(id.toString());
                      if (n != null) _denyRevert(n);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (hasInbox) ...[
              const Text(
                'In-app messages',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C1935),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'From supervisors and the system. Tap a row to open the related screen.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              ..._inboxItems.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _InboxMessageCard(
                    item: e,
                    time: _relativeTime(e.createdAt),
                    onOpen: () {
                      unawaited(_openInboxItem(e));
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (hasTasks) ...[
              const Text(
                'Subtasks needing attention',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C1935),
                ),
              ),
              const SizedBox(height: 12),
              ..._notifications.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NotificationCard(item: item),
                ),
              ),
            ],
            if (!hasAny)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.04 * 255).round()),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'No notifications right now.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
                ),
              ),
            ],
            SizedBox(height: isMobile ? 80 : 0),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onMarkAllInboxRead,
    this.markReadEnabled = false,
    this.markReadBusy = false,
  });

  final VoidCallback onMarkAllInboxRead;
  final bool markReadEnabled;
  final bool markReadBusy;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    void onPressed() {
      if (markReadEnabled && !markReadBusy) onMarkAllInboxRead();
    }

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'All Notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0C1935),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Monitor project alerts, approvals, and incidents.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: markReadBusy ? null : (markReadEnabled ? onPressed : null),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0C1935),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: markReadBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.done_all, size: 18),
              label: Text(
                markReadBusy ? 'Updating…' : 'Mark inbox as read',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All Notifications',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C1935),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Monitor project alerts, approvals, and incidents.',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            onPressed: markReadBusy ? null : (markReadEnabled ? onPressed : null),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0C1935),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: markReadBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all, size: 18),
            label: Text(
              markReadBusy ? 'Updating…' : 'Mark inbox as read',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _InboxMessageCard extends StatelessWidget {
  const _InboxMessageCard({
    required this.item,
    required this.time,
    required this.onOpen,
  });

  final PmInboxItem item;
  final String time;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.read
                  ? const Color(0xFFE5E7EB)
                  : const Color(0xFF93C5FD),
              width: item.read ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.04 * 255).round()),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.title.trim().isEmpty
                          ? 'Notification'
                          : item.title.trim(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                  ),
                  if (!item.read)
                    Container(
                      margin: const EdgeInsets.only(left: 6, right: 4, top: 4),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              if (item.body.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.body.trim(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                    height: 1.35,
                  ),
                ),
              ],
              if (item.supervisorName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'From: ${item.supervisorName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationFilters extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tags = ['All', 'Urgent', 'Approvals', 'Inventory'];
    return Wrap(
      spacing: 12,
      children: tags
          .map(
            (tag) => FilterChip(
              label: Text(tag),
              selected: tag == 'All',
              onSelected: (_) {},
              selectedColor: const Color(
                0xFFFF7A18,
              ).withAlpha((0.15 * 255).round()),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              labelStyle: TextStyle(
                color: tag == 'All'
                    ? const Color(0xFFFF7A18)
                    : const Color(0xFF0C1935),
                fontWeight: FontWeight.w600,
              ),
            ),
          )
          .toList(),
    );
  }
}

class NotificationCard extends StatelessWidget {
  const NotificationCard({super.key, required this.item});

  final NotificationItem item;

  Color _statusColor() {
    switch (item.status) {
      case NotificationStatus.urgent:
        return const Color(0xFFF97316);
      case NotificationStatus.warning:
        return const Color(0xFFEAB308);
      case NotificationStatus.success:
        return const Color(0xFF22C55E);
      case NotificationStatus.info:
        return const Color(0xFF6366F1);
    }
  }

  String _statusLabel() {
    switch (item.status) {
      case NotificationStatus.urgent:
        return 'Urgent';
      case NotificationStatus.warning:
        return 'Warning';
      case NotificationStatus.success:
        return 'Success';
      case NotificationStatus.info:
        return 'Info';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final color = _statusColor();

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.04 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withAlpha((0.15 * 255).round()),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.notifications, size: 18, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0C1935),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.more_horiz,
                        size: 20,
                        color: Color(0xFF9CA3AF),
                      ),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatusChip(label: _statusLabel(), color: color),
                    const SizedBox(width: 8),
                    Text(
                      item.time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withAlpha((0.15 * 255).round()),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.notifications, size: 18, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0C1935),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusChip(label: _statusLabel(), color: color),
                          const Spacer(),
                          Text(
                            item.time,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_horiz,
                    size: 20,
                    color: Color(0xFF9CA3AF),
                  ),
                  onPressed: () {},
                ),
              ],
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _RevertRequestCard extends StatelessWidget {
  const _RevertRequestCard({
    required this.title,
    required this.project,
    required this.phase,
    required this.supervisor,
    required this.reason,
    required this.busy,
    required this.onApprove,
    required this.onDeny,
  });

  final String title;
  final String project;
  final String phase;
  final String supervisor;
  final String reason;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE4C4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.04 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.isNotEmpty ? '$project · $title' : title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0C1935),
            ),
          ),
          if (phase.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Phase: $phase',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
          if (supervisor.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Supervisor: $supervisor',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Reason: $reason',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: busy ? null : onDeny,
                child: const Text('Dismiss'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: busy ? null : onApprove,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Approve uncheck'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NotificationItem {
  const NotificationItem({
    required this.title,
    required this.description,
    required this.time,
    required this.status,
  });

  final String title;
  final String description;
  final String time;
  final NotificationStatus status;
}

enum NotificationStatus { urgent, warning, success, info }
