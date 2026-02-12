import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'sidebar.dart';
import 'dashboard_header.dart';

class ResponsivePageLayout extends StatelessWidget {
  final String currentPage;
  final String title;
  final Widget child;
  final EdgeInsets? padding;

  const ResponsivePageLayout({
    super.key,
    required this.currentPage,
    required this.title,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final isExtraSmallPhone = screenWidth <= 320;
    final isSmallPhone = screenWidth < 375;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: isMobile
          ? _buildMobileLayout(context, isExtraSmallPhone, isSmallPhone)
          : isTablet
          ? _buildTabletLayout(context)
          : _buildDesktopLayout(context, screenWidth),
      bottomNavigationBar: !isDesktop
          ? _BottomNavBar(currentPage: currentPage)
          : null,
    );
  }

  Widget _buildDesktopLayout(BuildContext context, double screenWidth) {
    final isLargeScreen = screenWidth > 1440;
    final contentPadding = _getContentPadding(screenWidth);

    return Row(
      children: [
        Sidebar(currentPage: currentPage),
        Expanded(
          child: Column(
            children: [
              DashboardHeader(title: title),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isLargeScreen ? 1400 : double.infinity,
                    ),
                    child: SingleChildScrollView(
                      padding: padding ?? EdgeInsets.all(contentPadding),
                      child: child,
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
    final contentPadding = _getContentPadding(
      MediaQuery.of(context).size.width,
    );

    return Column(
      children: [
        DashboardHeader(title: title),
        Expanded(
          child: SingleChildScrollView(
            padding: padding ?? EdgeInsets.all(contentPadding),
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    bool isExtraSmallPhone,
    bool isSmallPhone,
  ) {
    final contentPadding = _getContentPadding(
      MediaQuery.of(context).size.width,
    );

    return Column(
      children: [
        DashboardHeader(title: title),
        Expanded(
          child: SingleChildScrollView(
            padding: padding ?? EdgeInsets.all(contentPadding),
            child: child,
          ),
        ),
      ],
    );
  }

  double _getContentPadding(double screenWidth) {
    if (screenWidth <= 320) return 8.0;
    if (screenWidth < 375) return 12.0;
    if (screenWidth < 768) return 16.0;
    if (screenWidth < 1024) return 20.0;
    if (screenWidth > 1440) return 32.0;
    return 24.0;
  }
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
          print('Bottom nav tapped: $label'); // Debug log
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
