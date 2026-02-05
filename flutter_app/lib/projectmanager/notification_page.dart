import 'package:flutter/material.dart';

import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/responsive_page_layout.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  static final List<NotificationItem> _notifications = [
    NotificationItem(
      title: 'Inventory alert',
      description: 'Super Highway needs to restock rebar steel.',
      time: '5 min ago',
      status: NotificationStatus.urgent,
    ),
    NotificationItem(
      title: 'Report approved',
      description: 'Diversion Road weekly report was approved.',
      time: '1 hr ago',
      status: NotificationStatus.success,
    ),
    NotificationItem(
      title: 'License request',
      description: 'New enterprise license request pending review.',
      time: 'Yesterday',
      status: NotificationStatus.info,
    ),
    NotificationItem(
      title: 'Worker incident',
      description: 'Safety incident logged for Mason crew.',
      time: 'Jul 18, 2025',
      status: NotificationStatus.warning,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

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
            _Header(onClear: () {}),
            const SizedBox(height: 24),
            _NotificationFilters(),
            const SizedBox(height: 16),
            ..._notifications.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NotificationCard(item: item),
              ),
            ),
            SizedBox(height: isMobile ? 80 : 0),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

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
              onPressed: onClear,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0C1935),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text(
                'Mark all as read',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
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
        const Spacer(),
        SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            onPressed: onClear,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0C1935),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text(
              'Mark all as read',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
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
              selectedColor: const Color(0xFFFF7A18).withOpacity(0.15),
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
            color: Colors.black.withOpacity(0.04),
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
                        color: color.withOpacity(0.15),
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
                    color: color.withOpacity(0.15),
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
        color: color.withOpacity(0.1),
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
