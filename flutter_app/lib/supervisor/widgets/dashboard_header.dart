import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../services/app_config.dart';
import '../../services/auth_service.dart';

class DashboardHeader extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const DashboardHeader({super.key, this.onMenuPressed});

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader> {
  // Notifications are handled by _SupervisorNotificationMenu.

  String _displayName(Map<String, dynamic>? user) {
    final first = (user?['first_name'] as String? ?? '').trim();
    final last = (user?['last_name'] as String? ?? '').trim();
    final full = ('$first $last').trim();
    if (full.isNotEmpty) return full;
    final email = (user?['email'] as String? ?? '').trim();
    if (email.isNotEmpty) return email;
    return 'AESTRA';
  }

  String _subtitle(Map<String, dynamic>? user) {
    final role = (user?['role'] as String? ?? '').trim();
    if (role.isNotEmpty) return role;
    final type = (user?['type'] as String? ?? '').trim();
    if (type.isNotEmpty) return type;
    return 'Supervisor';
  }

  String _avatarLetter(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'A';
    return trimmed.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 600;

    final auth = AuthService();
    final user = auth.currentUser;
    final name = _displayName(user);
    final subtitle = _subtitle(user);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Left side - Dashboard title
          const Text(
            "Dashboard",
            style: TextStyle(
              color: Color(0xFF0C1935),
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
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8D5F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              _avatarLetter(name),
                              style: const TextStyle(
                                color: Color(0xFFB088D9),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Color(0xFF0C1935),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
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
    setState(() {
      _loading = true;
      _error = null;
    });

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

      final response = await http.get(
        AppConfig.apiUri('subtasks/?project_id=$projectId'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw Exception('Unexpected response');
      }

      final all = decoded.whereType<Map<String, dynamic>>().toList();
      final open = all
          .where(
            (t) => (t['status']?.toString().toLowerCase() ?? '') != 'completed',
          )
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

      if (!mounted) return;
      setState(() {
        _loading = false;
        _badgeCount = open.length;
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _badgeCount = 0;
        _items = const [];
        _error = e.toString();
      });
    }
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
      offset: const Offset(0, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onOpened: _refresh,
      onSelected: (value) {
        if (value == 1) {
          context.go('/supervisor/task-progress');
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
                  'View all tasks',
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: Color(0xFF0C1935),
              size: 24,
            ),
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
