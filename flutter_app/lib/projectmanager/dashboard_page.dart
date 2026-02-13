import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/pm_dashboard_service.dart';
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

class PMDashboardPage extends StatefulWidget {
  const PMDashboardPage({super.key});

  @override
  State<PMDashboardPage> createState() => _PMDashboardPageState();
}

class _PMDashboardPageState extends State<PMDashboardPage> {
  static const _hasSeenWelcomeKey = 'pm_has_seen_dashboard_welcome';

  bool _isLoadingPrefs = true;
  bool _showWelcome = false;

  bool _isLoadingSummary = true;
  String? _summaryError;
  PmDashboardSummary? _summary;
  final PmDashboardService _dashboardService = PmDashboardService();

  @override
  void initState() {
    super.initState();
    _loadWelcomeState();
    _loadDashboardSummary();
  }

  Future<void> _loadDashboardSummary() async {
    setState(() {
      _isLoadingSummary = true;
      _summaryError = null;
    });

    try {
      final authService = AuthService();
      final userIdRaw = authService.currentUser?['user_id'];
      final userId = userIdRaw is int
          ? userIdRaw
          : int.tryParse(userIdRaw?.toString() ?? '');

      if (userId == null) {
        throw Exception('Missing user id');
      }

      final summary = await _dashboardService.fetchSummary(userId: userId);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _isLoadingSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _summary = null;
        _summaryError = e.toString();
        _isLoadingSummary = false;
      });
    }
  }

  Future<void> _loadWelcomeState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool(_hasSeenWelcomeKey) ?? false;
      if (!mounted) return;
      setState(() {
        _showWelcome = !hasSeen;
        _isLoadingPrefs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showWelcome = false;
        _isLoadingPrefs = false;
      });
    }
  }

  Future<void> _setHasSeenWelcomeAndMaybeNavigate(String? route) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasSeenWelcomeKey, true);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _showWelcome = false;
    });

    if (route != null) {
      context.go(route);
    }
  }

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
                        child: _buildBody(
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
              child: _buildBody(
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
              child: _buildBody(
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

  Widget _buildBody({required double screenWidth, required LayoutType layout}) {
    if (_isLoadingPrefs) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_showWelcome) {
      return _buildWelcomeEmptyState(layout: layout);
    }

    return _buildDashboardContent(screenWidth: screenWidth, layout: layout);
  }

  Widget _buildWelcomeEmptyState({required LayoutType layout}) {
    final isMobile =
        layout == LayoutType.extraSmallPhone ||
        layout == LayoutType.smallPhone ||
        layout == LayoutType.mobile;

    final titleSize = layout == LayoutType.extraSmallPhone
        ? 18.0
        : layout == LayoutType.smallPhone
        ? 20.0
        : isMobile
        ? 22.0
        : layout == LayoutType.tablet
        ? 24.0
        : 26.0;

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Structura',
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0C1935),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your dashboard is empty because this is a new account. Start by creating your first project, then add clients and workers to track progress here.',
            style: TextStyle(
              height: 1.3,
              color: Colors.grey[700],
              fontSize: isMobile ? 12 : 13,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () =>
                    _setHasSeenWelcomeAndMaybeNavigate('/projects'),
                icon: const Icon(Icons.add),
                label: const Text('Create Project'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C1935),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _setHasSeenWelcomeAndMaybeNavigate('/clients'),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Add Clients'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _setHasSeenWelcomeAndMaybeNavigate('/workforce'),
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Add Workers'),
              ),
              TextButton(
                onPressed: () => _setHasSeenWelcomeAndMaybeNavigate(null),
                child: const Text('Skip'),
              ),
            ],
          ),
          if (isMobile) const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildDashboardContent({
    required double screenWidth,
    required LayoutType layout,
  }) {
    if (_isLoadingSummary) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_summaryError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.10),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Failed to load dashboard data.\n$_summaryError',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _loadDashboardSummary,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C1935),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final summary = _summary;
    if (summary == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.10),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          'No dashboard data available.',
          style: TextStyle(color: Colors.grey[700]),
        ),
      );
    }

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
        RecentProjects(projects: summary.recentProjects),
        SizedBox(height: spacing),

        // Activity and Task Summary
        if (layout == LayoutType.extraSmallPhone ||
            layout == LayoutType.smallPhone ||
            layout == LayoutType.mobile) ...[
          ActivityWidget(series: summary.activitySeries),
          SizedBox(height: spacing),
          TaskSummaryWidget(
            totalProjects: summary.totalProjects,
            assignedTasks: summary.assignedTasks,
            totalTasks: summary.totalTasks,
            completionRate: summary.completionRate,
          ),
          SizedBox(height: spacing),
        ] else if (layout == LayoutType.tablet)
          // Tablet: 1:1 ratio
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: ActivityWidget(series: summary.activitySeries)),
              SizedBox(width: spacing),
              Expanded(
                child: TaskSummaryWidget(
                  totalProjects: summary.totalProjects,
                  assignedTasks: summary.assignedTasks,
                  totalTasks: summary.totalTasks,
                  completionRate: summary.completionRate,
                ),
              ),
            ],
          )
        else
          // Desktop: 2:1 ratio
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: ActivityWidget(series: summary.activitySeries),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: TaskSummaryWidget(
                  totalProjects: summary.totalProjects,
                  assignedTasks: summary.assignedTasks,
                  totalTasks: summary.totalTasks,
                  completionRate: summary.completionRate,
                ),
              ),
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
          TaskTodayWidget(tasksToday: summary.tasksToday),
          SizedBox(height: spacing),
          ActiveWorkersWidget(
            supervisorsCount: summary.supervisorsCount,
            fieldWorkersTotal: summary.fieldWorkersTotal,
            fieldWorkersByRole: summary.fieldWorkersByRole,
          ),
          const SizedBox(height: 80), // Space for bottom navbar
        ] else if (layout == LayoutType.tablet)
          // Tablet: 1:1 ratio
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: TaskTodayWidget(tasksToday: summary.tasksToday)),
              SizedBox(width: spacing),
              Expanded(
                child: ActiveWorkersWidget(
                  supervisorsCount: summary.supervisorsCount,
                  fieldWorkersTotal: summary.fieldWorkersTotal,
                  fieldWorkersByRole: summary.fieldWorkersByRole,
                ),
              ),
            ],
          )
        else
          // Desktop: 2:1 ratio
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TaskTodayWidget(tasksToday: summary.tasksToday),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: ActiveWorkersWidget(
                  supervisorsCount: summary.supervisorsCount,
                  fieldWorkersTotal: summary.fieldWorkersTotal,
                  fieldWorkersByRole: summary.fieldWorkersByRole,
                ),
              ),
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!rootContext.mounted) return;
          _navigateToPage(rootContext, label);
        });
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
