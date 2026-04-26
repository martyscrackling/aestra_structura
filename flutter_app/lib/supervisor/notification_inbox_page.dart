import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'supervisor_inbox_nav.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/mobile_bottom_nav.dart';
import 'widgets/sidebar.dart';
import '../services/app_config.dart';

class SupervisorNotificationPage extends StatefulWidget {
  const SupervisorNotificationPage({super.key});

  @override
  State<SupervisorNotificationPage> createState() =>
      _SupervisorNotificationPageState();
}

class _InboxListItem {
  _InboxListItem({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.read,
    required this.timeLabel,
    required this.target,
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
  final String timeLabel;
  final String? target;
  final int? projectId;
  final int? phaseId;
  final int? subtaskId;
  final int? planId;
  final int? itemId;
  final int? unitId;
}

class _SupervisorNotificationPageState extends State<SupervisorNotificationPage> {
  bool _loading = true;
  String? _error;
  List<_InboxListItem> _items = const [];
  bool _markBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _relativeTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  Future<void> _load() async {
    final sid = supervisorIdFromAuth();
    if (sid == null) {
      setState(() {
        _loading = false;
        _items = const [];
        _error = 'Not signed in as supervisor';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await http.get(
        AppConfig.apiUri('supervisor/inbox/?supervisor_id=$sid'),
      );
      if (r.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Load failed (${r.statusCode})';
        });
        return;
      }
      final decoded = jsonDecode(r.body);
      if (decoded is! Map) {
        setState(() {
          _loading = false;
          _error = 'Invalid response';
        });
        return;
      }
      final inbox = (decoded['inbox'] as Map<String, dynamic>?) ?? {};
      final raw = (inbox['items'] as List<dynamic>?) ?? const [];
      final list = <_InboxListItem>[];
      for (final e in raw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final nid = (m['notification_id'] as num?)?.toInt() ?? 0;
        if (nid == 0) continue;
        list.add(
          _InboxListItem(
            notificationId: nid,
            title: (m['title'] ?? '').toString(),
            body: (m['body'] ?? '').toString(),
            read: m['read'] as bool? ?? true,
            timeLabel: _relativeTime(m['created_at']?.toString()),
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
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _markAllRead() async {
    final sid = supervisorIdFromAuth();
    if (sid == null) return;
    final unread = _items.where((e) => !e.read).toList();
    if (unread.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No unread items.')),
        );
      }
      return;
    }
    setState(() => _markBusy = true);
    try {
      await Future.wait(
        unread.map(
          (e) => http.post(
            AppConfig.apiUri(
              'supervisor/inbox/${e.notificationId}/read/?supervisor_id=$sid',
            ),
            headers: const {'Content-Type': 'application/json'},
            body: '{}',
          ),
        ),
      );
      clearSupervisorNotificationMenuCache();
      if (mounted) await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as read.')),
        );
      }
    } finally {
      if (mounted) setState(() => _markBusy = false);
    }
  }

  void _navFromBottomNav(String page) {
    switch (page) {
      case 'Dashboard':
        context.go('/supervisor');
        break;
      case 'Projects':
        context.go('/supervisor/projects');
        break;
      case 'Workers':
      case 'Worker Management':
        context.go('/supervisor/workers');
        break;
      case 'Attendance':
        context.go('/supervisor/attendance');
        break;
      case 'Reports':
        context.go('/supervisor/reports');
        break;
      case 'Inventory':
        context.go('/supervisor/inventory');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w > 1024;
    final isMobile = w <= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          if (isDesktop) const Sidebar(activePage: 'Dashboard', keepVisible: true),
          Expanded(
            child: Column(
              children: [
                const DashboardHeader(title: 'Notifications'),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 24,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Updates from your project manager',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0C1935),
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _markBusy ? null : _markAllRead,
                                icon: _markBusy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.done_all, size: 18),
                                label: Text(
                                  _markBusy ? 'Working…' : 'Mark all read',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_loading)
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (_error != null)
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                              ),
                            )
                          else if (_items.isEmpty)
                            const Text(
                              'No notifications yet.',
                              style: TextStyle(color: Color(0xFF6B7280)),
                            )
                          else
                            ..._items.map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _InboxCard(
                                  item: e,
                                  onTap: () async {
                                    clearSupervisorNotificationMenuCache();
                                    await openSupervisorInboxNotification(
                                      context,
                                      notificationId: e.notificationId,
                                      target: e.target,
                                      projectId: e.projectId,
                                      phaseId: e.phaseId,
                                      subtaskId: e.subtaskId,
                                      planId: e.planId,
                                      itemId: e.itemId,
                                      unitId: e.unitId,
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile
          ? SupervisorMobileBottomNav(
              activeTab: SupervisorMobileTab.dashboard,
              onSelect: _navFromBottomNav,
            )
          : null,
    );
  }
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({required this.item, required this.onTap});

  final _InboxListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: item.read
                  ? const Color(0xFFE5E7EB)
                  : const Color(0xFF93C5FD),
              width: item.read ? 1 : 1.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 6,
                offset: Offset(0, 2),
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
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                  ),
                  if (!item.read)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 4, right: 6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    item.timeLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              if (item.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.body,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              const Text(
                'Tap to open',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
