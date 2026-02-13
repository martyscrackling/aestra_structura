import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/active_project.dart';
import 'widgets/tasks.dart';
import 'widgets/workers.dart';
import 'widgets/calendar_panel.dart';
import 'widgets/phases.dart';
import 'workers_management.dart';
import 'attendance_page.dart';
import 'daily_logs.dart';
import 'task_progress.dart';
import 'reports.dart';
import 'inventory.dart';

class SupervisorDashboardPage extends StatefulWidget {
  final bool initialSidebarVisible;

  const SupervisorDashboardPage({
    super.key,
    this.initialSidebarVisible = false,
  });

  @override
  State<SupervisorDashboardPage> createState() =>
      _SupervisorDashboardPageState();
}

class _SupervisorDashboardPageState extends State<SupervisorDashboardPage> {
  int? _currentProjectId;
  final GlobalKey _activeProjectKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  void _navigateToPage(String page) {
    Widget destination;
    switch (page) {
      case 'Dashboard':
        return; // Already on dashboard
      case 'Workers':
      case 'Worker Management':
        destination = const WorkerManagementPage(initialSidebarVisible: false);
        break;
      case 'Attendance':
        destination = const AttendancePage(initialSidebarVisible: false);
        break;
      case 'Logs':
      case 'Daily Logs':
        destination = const DailyLogsPage(initialSidebarVisible: false);
        break;
      case 'Tasks':
      case 'Task Progress':
        destination = const TaskProgressPage(initialSidebarVisible: false);
        break;
      case 'Reports':
        destination = const ReportsPage(initialSidebarVisible: false);
        break;
      case 'Inventory':
        destination = const InventoryPage(initialSidebarVisible: false);
        break;
      default:
        return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  void _setProjectId(int projectId) {
    print('🎯 Dashboard: Setting project ID to $projectId');
    setState(() {
      _currentProjectId = projectId;
    });
    print('📌 Dashboard: _currentProjectId is now $_currentProjectId');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isTablet = screenWidth > 600 && screenWidth <= 1024;
    final isMobile = screenWidth <= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Stack(
        children: [
          Row(
            children: [
              // Sidebar stays fixed on the left (only on desktop)
              if (isDesktop)
                Sidebar(
                  activePage: "Dashboard",
                  keepVisible: true,
                ),

              // Right area (header fixed, content scrollable)
              Expanded(
                child: Column(
                  children: [
                    // Header fixed at top of right area
                    DashboardHeader(
                      onMenuPressed: () {},
                    ),

                    // Scrollable content below header while sidebar stays put
                    Expanded(
                      child: SingleChildScrollView(
                        child: isMobile
                            ? _buildMobileLayout()
                            : isTablet
                            ? _buildTabletLayout()
                            : _buildDesktopLayout(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      // Bottom navigation bar for mobile only
      bottomNavigationBar: isMobile ? _buildBottomNavBar() : null,
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1935),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.dashboard, 'Dashboard', true),
                _buildNavItem(Icons.people, 'Workers', false),
                _buildNavItem(Icons.check_circle, 'Attendance', false),
                _buildNavItem(Icons.list_alt, 'Logs', false),
                _buildNavItem(Icons.more_horiz, 'More', false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    final color = isActive ? const Color(0xFFFF6F00) : Colors.white70;

    return InkWell(
      onTap: () {
        if (label == 'More') {
          _showMoreOptions();
        } else {
          _navigateToPage(label);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFF6F00).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0C1935),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _buildMoreOption(Icons.show_chart, 'Task Progress', 'Tasks'),
              _buildMoreOption(Icons.file_copy, 'Reports', 'Reports'),
              _buildMoreOption(Icons.inventory, 'Inventory', 'Inventory'),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOption(IconData icon, String title, String page) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        _navigateToPage(page);
      },
    );
  }

  // Mobile layout - Stack everything vertically
  Widget _buildMobileLayout() {
    print('📱 Building mobile layout, _currentProjectId: $_currentProjectId');
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActiveProject(key: _activeProjectKey, onProjectLoaded: _setProjectId),
          const SizedBox(height: 16),
          Tasks(projectId: _currentProjectId),
          const SizedBox(height: 16),
          if (_currentProjectId != null) ...[
            PhasesWidget(projectId: _currentProjectId!),
            const SizedBox(height: 16),
            Workers(projectId: _currentProjectId!),
          ] else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                '⚠️ No project ID available. _currentProjectId = $_currentProjectId',
                style: TextStyle(color: Colors.orange.shade900),
              ),
            ),
          const SizedBox(height: 16),
          // Calendar panel on mobile (compact version)
          const CalendarPanel(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // Tablet layout - Stack vertically with more spacing
  Widget _buildTabletLayout() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActiveProject(key: _activeProjectKey, onProjectLoaded: _setProjectId),
          const SizedBox(height: 18),
          Tasks(projectId: _currentProjectId),
          const SizedBox(height: 18),
          if (_currentProjectId != null) ...[
            PhasesWidget(projectId: _currentProjectId!),
            const SizedBox(height: 18),
            Workers(projectId: _currentProjectId!),
          ],
          const SizedBox(height: 18),
          const CalendarPanel(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Desktop layout - Side by side with calendar panel
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main content area (left/middle)
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ActiveProject(
                  key: _activeProjectKey,
                  onProjectLoaded: _setProjectId,
                ),
                const SizedBox(height: 20),
                Tasks(projectId: _currentProjectId),
                const SizedBox(height: 20),
                if (_currentProjectId != null) ...[
                  PhasesWidget(projectId: _currentProjectId!),
                  const SizedBox(height: 20),
                  Workers(projectId: _currentProjectId!),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // Right-side calendar panel
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [const CalendarPanel()]),
          ),
        ),
      ],
    );
  }
}
