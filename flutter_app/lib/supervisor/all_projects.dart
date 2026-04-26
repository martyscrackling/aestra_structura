import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'supervisor_inbox_nav.dart';
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
      case 'Settings':
        context.go('/supervisor/settings');
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

  Widget _buildMobileLayout({required ActiveProject child}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }

  Widget _buildTabletLayout({required ActiveProject child}) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _buildDesktopLayout({required ActiveProject child}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = GoRouterState.of(context).uri.queryParameters;
    final activeProject = ActiveProject(
      key: _activeProjectKey,
      enableSelection: false,
      deepLinkProjectId: parseInboxId(q['project_id'] ?? q['project']),
      deepLinkPhaseId: parseInboxId(q['phase_id']),
      deepLinkSubtaskId: parseInboxId(q['subtask_id']),
    );

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
                            ? _buildMobileLayout(child: activeProject)
                            : isTablet
                            ? _buildTabletLayout(child: activeProject)
                            : _buildDesktopLayout(child: activeProject),
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
