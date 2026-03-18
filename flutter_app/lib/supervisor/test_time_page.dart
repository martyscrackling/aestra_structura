import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../services/app_time_service.dart';
import 'widgets/sidebar.dart';
import 'widgets/supervisor_user_badge.dart';

class TestTimePage extends StatefulWidget {
  final bool initialSidebarVisible;

  const TestTimePage({super.key, this.initialSidebarVisible = false});

  @override
  State<TestTimePage> createState() => _TestTimePageState();
}

class _TestTimePageState extends State<TestTimePage> {
  final Color neutral = const Color(0xFFF4F6F9);
  final Color accent = const Color(0xFFFF6F00);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  DateTime _pickedDateTime = AppTimeService.now();

  @override
  void initState() {
    super.initState();
    final existing = AppTimeService.overrideNow;
    if (existing != null) {
      _pickedDateTime = existing;
    }
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      _pickedDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _pickedDateTime.hour,
        _pickedDateTime.minute,
        _pickedDateTime.second,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _pickedDateTime.hour,
        minute: _pickedDateTime.minute,
      ),
    );
    if (picked == null) return;

    setState(() {
      _pickedDateTime = DateTime(
        _pickedDateTime.year,
        _pickedDateTime.month,
        _pickedDateTime.day,
        picked.hour,
        picked.minute,
        0,
      );
    });
  }

  Future<void> _applyOverride() async {
    await AppTimeService.setOverride(_pickedDateTime);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Test time set to ${_formatDateTime(_pickedDateTime)}'),
      ),
    );
  }

  Future<void> _clearOverride() async {
    await AppTimeService.clearOverride();
    if (!mounted) return;
    setState(() {
      _pickedDateTime = AppTimeService.now();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test time cleared. Using device time.')),
    );
  }

  void _navigateToPage(String page) {
    switch (page) {
      case 'Dashboard':
        context.go('/supervisor');
        break;
      case 'Workers':
      case 'Worker Management':
        context.go('/supervisor/workers');
        break;
      case 'Attendance':
        context.go('/supervisor/attendance');
        break;
      case 'Logs':
      case 'Daily Logs':
        context.go('/supervisor/daily-logs');
        break;
      case 'Tasks':
      case 'Task Progress':
        context.go('/supervisor/task-progress');
        break;
      case 'Reports':
        context.go('/supervisor/reports');
        break;
      case 'Inventory':
        context.go('/supervisor/inventory');
        break;
      case 'Test Time':
        return;
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: neutral,
      body: Row(
        children: [
          if (isDesktop) Sidebar(activePage: 'Test Time', keepVisible: true),
          Expanded(
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Test Date & Time',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0C1935),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const SupervisorUserBadge(),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Card(
                        elevation: 2,
                        margin: const EdgeInsets.all(20),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: ValueListenableBuilder<DateTime?>(
                            valueListenable: AppTimeService.overrideNotifier,
                            builder: (context, activeOverride, _) {
                              final effectiveNow = AppTimeService.now();
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Testing Clock Controls',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0C1935),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Use this menu to simulate system date/time for app workflows.',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _infoRow(
                                    label: 'Current effective time',
                                    value: _formatDateTime(effectiveNow),
                                  ),
                                  const SizedBox(height: 10),
                                  _infoRow(
                                    label: 'Active override',
                                    value: activeOverride == null
                                        ? 'None (device clock)'
                                        : _formatDateTime(activeOverride),
                                  ),
                                  const SizedBox(height: 20),
                                  _infoRow(
                                    label: 'Selected test value',
                                    value: _formatDateTime(_pickedDateTime),
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: _pickDate,
                                        icon: const Icon(Icons.calendar_today),
                                        label: const Text('Pick Date'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _pickTime,
                                        icon: const Icon(Icons.access_time),
                                        label: const Text('Pick Time'),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: _applyOverride,
                                        icon: const Icon(Icons.save),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: accent,
                                          foregroundColor: Colors.white,
                                        ),
                                        label: const Text('Apply Test Time'),
                                      ),
                                      TextButton.icon(
                                        onPressed: _clearOverride,
                                        icon: const Icon(Icons.restore),
                                        label: const Text('Reset to Device Time'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF3E0),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFFFD7A8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Note: This affects in-app time-dependent features that use the test clock. It does not change your device clock or server clock.',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: !isDesktop
          ? Drawer(
              child: Sidebar(activePage: 'Test Time', keepVisible: false),
            )
          : null,
      floatingActionButton: !isDesktop
          ? FloatingActionButton(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              child: const Icon(Icons.menu),
            )
          : null,
    );
  }

  Widget _infoRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0C1935),
            ),
          ),
        ),
      ],
    );
  }
}
