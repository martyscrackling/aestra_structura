import 'package:flutter/material.dart';
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
      bottomNavigationBar: !isDesktop ? const _BottomNavBar(currentPage: 'Dashboard') : null,
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
    final padding = isExtraSmallPhone ? 8.0 : isSmallPhone ? 12.0 : 16.0;
    
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
                layout: isExtraSmallPhone ? LayoutType.extraSmallPhone : isSmallPhone ? LayoutType.smallPhone : LayoutType.mobile,
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
    final spacing = layout == LayoutType.extraSmallPhone ? 8.0
        : layout == LayoutType.smallPhone ? 12.0 
        : layout == LayoutType.mobile ? 16.0 
        : layout == LayoutType.tablet ? 20.0 
        : 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recent Projects
        const RecentProjects(),
        SizedBox(height: spacing),

        // Activity and Task Summary
        if (layout == LayoutType.extraSmallPhone || layout == LayoutType.smallPhone || layout == LayoutType.mobile) ...[
          const ActivityWidget(),
          SizedBox(height: spacing),
          const TaskSummaryWidget(),
          SizedBox(height: spacing),
        ] else if (layout == LayoutType.tablet)
          // Tablet: 1:1 ratio
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: ActivityWidget(),
              ),
              SizedBox(width: spacing),
              const Expanded(
                child: TaskSummaryWidget(),
              ),
            ],
          )
        else
          // Desktop: 2:1 ratio
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                flex: 2,
                child: ActivityWidget(),
              ),
              SizedBox(width: spacing),
              const Expanded(
                child: TaskSummaryWidget(),
              ),
            ],
          ),

        if (layout != LayoutType.extraSmallPhone && layout != LayoutType.smallPhone && layout != LayoutType.mobile) 
          SizedBox(height: spacing),

        // Task Today and Active Workers
        if (layout == LayoutType.extraSmallPhone || layout == LayoutType.smallPhone || layout == LayoutType.mobile) ...[
          const TaskTodayWidget(),
          SizedBox(height: spacing),
          const ActiveWorkersWidget(),
          const SizedBox(height: 80), // Space for bottom navbar
        ] else if (layout == LayoutType.tablet)
          // Tablet: 1:1 ratio
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: TaskTodayWidget(),
              ),
              SizedBox(width: spacing),
              const Expanded(
                child: ActiveWorkersWidget(),
              ),
            ],
          )
        else
          // Desktop: 2:1 ratio
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                flex: 2,
                child: TaskTodayWidget(),
              ),
              SizedBox(width: spacing),
              const Expanded(
                child: ActiveWorkersWidget(),
              ),
            ],
          ),
      ],
    );
  }
}

enum LayoutType {
  extraSmallPhone,
  smallPhone,
  mobile,
  tablet,
  desktop,
}

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
      {"label": "More", "icon": Icons.menu},
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1935),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: menuItems.map((item) {
              final isActive = item["label"] == currentPage;
              return _buildNavItem(
                context,
                item["label"] as String,
                item["icon"] as IconData,
                isActive,
              );
            }).toList(),
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
    if (label == "More") {
      return InkWell(
        onTap: () => _showMoreMenu(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white70,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => _navigateToPage(context, label),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF1396E9) : Colors.white70,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFF1396E9) : Colors.white70,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C1935),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMoreMenuItem(context, "Inventory", Icons.inventory_2_outlined),
            _buildMoreMenuItem(context, "Reports", Icons.insert_chart),
            _buildMoreMenuItem(context, "Settings", Icons.settings),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreMenuItem(BuildContext context, String label, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white70),
      ),
      onTap: () {
        Navigator.pop(context);
        _navigateToPage(context, label);
      },
    );
  }

  void _navigateToPage(BuildContext context, String label) {
    // Navigation logic would go here
    // For now, just print
    debugPrint('Navigate to: $label');
  }
}
