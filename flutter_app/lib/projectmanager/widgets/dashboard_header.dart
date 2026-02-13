import 'package:flutter/material.dart';
import '../settings_page.dart';
import '../notification_page.dart';
import '../../services/auth_service.dart';
import '../../services/pm_dashboard_service.dart';
import 'package:go_router/go_router.dart';

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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Notification bell
              const _NotificationMenu(),
              SizedBox(width: spacing),
              // User profile
              const _ProfileMenu(),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationMenu extends StatefulWidget {
  const _NotificationMenu();

  @override
  State<_NotificationMenu> createState() => _NotificationMenuState();
}

class _NotificationMenuState extends State<_NotificationMenu> {
  final PmDashboardService _dashboardService = PmDashboardService();

  bool _loading = true;
  String? _error;
  List<_UiNotification> _items = const [];
  int _badgeCount = 0;

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
      final authService = AuthService();
      final userIdRaw = authService.currentUser?['user_id'];
      final userId = userIdRaw is int
          ? userIdRaw
          : int.tryParse(userIdRaw?.toString() ?? '');

      if (userId == null) {
        setState(() {
          _items = const [];
          _loading = false;
        });
        return;
      }

      final summary = await _dashboardService.fetchSummary(userId: userId);
      final derived = _deriveFromSummary(summary);

      if (!mounted) return;
      setState(() {
        _items = derived;
        _badgeCount = summary.notificationsCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _badgeCount = 0;
        _error = e.toString();
        _loading = false;
      });
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

    return items.take(3).toList(growable: false);
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
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const NotificationPage()));
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
                        _NotificationTile(
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
        ];
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

enum _ProfileAction { settings, notifications, logout }

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu();

  String _displayName(Map<String, dynamic>? user) {
    final first = (user?['first_name'] as String?)?.trim() ?? '';
    final last = (user?['last_name'] as String?)?.trim() ?? '';
    final full = ('$first $last').trim();
    if (full.isNotEmpty) return full;

    final email = (user?['email'] as String?)?.trim() ?? '';
    if (email.isNotEmpty) return email;

    return 'AESTRA';
  }

  String _displayRole(Map<String, dynamic>? user) {
    final role = (user?['role'] as String?)?.trim();
    if (role != null && role.isNotEmpty) return role;

    final type = (user?['type'] as String?)?.trim();
    if (type != null && type.isNotEmpty) return type;

    return 'Account';
  }

  void _handleAction(BuildContext context, _ProfileAction action) {
    switch (action) {
      case _ProfileAction.settings:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => SettingsPage()));
        break;
      case _ProfileAction.notifications:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NotificationPage()));
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
