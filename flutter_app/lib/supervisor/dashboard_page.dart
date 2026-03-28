import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/active_project.dart';
import 'widgets/tasks.dart';
import 'widgets/workers.dart';
import 'widgets/phases.dart';
import 'widgets/mobile_bottom_nav.dart';
import '../services/auth_service.dart';
import '../services/app_config.dart';
import '../services/app_theme_tokens.dart';

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
  bool _showMobileDetails = false;
  final GlobalKey _activeProjectKey = GlobalKey();
  final Color _primary = AppColors.accent;
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
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 10 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.show_chart,
                  color: _primary,
                  size: isMobile ? 18 : 20,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Project Progress Overview',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: isMobile ? 14 : 15,
                    ),
                  ),
                ),
              ],
            ),
            if (!isMobile) const SizedBox(height: 4),
            if (!isMobile)
              Text(
                'Completion trend across assigned projects',
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            SizedBox(height: isMobile ? 10 : 14),
            if (_isLoadingProjectProgress)
              SizedBox(
                height: isMobile ? 150 : 180,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_projectProgressPoints.isEmpty)
              Container(
                height: isMobile ? 130 : 160,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  'No project progress data yet.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              )
            else
              SizedBox(
                height: isMobile ? 172 : 204,
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
                          reservedSize: 30,
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
                          reservedSize: isMobile ? 30 : 34,
                          getTitlesWidget: (value, axisMeta) {
                            final index = value.toInt();
                            if (index < 0 ||
                                index >= _projectProgressPoints.length) {
                              return const SizedBox.shrink();
                            }

                            final rawTitle =
                                _projectProgressPoints[index].projectName;
                            final shortTitle = rawTitle.length > 8
                                ? '${rawTitle.substring(0, 8)}...'
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
                        barWidth: 2.6,
                        isCurved: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                                radius: 2.6,
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
    switch (page) {
      case 'Dashboard':
        return; // Already on dashboard
      case 'Workers':
      case 'Worker Management':
        context.go('/supervisor/workers');
        break;
      case 'Attendance':
        context.go('/supervisor/attendance');
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
      default:
        return;
    }
  }

  void _setProjectId(int projectId) {
    setState(() {
      _currentProjectId = projectId;
    });
  }

  void _scrollToActiveProjects() {
    final targetContext = _activeProjectKey.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  Widget _buildScrollableActiveProjects({required double height}) {
    return ActiveProject(
      key: _activeProjectKey,
      onProjectLoaded: _setProjectId,
      scrollOnlyCards: true,
      cardsViewportHeight: height,
      compactCards: true,
      carouselWhenMultiple: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isTablet = screenWidth > 600 && screenWidth <= 1024;
    final isMobile = screenWidth <= 600;

    return Scaffold(
      backgroundColor: AppColors.surface,
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
                    const DashboardHeader(),

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
    return SupervisorMobileBottomNav(
      activeTab: SupervisorMobileTab.dashboard,
      onSelect: _navigateToPage,
    );
  }

  // Mobile layout - Stack everything vertically
  Widget _buildMobileLayout() {
    final viewHeight = MediaQuery.of(context).size.height;
    final activeProjectsHeight = (viewHeight * 0.28).clamp(220.0, 270.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDashboardProgressChart(true),
          const SizedBox(height: 10),
          _buildScrollableActiveProjects(height: activeProjectsHeight),
          const SizedBox(height: 10),
          Tasks(projectId: _currentProjectId),
          const SizedBox(height: 10),
          if (_currentProjectId != null) ...[
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _showMobileDetails = !_showMobileDetails;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: Color(0xFF0C1935),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Project details',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0C1935),
                          ),
                        ),
                      ),
                      Icon(
                        _showMobileDetails
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey[700],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              sizeCurve: Curves.easeOutCubic,
              crossFadeState: _showMobileDetails
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const SizedBox(height: 10),
                  PhasesWidget(projectId: _currentProjectId!),
                  const SizedBox(height: 10),
                  Workers(projectId: _currentProjectId!),
                ],
              ),
            ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a project to load details',
                    style: TextStyle(
                      color: Color(0xFF0C1935),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pick an active project above to view phases and workers.',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _scrollToActiveProjects,
                    icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                    label: const Text('Go to Active Projects'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0C1935),
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Tablet layout - Stack vertically with more spacing
  Widget _buildTabletLayout() {
    final viewHeight = MediaQuery.of(context).size.height;
    final activeProjectsHeight = (viewHeight * 0.3).clamp(240.0, 320.0);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDashboardProgressChart(false),
          const SizedBox(height: 12),
          _buildScrollableActiveProjects(height: activeProjectsHeight),
          const SizedBox(height: 12),
          Tasks(projectId: _currentProjectId),
          const SizedBox(height: 12),
          if (_currentProjectId != null) ...[
            PhasesWidget(projectId: _currentProjectId!),
            const SizedBox(height: 12),
            Workers(projectId: _currentProjectId!),
          ],
          const SizedBox(height: 12),
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
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: _buildDashboardProgressChart(false),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 10, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScrollableActiveProjects(height: 390),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 18, 18, 18),
                child: Column(
                  children: [
                    Tasks(projectId: _currentProjectId),
                    const SizedBox(height: 12),
                    if (_currentProjectId != null) ...[
                      PhasesWidget(projectId: _currentProjectId!),
                      const SizedBox(height: 12),
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
