import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'modals/task_details_modal.dart';
import 'modals/phase_modal.dart';
import 'subtask_manage.dart';

class Phase {
  final int phaseId;
  final int projectId;
  final String phaseName;
  final String? description;
  final int? daysDuration;
  final String status;
  final List<Subtask> subtasks;
  final DateTime? startDate;
  final DateTime? endDate;

  Phase({
    required this.phaseId,
    required this.projectId,
    required this.phaseName,
    this.description,
    this.daysDuration,
    required this.status,
    required this.subtasks,
    this.startDate,
    this.endDate,
  });

  factory Phase.fromJson(Map<String, dynamic> json) {
    return Phase(
      phaseId: json['phase_id'],
      projectId: json['project_id'],
      phaseName: json['phase_name'],
      description: json['description'],
      daysDuration: json['days_duration'],
      status: json['status'],
      subtasks:
          (json['subtasks'] as List<dynamic>?)
              ?.map((s) => Subtask.fromJson(s))
              .toList() ??
          [],
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : null,
    );
  }

  // Calculate progress for this phase based on subtasks (matching task_progress.dart)
  double calculateProgress() {
    if (subtasks.isEmpty) return 0.0;
    final completed = subtasks.where((s) => s.status == 'completed').length;
    return completed / subtasks.length;
  }
}

class Subtask {
  final int subtaskId;
  final String title;
  final String status;

  Subtask({required this.subtaskId, required this.title, required this.status});

  factory Subtask.fromJson(Map<String, dynamic> json) {
    return Subtask(
      subtaskId: json['subtask_id'],
      title: json['title'],
      status: json['status'],
    );
  }
}

class WeeklyTask {
  final String weekTitle;
  final String description;
  final String status;
  final String date;
  final double progress;

  WeeklyTask({
    required this.weekTitle,
    required this.description,
    required this.status,
    required this.date,
    required this.progress,
  });
}

class ProjectTaskDetailsPage extends StatefulWidget {
  final String projectTitle;
  final String projectLocation;
  final String projectImage;
  final double progress;
  final String? budget;
  final int projectId;

  const ProjectTaskDetailsPage({
    super.key,
    required this.projectTitle,
    required this.projectLocation,
    required this.projectImage,
    required this.progress,
    this.budget,
    required this.projectId,
  });

  @override
  State<ProjectTaskDetailsPage> createState() => _ProjectTaskDetailsPageState();
}

class _ProjectTaskDetailsPageState extends State<ProjectTaskDetailsPage> {
  List<Phase> _phases = [];
  bool _isLoading = true;
  String? _error;

  // Calculate overall project progress based on phases (matching task_progress.dart)
  double _calculateProjectProgress() {
    if (_phases.isEmpty) return 0.0;

    // Count all subtasks across all phases
    int totalSubtasks = 0;
    int completedSubtasks = 0;

    for (var phase in _phases) {
      totalSubtasks += phase.subtasks.length;
      completedSubtasks += phase.subtasks
          .where((s) => s.status == 'completed')
          .length;
    }

    if (totalSubtasks == 0) return 0.0;
    return completedSubtasks / totalSubtasks;
  }

  @override
  void initState() {
    super.initState();
    _fetchPhases();
  }

  Future<void> _fetchPhases() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://127.0.0.1:8000/api/phases/?project_id=${widget.projectId}',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _phases = data.map((json) => Phase.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load phases';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Phase> get _todoPhases =>
      _phases.where((p) => p.status != 'completed').toList();
  List<Phase> get _completedPhases =>
      _phases.where((p) => p.status == 'completed').toList();

  static final List<WeeklyTask> _todoTasks = [
    WeeklyTask(
      weekTitle: 'Week 5 - Pre-Construction & Site Prep',
      description:
          'Conduct site survey, clearing, excavation, soil compaction, and set up temporary facilities.',
      status: 'In-Process',
      date: 'Sept 28',
      progress: 0.65,
    ),
    WeeklyTask(
      weekTitle: 'Week 6 - Foundation',
      description:
          'Build foundation by reinforcing, pouring, curing, and inspecting footings and foundation walls.',
      status: 'In-Process',
      date: 'Oct 5',
      progress: 0.45,
    ),
    WeeklyTask(
      weekTitle: 'Week 7 - Structural Framework',
      description:
          'Construct the structural framework, including beams, columns, and slab preparation.',
      status: 'In-Process',
      date: 'Oct 12',
      progress: 0.30,
    ),
    WeeklyTask(
      weekTitle: 'Week 8 - Superstructure & Roofing',
      description:
          'Complete slab concreting, masonry works, install frames, set roof trusses, and finish with roofing and cleanup.',
      status: 'In-Process',
      date: 'Oct 19',
      progress: 0.15,
    ),
  ];

  static final List<WeeklyTask> _finishedTasks = [
    WeeklyTask(
      weekTitle: 'Week 1 - Pre-Construction & Site Prep',
      description:
          'Conduct site survey, clearing, excavation, soil compaction, and set up temporary facilities.',
      status: 'Completed',
      date: 'Completed',
      progress: 1.0,
    ),
    WeeklyTask(
      weekTitle: 'Week 2 - Foundation',
      description:
          'Build foundation by reinforcing, pouring, curing, and inspecting footings and foundation walls.',
      status: 'Completed',
      date: 'Completed',
      progress: 1.0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          const Sidebar(currentPage: 'Projects'),
          Expanded(
            child: Column(
              children: [
                const DashboardHeader(title: 'Projects'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back button and project header
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back),
                              color: const Color(0xFF0C1935),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.projectTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0C1935),
                                    ),
                                  ),
                                  Text(
                                    widget.projectLocation,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Project info badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _calculateProjectProgress() >= 1
                                    ? const Color(0xFFE5F8ED)
                                    : const Color(0xFFFFF2E8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${(_calculateProjectProgress() * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _calculateProjectProgress() >= 1
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFFF7A18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (widget.budget != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.account_balance_wallet_outlined,
                                      size: 16,
                                      color: Color(0xFF2E7D32),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '₱ ${widget.budget}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: AssetImage(widget.projectImage),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Tabs
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _TabButton(
                                label: 'Add Phase',
                                icon: Icons.list,
                                isSelected: true,
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => PhaseModal(
                                      projectTitle: widget.projectTitle,
                                      projectId: widget.projectId,
                                    ),
                                  ).then((_) => _fetchPhases());
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Search and Filter
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 18,
                                  ),
                                  hintText: 'Search task...',
                                  hintStyle: const TextStyle(fontSize: 13),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0C1935),
                                side: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.filter_list, size: 18),
                              label: const Text('Filter'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0C1935),
                                side: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.sort, size: 18),
                              label: const Text('Sort: Date Created'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Loading state
                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_error != null)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Text(
                                'Error: $_error',
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          )
                        else if (_phases.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(60),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No phases yet, add first',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else ...[
                          // To Do Section (Phases)
                          _PhaseSection(
                            title: 'To Do',
                            count: _todoPhases.length,
                            phases: _todoPhases,
                            onRefresh: _fetchPhases,
                          ),
                          const SizedBox(height: 24),

                          // Finished Section (Phases)
                          _PhaseSection(
                            title: 'Finished',
                            count: _completedPhases.length,
                            phases: _completedPhases,
                            onRefresh: _fetchPhases,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.transparent,
        foregroundColor: isSelected ? Colors.white : const Color(0xFF6B7280),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _TaskSection extends StatelessWidget {
  final String title;
  final int count;
  final List<WeeklyTask> tasks;

  const _TaskSection({
    required this.title,
    required this.count,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  '$title /$count',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0C1935),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 20),
                  color: const Color(0xFF6B7280),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz, size: 20),
                  color: const Color(0xFF6B7280),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...tasks.map((task) => _WeeklyTaskCard(task: task)),
        ],
      ),
    );
  }
}

class _WeeklyTaskCard extends StatelessWidget {
  final WeeklyTask task;

  const _WeeklyTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.weekTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      task.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        task.date,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => TaskDetailsModal(task: task),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A18),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'View more',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: task.progress >= 1
                      ? const Color(0xFFE5F8ED)
                      : const Color(0xFFFFF2E8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  task.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: task.progress >= 1
                        ? const Color(0xFF10B981)
                        : const Color(0xFFFF7A18),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${(task.progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0C1935),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhaseSection extends StatelessWidget {
  final String title;
  final int count;
  final List<Phase> phases;
  final VoidCallback onRefresh;

  const _PhaseSection({
    required this.title,
    required this.count,
    required this.phases,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  '$title / $count',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0C1935),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, size: 20),
                  color: const Color(0xFF6B7280),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (phases.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No phases yet',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          else
            ...phases.map((phase) => _PhaseCard(phase: phase)),
        ],
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  final Phase phase;

  const _PhaseCard({required this.phase});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'in_progress':
        return const Color(0xFFFF7A18);
      case 'not_started':
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFFE5F8ED);
      case 'in_progress':
        return const Color(0xFFFFF2E8);
      case 'not_started':
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phase.phaseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (phase.description != null &&
                        phase.description!.isNotEmpty)
                      Text(
                        phase.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusBgColor(phase.status),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  phase.status.replaceAll('_', ' ').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(phase.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Duration and date info
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'Duration: ${phase.daysDuration != null ? '${phase.daysDuration} days' : 'Not set'}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              if (phase.startDate != null) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${phase.startDate!.month}/${phase.startDate!.day}/${phase.startDate!.year}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              if (phase.endDate != null) ...[
                const SizedBox(width: 4),
                Text(
                  '- ${phase.endDate!.month}/${phase.endDate!.day}/${phase.endDate!.year}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
          // Progress bar
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: phase.calculateProgress(),
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      phase.status == 'completed'
                          ? const Color(0xFF10B981)
                          : const Color(0xFFFF7A18),
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(phase.calculateProgress() * 100).round()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0C1935),
                ),
              ),
            ],
          ),
          // Subtask count indicator and View button
          if (phase.subtasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.checklist, size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${phase.subtasks.where((s) => s.status == 'completed').length}/${phase.subtasks.length} subtasks completed',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SubtaskManagePage(phase: phase),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A18),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Manage Subtask',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
