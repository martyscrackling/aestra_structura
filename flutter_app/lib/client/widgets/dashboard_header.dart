import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../cl_notifications.dart';
import '../cl_settings.dart';
import '../../services/auth_service.dart';
import '../../services/client_dashboard_service.dart';

class ClientDashboardHeader extends StatelessWidget {
  const ClientDashboardHeader({super.key, this.title = 'Dashboard'});

  final String title;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final auth = AuthService();
    final user = auth.currentUser;
    final first = (user?['first_name'] as String? ?? '').trim();
    final last = (user?['last_name'] as String? ?? '').trim();
    final fullName = ('$first $last').trim();
    final displayName = fullName.isNotEmpty ? fullName : 'AESTRA';
    final role = (user?['role'] as String? ?? 'Client').trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: isMobile ? 12 : 16,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: const Color(0xFF0C1935),
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Notification bell (client-specific)
              _ClientNotificationMenu(isMobile: isMobile),
              SizedBox(width: isMobile ? 8 : 16),
              // User profile (simple)
              _ClientProfileMenu(
                isMobile: isMobile,
                displayName: displayName,
                role: role.isEmpty ? 'Client' : role,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientNotificationMenu extends StatefulWidget {
  const _ClientNotificationMenu({this.isMobile = false});

  final bool isMobile;

  @override
  State<_ClientNotificationMenu> createState() =>
      _ClientNotificationMenuState();
}

class _ClientNotificationMenuState extends State<_ClientNotificationMenu> {
  final _service = ClientDashboardService();

  bool _loading = true;
  String? _error;
  int _count = 0;
  List<ClientNotificationItem> _items = const [];

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
      final payload = await _service.fetchClientNotifications(previewLimit: 3);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _count = payload.count;
        _items = payload.items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _count = 0;
        _items = const [];
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = widget.isMobile;

    return PopupMenuButton<int>(
      tooltip: 'Notifications',
      offset: Offset(0, isMobile ? 8 : 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      constraints: BoxConstraints(
        maxWidth: isMobile ? 280 : 320,
        maxHeight: isMobile ? 300 : 400,
      ),
      onSelected: (value) {
        if (value == 1) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ClNotificationsPage()),
          );
        }
      },
      onOpened: _refresh,
      itemBuilder: (context) => [
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
                _loading
                    ? 'Loading…'
                    : _error != null
                    ? 'Failed to load'
                    : _count == 0
                    ? 'No updates'
                    : '$_count task${_count == 1 ? '' : 's'} need attention',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loading)
                const Text(
                  'Loading…',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                )
              else if (_error != null)
                const Text(
                  'Unable to load notifications.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                )
              else if (_items.isEmpty)
                const Text(
                  'No notifications.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                )
              else
                for (final n in _items) ...[
                  _NotificationTile(
                    title: n.title,
                    time: n.time,
                    color: const Color(0xFFFF7A18),
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
      ],
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.notifications_outlined,
            size: isMobile ? 22 : 24,
            color: Colors.grey[600],
          ),
          if (!_loading && _error == null && _count > 0)
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
                  _count > 99 ? '99+' : '$_count',
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

class _ClientProfileMenu extends StatelessWidget {
  const _ClientProfileMenu({
    required this.displayName,
    required this.role,
    this.isMobile = false,
  });

  final bool isMobile;
  final String displayName;
  final String role;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Profile',
      offset: Offset(0, isMobile ? 40 : 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      constraints: BoxConstraints(maxWidth: isMobile ? 180 : 200),
      onSelected: (value) async {
        if (value == 1) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ClNotificationsPage()),
          );
        } else if (value == 2) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ClSettingsPage()));
        } else if (value == 3) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Log out'),
              content: const Text('Are you sure you want to log out?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Log out'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await AuthService().logout();
            if (!context.mounted) return;
            context.go('/login');
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 1,
          child: Row(
            children: const [
              Icon(
                Icons.notifications_outlined,
                size: 16,
                color: Color(0xFF0C1935),
              ),
              SizedBox(width: 8),
              Text('Notifications'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 2,
          child: Row(
            children: const [
              Icon(Icons.settings, size: 16, color: Color(0xFF0C1935)),
              SizedBox(width: 8),
              Text('Settings'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 3,
          child: Row(
            children: const [
              Icon(Icons.logout, size: 16, color: Color(0xFF0C1935)),
              SizedBox(width: 8),
              Text('Log out'),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: isMobile ? 16 : 18,
            backgroundColor: const Color(0xFF0C1935),
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: isMobile ? 18 : 20,
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0C1935),
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(width: 6),
          ],
          Icon(
            Icons.keyboard_arrow_down,
            color: Colors.grey[600],
            size: isMobile ? 18 : 20,
          ),
        ],
      ),
    );
  }
}
