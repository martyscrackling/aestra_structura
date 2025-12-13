import 'package:flutter/material.dart';
import '../settings_page.dart';
import '../notification_page.dart';
import '../../services/auth_service.dart';
import 'package:go_router/go_router.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key, this.title = 'Dashboard'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0C1935),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          // Notification bell
          const _NotificationMenu(),
          const SizedBox(width: 16),
          // User profile
          const _ProfileMenu(),
        ],
      ),
    );
  }
}

class _NotificationMenu extends StatelessWidget {
  const _NotificationMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Notifications',
      offset: const Offset(0, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 1) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const NotificationPage()));
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Notifications',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF0C1935),
                ),
              ),
              SizedBox(height: 4),
              Text(
                '2 new updates',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
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
              _NotificationTile(
                title: 'Super Highway inventory low',
                time: '3 mins ago',
                color: const Color(0xFFFF7A18),
              ),
              const SizedBox(height: 12),
              _NotificationTile(
                title: 'Diversion Road report approved',
                time: '1 hr ago',
                color: const Color(0xFF22C55E),
              ),
              const SizedBox(height: 12),
              _NotificationTile(
                title: 'New license request',
                time: 'Yesterday',
                color: const Color(0xFF6366F1),
              ),
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
          Icon(Icons.notifications_outlined, size: 24, color: Colors.grey[600]),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
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

enum _ProfileAction { settings, notifications, logout }

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu();

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
    return PopupMenuButton<_ProfileAction>(
      tooltip: 'Profile menu',
      offset: const Offset(0, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            children: const [
              Text(
                'AESTRA',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0C1935),
                ),
              ),
              Text('Admin', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          Icon(Icons.keyboard_arrow_down, color: Colors.grey[600], size: 20),
        ],
      ),
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
