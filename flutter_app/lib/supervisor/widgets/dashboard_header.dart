import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../services/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/app_theme_tokens.dart';
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
  static final Map<int, _SupervisorNotifCacheEntry> _cacheByProject =
      <int, _SupervisorNotifCacheEntry>{};
  static final Map<int, Future<_SupervisorNotifSnapshot>> _inFlightByProject =
      <int, Future<_SupervisorNotifSnapshot>>{};

  bool _loading = true;
  String? _error;
  int _badgeCount = 0;
  List<_SupervisorUiNotification> _items = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final auth = AuthService();
      final projectIdRaw = auth.currentUser?['project_id'];
      final projectId = projectIdRaw is int
          ? projectIdRaw
          : int.tryParse(projectIdRaw?.toString() ?? '');

      if (projectId == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _badgeCount = 0;
          _items = const [];
        });
        return;
      }

      final cached = _cacheByProject[projectId];
      if (cached != null &&
          DateTime.now().difference(cached.cachedAt) <= _cacheTtl) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = null;
          _badgeCount = cached.snapshot.badgeCount;
          _items = cached.snapshot.items;
        });
        return;
      }

      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }

      final inFlight = _inFlightByProject[projectId];
      final Future<_SupervisorNotifSnapshot> future;
      if (inFlight != null) {
        future = inFlight;
      } else {
        final created = _fetchNotifications(projectId: projectId);
        _inFlightByProject[projectId] = created;
        future = created;
      }

      final snapshot = await future;

      _cacheByProject[projectId] = _SupervisorNotifCacheEntry(
        snapshot: snapshot,
        cachedAt: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _badgeCount = snapshot.badgeCount;
        _items = snapshot.items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _badgeCount = 0;
        _items = const [];
        _error = e.toString();
      });
    } finally {
      final auth = AuthService();
      final projectIdRaw = auth.currentUser?['project_id'];
      final projectId = projectIdRaw is int
          ? projectIdRaw
          : int.tryParse(projectIdRaw?.toString() ?? '');
      if (projectId != null) {
        _inFlightByProject.remove(projectId);
      }
    }
  }

  Future<_SupervisorNotifSnapshot> _fetchNotifications({
    required int projectId,
  }) async {
    final response = await http.get(
      AppConfig.apiUri('subtasks/?project_id=$projectId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final rawList = decoded is List
        ? decoded
        : (decoded is Map<String, dynamic> && decoded['results'] is List
              ? decoded['results'] as List<dynamic>
              : const <dynamic>[]);

    final all = rawList.whereType<Map<String, dynamic>>().toList();
    final open = all
        .where((t) => (t['status']?.toString().toLowerCase() ?? '') != 'completed')
        .toList();

    open.sort((a, b) {
      final aUpdated = (a['updated_at'] as String?) ?? '';
      final bUpdated = (b['updated_at'] as String?) ?? '';
      return bUpdated.compareTo(aUpdated);
    });

    final items = <_SupervisorUiNotification>[];
    for (final t in open.take(3)) {
      final title = (t['title'] as String?) ?? 'Untitled task';
      final status = (t['status'] as String?) ?? 'pending';
      items.add(
        _SupervisorUiNotification(
          title: title,
          time: _relativeTime(
            DateTime.tryParse((t['updated_at'] as String?) ?? ''),
          ),
          color: _statusColor(status),
        ),
      );
    }

    return _SupervisorNotifSnapshot(badgeCount: open.length, items: items);
  }

  Color _statusColor(String statusRaw) {
    final status = statusRaw.toLowerCase();
    return switch (status) {
      'in_progress' || 'in progress' => const Color(0xFF2563EB),
      'assigned' => const Color(0xFFFF7A18),
      'pending' => const Color(0xFF6B7280),
      _ => const Color(0xFF6B7280),
    };
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onOpened: _refresh,
      onSelected: (value) {
        if (value == 1) {
          context.go('/supervisor/reports');
        }
      },
      itemBuilder: (context) {
        final subtitle = _loading
            ? 'Loading…'
            : _error != null
            ? 'Failed to load'
            : count == 0
            ? 'No updates'
            : '$count task${count == 1 ? '' : 's'} need attention';

        return [
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
          PopupMenuItem(
            enabled: false,
            child: _loading
                ? const Text(
                    'Loading…',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  )
                : _error != null
                ? const Text(
                    'Unable to load notifications.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  )
                : _items.isEmpty
                ? const Text(
                    'No notifications.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final n in _items) ...[
                        _SupervisorNotificationTile(
                          title: n.title,
                          time: n.time,
                          color: n.color,
                        ),
                        if (n != _items.last) const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 1,
            child: Row(
              children: const [
                Icon(Icons.open_in_new, size: 16, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Text(
                  'View reports',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
        ];
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

class _SupervisorUiNotification {
  final String title;
  final String time;
  final Color color;

  const _SupervisorUiNotification({
    required this.title,
    required this.time,
    required this.color,
  });
}

class _SupervisorNotifSnapshot {
  final int badgeCount;
  final List<_SupervisorUiNotification> items;

  const _SupervisorNotifSnapshot({
    required this.badgeCount,
    required this.items,
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

class _SupervisorNotificationTile extends StatelessWidget {
  const _SupervisorNotificationTile({
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
