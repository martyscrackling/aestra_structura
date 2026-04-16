import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/active_project.dart';
import 'widgets/mobile_bottom_nav.dart';

class AllProjectsPage extends StatefulWidget {
  final bool initialSidebarVisible;

  const AllProjectsPage({super.key, this.initialSidebarVisible = false});

  @override
  State<AllProjectsPage> createState() => _AllProjectsPageState();
}

class _AllProjectsPageState extends State<AllProjectsPage> {
  final GlobalKey _activeProjectKey = GlobalKey();

  void _navigateToPage(String page) {
    switch (page) {
      case 'Dashboard':
        context.go('/supervisor');
        break;
      case 'Projects':
        return; // Already on projects
      case 'Workers':
<<<<<<< HEAD
=======
      case 'Worker Management':
>>>>>>> parent of df03275 (Revert "push ko na par")
        context.go('/supervisor/workers');
        break;
      case 'Attendance':
        context.go('/supervisor/attendance');
        break;
      case 'Tasks':
<<<<<<< HEAD
=======
      case 'Task Progress':
>>>>>>> parent of df03275 (Revert "push ko na par")
        context.go('/supervisor/task-progress');
        break;
      case 'Reports':
        context.go('/supervisor/reports');
        break;
      case 'Inventory':
        context.go('/supervisor/inventory');
        break;
      default:
        return;
    }
  }

  Widget _buildBottomNavBar() {
    return SupervisorMobileBottomNav(
      activeTab: SupervisorMobileTab.projects,
      onSelect: _navigateToPage,
    );
  }

  Widget _buildMobileLayout() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ActiveProject(key: _activeProjectKey, enableSelection: false),
    );
  }

  Widget _buildTabletLayout() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ActiveProject(key: _activeProjectKey, enableSelection: false),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ActiveProject(key: _activeProjectKey, enableSelection: false),
    );
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
              if (isDesktop) Sidebar(activePage: 'Projects', keepVisible: true),
              Expanded(
                child: Column(
                  children: [
                    DashboardHeader(onMenuPressed: () {}, title: 'Projects'),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: isMobile
                            ? const EdgeInsets.only(bottom: 100)
                            : null,
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
      bottomNavigationBar: isMobile ? _buildBottomNavBar() : null,
    );
  }
}
