import 'package:flutter/material.dart';
import '../cl_notifications.dart';
import '../cl_settings.dart';

class ClientDashboardHeader extends StatelessWidget {
  const ClientDashboardHeader({super.key, this.title = 'Dashboard'});

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
          // Notification bell (client-specific)
          _ClientNotificationMenu(),
          const SizedBox(width: 16),
          // User profile (simple)
          _ClientProfileMenu(),
        ],
      ),
    );
  }
}

class _ClientNotificationMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Notifications',
      offset: const Offset(0, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 1) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClNotificationsPage()));
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
                'Client notifications',
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
                title: 'Super Highway progress updated',
                time: '3 mins ago',
                color: const Color(0xFFFF7A18),
              ),
              const SizedBox(height: 12),
              _NotificationTile(
                title: 'Diversion Road report approved',
                time: '1 hr ago',
                color: const Color(0xFF22C55E),
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
  const _NotificationTile({required this.title, required this.time, required this.color});

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
  const _ClientProfileMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Profile',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        if (value == 1) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClNotificationsPage()));
        } else if (value == 2) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClSettingsPage()));
        } else if (value == 3) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Log out'),
              content: const Text('Are you sure you want to log out?'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Log out')),
              ],
            ),
          );
          if (confirm == true) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 1,
          child: Row(
            children: const [
              Icon(Icons.notifications_outlined, size: 16, color: Color(0xFF0C1935)),
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
              Text('Client', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(width: 6),
          Icon(Icons.keyboard_arrow_down, color: Colors.grey[600], size: 20),
        ],
      ),
    );
  }
}
