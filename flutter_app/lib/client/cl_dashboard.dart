import 'package:flutter/material.dart';
import 'widgets/top_controls.dart';
import 'widgets/projects_grid.dart';
import 'models/project_item.dart';
import 'widgets/dashboard_header.dart';
import '../services/client_dashboard_service.dart';
import '../services/auth_service.dart';
import '../services/new_account_tutorial.dart';
import 'package:go_router/go_router.dart';

class ClDashboardPage extends StatefulWidget {
  const ClDashboardPage({super.key});

  @override
  State<ClDashboardPage> createState() => _ClDashboardPageState();
}

class _ClDashboardPageState extends State<ClDashboardPage> {
  static const Duration _newAccountWindow = Duration(days: 14);
  static const String _clientTutorialStepKey = 'client_quick_tour_step';
  static const String _clientTutorialDismissedKey = 'client_quick_tour_dismissed';
  static const String _clientTutorialResumePendingKey =
      'client_quick_tour_resume_pending';
  final _service = ClientDashboardService();
  late Future<List<ProjectItem>> _future;
  bool _isCompletingQuickTour = false;
  bool _hasAutoResumedTutorial = false;
  static const List<TutorialStepItem> _clientTutorialSteps = [
    TutorialStepItem(
      title: 'Step 1: View your assigned projects',
      description: 'Review project cards and overall progress from your dashboard.',
      actionLabel: 'Open Dashboard',
      route: '/client',
    ),
    TutorialStepItem(
      title: 'Step 2: Open project details',
      description: 'Check phase status, subtasks, and completion updates.',
      actionLabel: 'Stay Here',
      route: '/client',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ProjectItem>> _load() async {
    final cards = await _service.fetchClientProjects();
    return cards
        .map(
          (p) => ProjectItem(
            projectId: p.projectId,
            title: p.title,
            location: p.location,
            progress: p.progress,
            startDate: p.startDate,
            endDate: p.endDate,
            tasksCompleted: p.tasksCompleted,
            totalTasks: p.totalTasks,
            imageUrl: p.imageUrl,
          ),
        )
        .toList(growable: false);
  }

  bool _shouldShowQuickTutorialCard() {
    final user = AuthService().currentUser;
    if (user == null) return false;
    if (user['role']?.toString() != 'Client') return false;
    if (user['has_completed_quick_tour'] == true) return false;
    if (user[_clientTutorialDismissedKey] == true) return false;
    final createdAtRaw = user['created_at']?.toString();
    if (createdAtRaw == null || createdAtRaw.trim().isEmpty) return true;
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) return true;
    return DateTime.now().difference(createdAt.toLocal()) <= _newAccountWindow;
  }

  int _currentTutorialStepIndex() {
    final raw = AuthService().currentUser?[_clientTutorialStepKey];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  Future<void> _completeQuickTourAndGo(String route) async {
    if (_isCompletingQuickTour) return;
    setState(() => _isCompletingQuickTour = true);
    final authService = AuthService();
    final nextStep = _currentTutorialStepIndex() + 1;
    final hasMoreSteps = nextStep < _clientTutorialSteps.length;
    await authService.updateLocalUserFields({
      _clientTutorialStepKey: nextStep,
      _clientTutorialDismissedKey: false,
      _clientTutorialResumePendingKey: hasMoreSteps,
    });
    if (!hasMoreSteps) {
      await authService.markQuickTourCompleted();
    }
    if (!mounted) return;
    setState(() => _isCompletingQuickTour = false);
    context.go(route);
  }

  Future<void> _startTutorial() async {
    await AuthService().updateLocalUserFields({
      _clientTutorialDismissedKey: false,
      _clientTutorialResumePendingKey: false,
    });
    await showNewAccountTutorialDialog(
      context: context,
      roleLabel: 'Client',
      steps: _clientTutorialSteps,
      startIndex: _currentTutorialStepIndex(),
      onStepAction: _completeQuickTourAndGo,
    );
  }

  void _maybeAutoResumeTutorial() {
    if (_hasAutoResumedTutorial) return;
    final currentStep = _currentTutorialStepIndex();
    if (currentStep <= 0 || currentStep >= _clientTutorialSteps.length) return;
    final resumePending =
        AuthService().currentUser?[_clientTutorialResumePendingKey] == true;
    if (!resumePending) return;
    if (!_shouldShowQuickTutorialCard()) return;
    _hasAutoResumedTutorial = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AuthService().updateLocalUserFields({
        _clientTutorialResumePendingKey: false,
      });
      _startTutorial();
    });
  }

  Future<void> _skipTutorialForNow() async {
    if (_isCompletingQuickTour) return;
    setState(() => _isCompletingQuickTour = true);
    await AuthService().updateLocalUserFields({
      _clientTutorialDismissedKey: true,
      _clientTutorialResumePendingKey: false,
    });
    if (!mounted) return;
    setState(() => _isCompletingQuickTour = false);
  }

  @override
  Widget build(BuildContext context) {
    _maybeAutoResumeTutorial();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Column(
        children: [
          const ClientDashboardHeader(title: 'Projects'),
          Expanded(
            child: FutureBuilder<List<ProjectItem>>(
              future: _future,
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <ProjectItem>[];

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _future = _load();
                    });
                    await _future;
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 24,
                      vertical: isMobile ? 16 : 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_shouldShowQuickTutorialCard()) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE3E8F2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.explore_outlined,
                                  color: Color(0xFF0C1935),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'New account detected. Press Start Tutorial to look around your Client dashboard.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _isCompletingQuickTour
                                      ? null
                                      : _startTutorial,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF0C1935),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text('Start Tutorial'),
                                ),
                                TextButton(
                                  onPressed: _isCompletingQuickTour
                                      ? null
                                      : _skipTutorialForNow,
                                  child: const Text('Skip for now'),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isMobile ? 14 : 16),
                        ],
                        const TopControls(),
                        SizedBox(height: isMobile ? 16 : 18),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Center(child: CircularProgressIndicator())
                        else if (snapshot.hasError)
                          const Text(
                            'Unable to load projects.',
                            style: TextStyle(color: Color(0xFF6B7280)),
                          )
                        else if (items.isEmpty)
                          const Text(
                            'No projects found for this account.',
                            style: TextStyle(color: Color(0xFF6B7280)),
                          )
                        else
                          ProjectsGrid(items: items),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
