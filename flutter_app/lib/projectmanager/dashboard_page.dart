import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/recent_projects.dart';
import 'widgets/activity_widget.dart';
import 'widgets/task_summary_widget.dart';
import 'widgets/task_today_widget.dart';
import 'widgets/active_workers_widget.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PMDashboardPage(),
    ),
  );
}

class PMDashboardPage extends StatelessWidget {
  const PMDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Enhanced breakpoints for all screen sizes
    final isSmallPhone = screenWidth < 375;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: isMobile
          ? _buildMobileLayout(context, isSmallPhone)
          : isTablet
          ? _buildTabletLayout(context)
          : _buildDesktopLayout(context, screenWidth),
      bottomNavigationBar: !isDesktop
          ? const _BottomNavBar(currentPage: 'Dashboard')
          : null,
    );
  }

  Widget _buildDesktopLayout(BuildContext context, double screenWidth) {
    // Constrain max width for large screens
    final isLargeScreen = screenWidth > 1440;
    final contentPadding = isLargeScreen ? 32.0 : 24.0;

    return Row(
      children: [
        // Sidebar stays fixed on the left
        const Sidebar(currentPage: 'Dashboard'),

        // Right area (header fixed, content scrollable)
        Expanded(
          child: Column(
            children: [
              // Header fixed at top
              const DashboardHeader(),

              // Main content area
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isLargeScreen ? 1400 : double.infinity,
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(contentPadding),
                        child: _buildDashboardContent(
                          screenWidth: screenWidth,
                          layout: LayoutType.desktop,
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
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Column(
      children: [
        // Header fixed at top
        const DashboardHeader(),

        // Main content area
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildDashboardContent(
                screenWidth: MediaQuery.of(context).size.width,
                layout: LayoutType.tablet,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, bool isSmallPhone) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isExtraSmallPhone = screenWidth <= 320;
    final padding = isExtraSmallPhone
        ? 8.0
        : isSmallPhone
        ? 12.0
        : 16.0;

    return Column(
      children: [
        // Header fixed at top
        const DashboardHeader(),

        // Main content area
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: _buildDashboardContent(
                screenWidth: screenWidth,
                layout: isExtraSmallPhone
                    ? LayoutType.extraSmallPhone
                    : isSmallPhone
                    ? LayoutType.smallPhone
                    : LayoutType.mobile,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardContent({
    required double screenWidth,
    required LayoutType layout,
  }) {
    final spacing = layout == LayoutType.extraSmallPhone
        ? 8.0
        : layout == LayoutType.smallPhone
        ? 12.0
        : layout == LayoutType.mobile
        ? 16.0
        : layout == LayoutType.tablet
        ? 20.0
        : 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recent Projects
        const RecentProjects(),
        SizedBox(height: spacing),

        // Activity and Task Summary
        if (layout == LayoutType.extraSmallPhone ||
            layout == LayoutType.smallPhone ||
            layout == LayoutType.mobile) ...[
          const ActivityWidget(),
          SizedBox(height: spacing),
          const TaskSummaryWidget(),
          SizedBox(height: spacing),
        ] else if (layout == LayoutType.tablet)
          // Tablet: 1:1 ratio
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: ActivityWidget()),
              SizedBox(width: spacing),
              const Expanded(child: TaskSummaryWidget()),
            ],
          )
        else
          // Desktop: 2:1 ratio
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(flex: 2, child: ActivityWidget()),
              SizedBox(width: spacing),
              const Expanded(child: TaskSummaryWidget()),
            ],
          ),

        if (layout != LayoutType.extraSmallPhone &&
            layout != LayoutType.smallPhone &&
            layout != LayoutType.mobile)
          SizedBox(height: spacing),

        // Task Today and Active Workers
        if (layout == LayoutType.extraSmallPhone ||
            layout == LayoutType.smallPhone ||
            layout == LayoutType.mobile) ...[
          const TaskTodayWidget(),
          SizedBox(height: spacing),
          const ActiveWorkersWidget(),
          const SizedBox(height: 80), // Space for bottom navbar
        ] else if (layout == LayoutType.tablet)
          // Tablet: 1:1 ratio
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: TaskTodayWidget()),
              SizedBox(width: spacing),
              const Expanded(child: ActiveWorkersWidget()),
            ],
          )
        else
          // Desktop: 2:1 ratio
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(flex: 2, child: TaskTodayWidget()),
              SizedBox(width: spacing),
              const Expanded(child: ActiveWorkersWidget()),
            ],
          ),
      ],
    );
  }
}

enum LayoutType { extraSmallPhone, smallPhone, mobile, tablet, desktop }

class _BottomNavBar extends StatelessWidget {
  final String currentPage;

  const _BottomNavBar({required this.currentPage});

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      {"label": "Dashboard", "icon": Icons.dashboard},
      {"label": "Projects", "icon": Icons.folder},
      {"label": "Workforce", "icon": Icons.people},
      {"label": "Clients", "icon": Icons.person},
      {"label": "More", "icon": Icons.more_horiz},
    ];

    // Check if current page is in the "More" submenu
    final morePages = ['Inventory', 'Reports', 'Settings'];
    final isOnMorePage = morePages.contains(currentPage);

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
              children: menuItems.map((item) {
                final label = item["label"] as String;
                final isActive =
                    label == currentPage || (label == "More" && isOnMorePage);
                return _buildNavItem(
                  context,
                  label,
                  item["icon"] as IconData,
                  isActive,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    String label,
    IconData icon,
    bool isActive,
  ) {
    final color = isActive ? const Color(0xFFFF6F00) : Colors.white70;

    return InkWell(
      onTap: () {
        if (label == "More") {
          _showMoreMenu(context);
        } else {
          _navigateToPage(context, label);
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

  void _showMoreMenu(BuildContext context) {
    final rootContext = context;
    showModalBottomSheet(
      context: rootContext,
      backgroundColor: const Color(0xFF0C1935),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMoreMenuItem(
              rootContext,
              sheetContext,
              "Inventory",
              Icons.inventory_2_outlined,
            ),
            _buildMoreMenuItem(
              rootContext,
              sheetContext,
              "Reports",
              Icons.insert_chart,
            ),
            _buildMoreMenuItem(
              rootContext,
              sheetContext,
              "Settings",
              Icons.settings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreMenuItem(
    BuildContext rootContext,
    BuildContext sheetContext,
    String label,
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(label, style: const TextStyle(color: Colors.white70)),
      onTap: () {
        Navigator.pop(sheetContext);
        Future.microtask(() => _navigateToPage(rootContext, label));
      },
    );
  }

  void _navigateToPage(BuildContext context, String label) {
    final routeMap = {
      'Dashboard': '/dashboard',
      'Projects': '/projects',
      'Workforce': '/workforce',
      'Clients': '/clients',
      'Inventory': '/inventory',
      'Reports': '/reports',
      'Settings': '/settings',
    };

    final route = routeMap[label];
    if (route != null) {
      context.go(route);
    }
  }
}
