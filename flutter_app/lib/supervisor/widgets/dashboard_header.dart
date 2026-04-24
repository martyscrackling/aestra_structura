import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../services/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/app_theme_tokens.dart';
import '../supervisor_inbox_nav.dart';
import 'supervisor_user_badge.dart';

class DashboardHeader extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  final String title;

  const DashboardHeader({
    super.key,
    this.onMenuPressed,
    this.title = 'Dashboard',
  });

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader> {
  // Notifications are handled by _SupervisorNotificationMenu.

  String _supervisorFirstName() {
    final user = AuthService().currentUser;
    final first = (user?['first_name'] as String? ?? '').trim();
    if (first.isNotEmpty) return first;

    final email = (user?['email'] as String? ?? '').trim();
    if (email.isNotEmpty) {
      final local = email.split('@').first.trim();
      if (local.isNotEmpty) {
        return local.substring(0, 1).toUpperCase() +
            (local.length > 1 ? local.substring(1) : '');
      }
    }

    return 'Supervisor';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Left side - Dashboard title
          Text(
            widget.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),

          // Right side - Notification bell + AESTRA
          Row(
            children: [
              const _SupervisorNotificationMenu(),
              const SizedBox(width: 24),

              // AESTRA logo + text (clickable dropdown)
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'switch') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Switch Account clicked')),
                    );
                  } else if (value == 'logout') {
                    await AuthService().logout();
                    if (!context.mounted) return;
                    context.go('/login');
                  }
                },
                color: Colors.white,
                offset: const Offset(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'switch',
                    height: 48,
                    child: Row(
                      children: [
                        Icon(
                          Icons.swap_horiz,
                          size: 18,
                          color: Color(0xFF0C1935),
                        ),
                        SizedBox(width: 12),
                        Text('Switch Account'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    height: 48,
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 18, color: Color(0xFFFF6B6B)),
                        SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: TextStyle(color: Color(0xFFFF6B6B)),
                        ),
                      ],
                    ),
                  ),
                ],
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SupervisorUserBadge(
                          showName: false,
                          avatarSize: 34,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _supervisorFirstName(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupervisorNotificationMenu extends StatefulWidget {
  const _SupervisorNotificationMenu();

  @override
  State<_SupervisorNotificationMenu> createState() =>
      _SupervisorNotificationMenuState();
}

class _SupervisorNotificationMenuState
    extends State<_SupervisorNotificationMenu> {
  static const Duration _cacheTtl = Duration(seconds: 45);
  static const int _kViewAllValue = 1;
  static const int _kInboxValueBase = 1000000;
  static final Map<int, _SupervisorNotifCacheEntry> _cacheBySupervisor =
      <int, _SupervisorNotifCacheEntry>{};
  static final Map<int, Future<_SupervisorNotifSnapshot>> _inFlightBySupervisor =
      <int, Future<_SupervisorNotifSnapshot>>{};

  bool _loading = true;
  String? _error;
  int _badgeCount = 0;
  List<_SupervisorInboxRow> _inboxPreview = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  static void clearSharedCache() {
    _cacheBySupervisor.clear();
  }

  Future<void> _refresh() async {
    try {
      final sid = supervisorIdFromAuth();
      if (sid == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _badgeCount = 0;
          _inboxPreview = const [];
        });
        return;
      }

      final cached = _cacheBySupervisor[sid];
      if (cached != null &&
          DateTime.now().difference(cached.cachedAt) <= _cacheTtl) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = null;
          _badgeCount = cached.snapshot.badgeCount;
          _inboxPreview = cached.snapshot.inboxPreview;
        });
        return;
      }

      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }

      final inFlight = _inFlightBySupervisor[sid];
      final Future<_SupervisorNotifSnapshot> future;
      if (inFlight != null) {
        future = inFlight;
      } else {
        final created = _fetchInbox(supervisorId: sid);
        _inFlightBySupervisor[sid] = created;
        future = created;
      }

      final snapshot = await future;

      _cacheBySupervisor[sid] = _SupervisorNotifCacheEntry(
        snapshot: snapshot,
        cachedAt: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _badgeCount = snapshot.badgeCount;
        _inboxPreview = snapshot.inboxPreview;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _badgeCount = 0;
        _inboxPreview = const [];
        _error = e.toString();
      });
    } finally {
      final sid = supervisorIdFromAuth();
      if (sid != null) {
        _inFlightBySupervisor.remove(sid);
      }
    }
  }

  Future<_SupervisorNotifSnapshot> _fetchInbox({required int supervisorId}) async {
    final response = await http.get(
      AppConfig.apiUri('supervisor/inbox/?supervisor_id=$supervisorId'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load inbox: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Invalid inbox response');
    }
    if (decoded['success'] != true) {
      throw Exception(decoded['message']?.toString() ?? 'Inbox request failed');
    }
    final inbox = (decoded['inbox'] as Map<String, dynamic>?) ?? {};
    final unread = (inbox['unread_count'] as num?)?.toInt() ?? 0;
    final raw = (inbox['items'] as List<dynamic>?) ?? const [];
    final rows = <_SupervisorInboxRow>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final nid = (m['notification_id'] as num?)?.toInt() ?? 0;
      if (nid == 0) continue;
      rows.add(
        _SupervisorInboxRow(
          notificationId: nid,
          title: (m['title'] ?? '').toString(),
          body: (m['body'] ?? '').toString(),
          read: m['read'] as bool? ?? true,
          time: _relativeTime(
            DateTime.tryParse((m['created_at'] as String?) ?? ''),
          ),
          target: m['target']?.toString(),
          projectId: parseInboxId(m['project_id']),
          phaseId: parseInboxId(m['phase_id']),
          subtaskId: parseInboxId(m['subtask_id']),
          planId: parseInboxId(m['plan_id']),
          itemId: parseInboxId(m['item_id']),
          unitId: parseInboxId(m['unit_id']),
        ),
      );
    }
    return _SupervisorNotifSnapshot(
      badgeCount: unread,
      inboxPreview: rows.take(6).toList(growable: false),
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

  @override
  Widget build(BuildContext context) {
    final count = _badgeCount;

    return PopupMenuButton<int>(
      tooltip: 'Notifications',
      color: Colors.white,
      offset: const Offset(0, 12),
      constraints: const BoxConstraints(minWidth: 300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onOpened: _refresh,
      onSelected: (value) {
        if (value == _kViewAllValue) {
          context.go('/supervisor/notifications');
          return;
        }
        if (value >= _kInboxValueBase) {
          final nid = value - _kInboxValueBase;
          for (final r in _inboxPreview) {
            if (r.notificationId == nid) {
              openSupervisorInboxNotification(
                context,
                notificationId: r.notificationId,
                target: r.target,
                projectId: r.projectId,
                phaseId: r.phaseId,
                subtaskId: r.subtaskId,
                planId: r.planId,
                itemId: r.itemId,
                unitId: r.unitId,
                markRead: true,
              );
              clearSharedCache();
              _refresh();
              return;
            }
          }
        }
      },
      itemBuilder: (context) {
        final subtitle = _loading
            ? 'Loading…'
            : _error != null
            ? 'Failed to load'
            : count == 0
            ? 'No unread'
            : '$count unread';

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
        } else if (_inboxPreview.isEmpty) {
          entries.add(
            const PopupMenuItem(
              enabled: false,
              child: Text(
                'No messages from your PM yet.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ),
          );
        } else {
          for (final r in _inboxPreview) {
            entries.add(
              PopupMenuItem<int>(
                value: _kInboxValueBase + r.notificationId,
                child: _SupervisorInboxMenuTile(row: r),
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
          const Icon(
            Icons.notifications_outlined,
            color: Color(0xFF0C1935),
            size: 24,
          ),
          if (!_loading && _error == null && count > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B),
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

class _SupervisorInboxRow {
  const _SupervisorInboxRow({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.read,
    required this.time,
    this.target,
    this.projectId,
    this.phaseId,
    this.subtaskId,
    this.planId,
    this.itemId,
    this.unitId,
  });

  final int notificationId;
  final String title;
  final String body;
  final bool read;
  final String time;
  final String? target;
  final int? projectId;
  final int? phaseId;
  final int? subtaskId;
  final int? planId;
  final int? itemId;
  final int? unitId;
}

class _SupervisorNotifSnapshot {
  final int badgeCount;
  final List<_SupervisorInboxRow> inboxPreview;

  const _SupervisorNotifSnapshot({
    required this.badgeCount,
    required this.inboxPreview,
  });
}

class _SupervisorNotifCacheEntry {
  final _SupervisorNotifSnapshot snapshot;
  final DateTime cachedAt;

  const _SupervisorNotifCacheEntry({
    required this.snapshot,
    required this.cachedAt,
  });
}

class _SupervisorInboxMenuTile extends StatelessWidget {
  const _SupervisorInboxMenuTile({required this.row});

  final _SupervisorInboxRow row;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  row.title.isEmpty ? 'Notification' : row.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0C1935),
                  ),
                ),
              ),
              if (!row.read) ...[
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            row.time,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
          if (row.body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              row.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
            ),
          ],
        ],
      ),
    );
  }
}
