import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/account_settings_view.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/mobile_bottom_nav.dart';
import 'widgets/sidebar.dart';

class SupervisorSettingsPage extends StatefulWidget {
  const SupervisorSettingsPage({super.key});

  @override
  State<SupervisorSettingsPage> createState() => _SupervisorSettingsPageState();
}

class _SupervisorSettingsPageState extends State<SupervisorSettingsPage> {
  void _navigateToPage(String page) {
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
      case 'Test Time':
        context.go('/supervisor/test-time');
        break;
      case 'Settings':
        return;
      default:
        return;
    }
  }

  Widget _buildBottomNavBar() {
    return SupervisorMobileBottomNav(
      activeTab: SupervisorMobileTab.more,
      activeMorePage: 'Settings',
      onSelect: _navigateToPage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isMobile = screenWidth <= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          if (isDesktop)
            const Sidebar(activePage: 'Settings', keepVisible: true),
          Expanded(
            child: Column(
              children: [
                const DashboardHeader(title: 'Settings'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: isMobile
                        ? const EdgeInsets.only(bottom: 100)
                        : null,
                    child: const AccountSettingsView(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildBottomNavBar() : null,
    );
  }
}
