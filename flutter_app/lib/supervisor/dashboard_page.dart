import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/active_project.dart';
import 'widgets/tasks.dart';
import 'widgets/workers.dart';
import 'widgets/phases.dart';
import 'workers_management.dart';
import 'attendance_page.dart';
import 'daily_logs.dart';
import 'task_progress.dart';
import 'reports.dart';
import 'inventory.dart';
import '../services/auth_service.dart';
import '../services/app_config.dart';

class _ProjectProgressPoint {
  const _ProjectProgressPoint({
    required this.projectName,
    required this.progress,
  });

  final String projectName;
  final int progress;
}

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
  final Color _primary = const Color(0xFFFF6F00);
  List<_ProjectProgressPoint> _projectProgressPoints = const [];
  bool _isLoadingProjectProgress = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadProjectProgress);
  }

  Future<void> _loadProjectProgress() async {
    try {
      final authService = AuthService();
      final userId = authService.currentUser?['user_id'];
      final supervisorId = authService.currentUser?['supervisor_id'];
      final fallbackProjectId = authService.currentUser?['project_id'];
      final scopeSuffix = userId != null ? '&user_id=$userId' : '';

      if (supervisorId == null && fallbackProjectId == null) {
        if (!mounted) return;
        setState(() {
          _projectProgressPoints = const [];
          _isLoadingProjectProgress = false;
        });
        return;
      }

      late final http.Response projectsResponse;
      if (supervisorId != null) {
        projectsResponse = await http.get(
          AppConfig.apiUri('projects/?supervisor_id=$supervisorId$scopeSuffix'),
        );
      } else {
        final projectUrl = userId != null
            ? 'projects/$fallbackProjectId/?user_id=$userId'
            : 'projects/$fallbackProjectId/';
        projectsResponse = await http.get(AppConfig.apiUri(projectUrl));
      }

      if (projectsResponse.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _projectProgressPoints = const [];
          _isLoadingProjectProgress = false;
        });
        return;
      }

      final decoded = jsonDecode(projectsResponse.body);
      final projects = _parseProjectsPayload(decoded);

      final List<_ProjectProgressPoint> progressPoints = [];
      for (final project in projects) {
        final projectIdRaw = project['project_id'];
        if (projectIdRaw == null) continue;

        final int projectId = projectIdRaw is int
            ? projectIdRaw
            : int.tryParse(projectIdRaw.toString()) ?? -1;
        if (projectId <= 0) continue;

        final projectName =
            (project['project_name'] as String?)?.trim().isNotEmpty == true
            ? project['project_name'] as String
            : 'Project $projectId';

        final phasesUrl = userId != null
            ? 'phases/?project_id=$projectId&user_id=$userId'
            : 'phases/?project_id=$projectId';

        try {
          final phasesResponse = await http.get(AppConfig.apiUri(phasesUrl));
          if (phasesResponse.statusCode != 200) {
            progressPoints.add(
              _ProjectProgressPoint(projectName: projectName, progress: 0),
            );
            continue;
          }

          final List<dynamic> phasesPayload =
              jsonDecode(phasesResponse.body) as List<dynamic>;
          final progress = _calculateProjectProgress(phasesPayload);
          progressPoints.add(
            _ProjectProgressPoint(projectName: projectName, progress: progress),
          );
        } catch (_) {
          progressPoints.add(
            _ProjectProgressPoint(projectName: projectName, progress: 0),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _projectProgressPoints = progressPoints;
        _isLoadingProjectProgress = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _projectProgressPoints = const [];
        _isLoadingProjectProgress = false;
      });
    }
  }

  List<Map<String, dynamic>> _parseProjectsPayload(dynamic payload) {
    if (payload is List) {
      return payload
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (payload is Map<String, dynamic>) {
      return [Map<String, dynamic>.from(payload)];
    }
    return [];
  }

  int _calculateProjectProgress(List<dynamic> phasesPayload) {
    int totalSubtasks = 0;
    int completedSubtasks = 0;

    for (final phase in phasesPayload) {
      final phaseMap = phase as Map<String, dynamic>;
      final subtasks = (phaseMap['subtasks'] as List<dynamic>?) ?? const [];
      totalSubtasks += subtasks.length;

      for (final subtask in subtasks) {
        final subtaskMap = subtask as Map<String, dynamic>;
        if (subtaskMap['status'] == 'completed') {
          completedSubtasks++;
        }
      }
    }

    if (totalSubtasks == 0) return 0;
    return ((completedSubtasks / totalSubtasks) * 100).round();
  }

  Widget _buildDashboardProgressChart(bool isMobile) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: _primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Project Progress Overview',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: isMobile ? 15 : 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Completion trend across assigned projects',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            if (_isLoadingProjectProgress)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_projectProgressPoints.isEmpty)
              Container(
                height: 180,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  'No project progress data yet.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              )
            else
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 100,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 20,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: Colors.grey[300], strokeWidth: 1),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        left: BorderSide(color: Colors.grey[300]!, width: 1),
                        bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                        right: BorderSide.none,
                        top: BorderSide.none,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 34,
                          interval: 20,
                          getTitlesWidget: (value, _) => Text(
                            '${value.toInt()}%',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          reservedSize: 38,
                          getTitlesWidget: (value, axisMeta) {
                            final index = value.toInt();
                            if (index < 0 ||
                                index >= _projectProgressPoints.length) {
                              return const SizedBox.shrink();
                            }

                            final rawTitle =
                                _projectProgressPoints[index].projectName;
                            final shortTitle = rawTitle.length > 10
                                ? '${rawTitle.substring(0, 10)}...'
                                : rawTitle;

                            return SideTitleWidget(
                              meta: axisMeta,
                              angle: -0.45,
                              child: Text(
                                shortTitle,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => spots
                            .map((spot) {
                              final index = spot.x.toInt();
                              if (index < 0 ||
                                  index >= _projectProgressPoints.length) {
                                return null;
                              }
                              final item = _projectProgressPoints[index];
                              return LineTooltipItem(
                                '${item.projectName}\n${item.progress}%',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              );
                            })
                            .whereType<LineTooltipItem>()
                            .toList(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          _projectProgressPoints.length,
                          (index) => FlSpot(
                            index.toDouble(),
                            _projectProgressPoints[index].progress.toDouble(),
                          ),
                        ),
                        color: _primary,
                        barWidth: 3,
                        isCurved: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                                radius: 3,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: _primary,
                              ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: _primary.withOpacity(0.12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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

  Widget _buildScrollableActiveProjects({required double height}) {
    return ActiveProject(
      key: _activeProjectKey,
      onProjectLoaded: _setProjectId,
      scrollOnlyCards: true,
      cardsViewportHeight: height,
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
              // Sidebar stays fixed on the left (only on desktop)
              if (isDesktop)
                Sidebar(activePage: "Dashboard", keepVisible: true),

              // Right area (header fixed, content scrollable)
              Expanded(
                child: Column(
                  children: [
                    // Header fixed at top of right area
                    DashboardHeader(onMenuPressed: () {}),

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
          _buildDashboardProgressChart(true),
          const SizedBox(height: 16),
          _buildScrollableActiveProjects(height: 380),
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
          _buildDashboardProgressChart(false),
          const SizedBox(height: 18),
          _buildScrollableActiveProjects(height: 450),
          const SizedBox(height: 18),
          Tasks(projectId: _currentProjectId),
          const SizedBox(height: 18),
          if (_currentProjectId != null) ...[
            PhasesWidget(projectId: _currentProjectId!),
            const SizedBox(height: 18),
            Workers(projectId: _currentProjectId!),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Desktop layout - Side by side with tasks panel on the right
  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: _buildDashboardProgressChart(false),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScrollableActiveProjects(height: 640),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Tasks(projectId: _currentProjectId),
                    const SizedBox(height: 20),
                    if (_currentProjectId != null) ...[
                      PhasesWidget(projectId: _currentProjectId!),
                      const SizedBox(height: 20),
                      Workers(projectId: _currentProjectId!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
