import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/responsive_page_layout.dart';
import 'modals/task_details_modal.dart';
import 'modals/phase_modal.dart';
import 'subtask_manage.dart';
import '../services/app_config.dart';

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
  final DateTime? createdAt;

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
    this.createdAt,
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
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
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

class BackJobReview {
  final int reviewId;
  final String clientName;
  final String reviewText;
  final DateTime? createdAt;
  final bool isResolved;

  BackJobReview({
    required this.reviewId,
    required this.clientName,
    required this.reviewText,
    required this.createdAt,
    required this.isResolved,
  });

  static String _stringValue(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static int _intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static bool _parseResolved(dynamic value) {
    if (value is bool) return value;
    final text = (value ?? '').toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'resolved' || text == 'completed';
  }

  factory BackJobReview.fromJson(Map<String, dynamic> json) {
    final client = _stringValue(
      json['client_name'] ?? json['client'] ?? json['customer_name'],
      fallback: 'Client',
    );
    final text = _stringValue(
      json['review_text'] ??
          json['review'] ??
          json['comment'] ??
          json['remarks'] ??
          json['feedback'],
      fallback: 'No review details provided.',
    );

    return BackJobReview(
      reviewId: _intValue(json['review_id'] ?? json['id'] ?? json['back_job_review_id']),
      clientName: client,
      reviewText: text,
      createdAt: _parseDate(json['created_at'] ?? json['createdAt'] ?? json['date']),
      isResolved: _parseResolved(json['is_resolved'] ?? json['resolved'] ?? json['status']),
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
  final String? projectStartDate;

  const ProjectTaskDetailsPage({
    super.key,
    required this.projectTitle,
    required this.projectLocation,
    required this.projectImage,
    required this.progress,
    this.budget,
    required this.projectId,
    this.projectStartDate,
  });

  @override
  State<ProjectTaskDetailsPage> createState() => _ProjectTaskDetailsPageState();
}

class _ProjectTaskDetailsPageState extends State<ProjectTaskDetailsPage> {
  List<Phase> _phases = [];
  List<BackJobReview> _backJobReviews = [];
  bool _isLoading = true;
  bool _isLoadingReviews = true;
  String? _error;
  String? _reviewsError;
  bool _isGanttView = false; // View mode: false = list view, true = gantt chart

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
    setState(() {
      _isLoading = true;
      _isLoadingReviews = true;
      _error = null;
      _reviewsError = null;
    });

    try {
      final response = await http.get(
        AppConfig.apiUri('phases/?project_id=${widget.projectId}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _phases = data.map((json) => Phase.fromJson(json)).toList();
          // Sort phases by createdAt (oldest first)
          _phases.sort((a, b) {
            if (a.createdAt != null && b.createdAt != null) {
              int cmp = a.createdAt!.compareTo(b.createdAt!);
              if (cmp != 0) return cmp;
            }
            return a.phaseId.compareTo(b.phaseId);
          });
        });
      } else {
        setState(() {
          _error = 'Failed to load phases';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      await _fetchBackJobReviews();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchBackJobReviews() async {
    try {
      final response = await http.get(
        AppConfig.apiUri('back-job-reviews/?project_id=${widget.projectId}'),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> data = [];

        if (decoded is List<dynamic>) {
          data = decoded;
        } else if (decoded is Map<String, dynamic>) {
          final wrapped =
              decoded['results'] ??
              decoded['data'] ??
              decoded['reviews'] ??
              decoded['items'];
          if (wrapped is List<dynamic>) {
            data = wrapped;
          }
        }

        final reviews = data
            .whereType<Map>()
            .map((json) => BackJobReview.fromJson(Map<String, dynamic>.from(json)))
            .toList();

        reviews.sort((a, b) {
          final aDate = a.createdAt;
          final bDate = b.createdAt;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

        if (!mounted) return;
        setState(() {
          _backJobReviews = reviews;
          _isLoadingReviews = false;
          _reviewsError = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoadingReviews = false;
          _reviewsError = 'Failed to load back job reviews';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingReviews = false;
        _reviewsError = 'Unable to load back job reviews';
      });
    }
  }

  String _formatReviewDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  Widget _buildBackJobReviewsSection() {
    if (_isLoadingReviews) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_reviewsError != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          _reviewsError!,
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }

    if (_backJobReviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Text(
          'No back job reviews submitted by the client yet.',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }

    return Column(
      children: _backJobReviews.map((review) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      review.clientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                  ),
                  if (review.createdAt != null)
                    Text(
                      _formatReviewDate(review.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                review.reviewText,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: review.isResolved
                      ? const Color(0xFFE5F8ED)
                      : const Color(0xFFFFF2E8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  review.isResolved ? 'Resolved' : 'Open',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: review.isResolved
                        ? const Color(0xFF10B981)
                        : const Color(0xFFFF7A18),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
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
          'Complete slab concreting, masonry works, inFstall frames, set roof trusses, and finish with roofing and cleanup.',
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return ResponsivePageLayout(
      currentPage: 'Projects',
      title: 'Projects',
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
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
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0C1935),
                        ),
                      ),
                      Text(
                        widget.projectLocation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          color: const Color(0xFF6B7280),
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

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Client Back Job Reviews',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0C1935),
                          ),
                        ),
                      ),
                      if (!_isLoadingReviews && _reviewsError == null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_backJobReviews.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildBackJobReviewsSection(),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tabs
            Row(
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
            const SizedBox(height: 24),

            // Search and Filter
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search, size: 18),
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
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
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
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
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
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
                isGanttView: _isGanttView,
                onToggleView: () {
                  setState(() {
                    _isGanttView = !_isGanttView;
                  });
                },
                projectStartDate: widget.projectStartDate,
              ),
              const SizedBox(height: 24),

              // Finished Section (Phases)
              _PhaseSection(
                title: 'Finished',
                count: _completedPhases.length,
                phases: _completedPhases,
                onRefresh: _fetchPhases,
                isGanttView: _isGanttView,
                onToggleView: () {
                  setState(() {
                    _isGanttView = !_isGanttView;
                  });
                },
                projectStartDate: widget.projectStartDate,
              ),
            ],
            SizedBox(height: isMobile ? 80 : 32), // Space for bottom nav
          ],
        ),
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
        backgroundColor: isSelected
            ? const Color(0xFF0C1935)
            : Colors.transparent,
        foregroundColor: isSelected ? Colors.white : const Color(0xFF6B7280),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
  final bool isGanttView;
  final VoidCallback onToggleView;
  final String? projectStartDate;

  const _PhaseSection({
    required this.title,
    required this.count,
    required this.phases,
    required this.onRefresh,
    required this.isGanttView,
    required this.onToggleView,
    this.projectStartDate,
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
                // Toggle switch for view mode
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.view_list,
                      size: 18,
                      color: !isGanttView
                          ? const Color(0xFF0C1935)
                          : const Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onToggleView,
                      child: Container(
                        width: 44,
                        height: 24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isGanttView
                              ? const Color(0xFF0C1935)
                              : const Color(0xFFE5E7EB),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: isGanttView
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 20,
                            height: 20,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.view_timeline,
                      size: 18,
                      color: isGanttView
                          ? const Color(0xFF0C1935)
                          : const Color(0xFF6B7280),
                    ),
                  ],
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
          else if (isGanttView)
            _GanttChartView(phases: phases, projectStartDate: projectStartDate)
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
          // Progress barnd
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

// Gantt Chart View Widget
class _GanttChartView extends StatelessWidget {
  final List<Phase> phases;
  final String? projectStartDate;

  const _GanttChartView({required this.phases, this.projectStartDate});

  @override
  Widget build(BuildContext context) {
    if (phases.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'No phases to display',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }

    // Parse project start date
    DateTime projectStart;
    try {
      projectStart = projectStartDate != null
          ? DateTime.parse(projectStartDate!)
          : DateTime.now();
    } catch (e) {
      projectStart = DateTime.now();
    }

    // Calculate sequential phase dates based on duration
    List<Map<String, dynamic>> sequentialPhases = [];
    DateTime currentDate = projectStart;

    for (int i = 0; i < phases.length; i++) {
      final phase = phases[i];
      final duration = phase.daysDuration ?? 30; // Default 30 days if not set

      final startDate = currentDate;
      final endDate = currentDate.add(Duration(days: duration));

      sequentialPhases.add({
        'phase': phase,
        'startDate': startDate,
        'endDate': endDate,
        'index': i,
      });

      currentDate = endDate; // Next phase starts after this one ends
    }

    // Calculate total project duration
    final lastPhase = sequentialPhases.last;
    final totalDays = lastPhase['endDate'].difference(projectStart).inDays;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 768;

        // Calculate responsive chart width
        // Subtract padding (40) and label width (200)
        final availableWidth = constraints.maxWidth > 0
            ? constraints.maxWidth -
                  40 -
                  220 // 40 for padding, 220 for label + spacing
            : screenWidth - 40 - 220;

        final chartWidth = (availableWidth > 400 ? availableWidth : 400)
            .toDouble();

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline header with months
              _buildTimelineHeader(projectStart, totalDays, chartWidth),
              const SizedBox(height: 20),

              // Phases as Gantt bars
              ...sequentialPhases.map((phaseData) {
                final phase = phaseData['phase'] as Phase;
                final startDate = phaseData['startDate'] as DateTime;
                final endDate = phaseData['endDate'] as DateTime;
                final index = phaseData['index'] as int;

                return _buildGanttBar(
                  context,
                  phase,
                  startDate,
                  endDate,
                  projectStart,
                  totalDays,
                  chartWidth,
                  index,
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimelineHeader(
    DateTime projectStart,
    int totalDays,
    double chartWidth,
  ) {
    List<Widget> timeMarkers = [];

    // Generate month/day markers
    DateTime currentDate = projectStart;
    int daysShown = 0;

    while (daysShown < totalDays) {
      final daysInCurrentMonth = DateTime(
        currentDate.year,
        currentDate.month + 1,
        0,
      ).day;

      final remainingDaysInMonth = daysInCurrentMonth - currentDate.day + 1;
      final daysToShow = remainingDaysInMonth < (totalDays - daysShown)
          ? remainingDaysInMonth
          : (totalDays - daysShown);

      final widthPercent = daysToShow / totalDays;
      final width = chartWidth * widthPercent;

      timeMarkers.add(
        Container(
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.grey[300]!),
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Text(
            _getMonthName(currentDate.month) + ' ${currentDate.year}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );

      daysShown += daysToShow;
      currentDate = DateTime(currentDate.year, currentDate.month + 1, 1);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 200), // Space for phase names
        Expanded(child: Row(children: timeMarkers)),
      ],
    );
  }

  Widget _buildGanttBar(
    BuildContext context,
    Phase phase,
    DateTime startDate,
    DateTime endDate,
    DateTime projectStart,
    int totalDays,
    double chartWidth,
    int index,
  ) {
    final startOffset = startDate.difference(projectStart).inDays;
    final duration = endDate.difference(startDate).inDays;

    final startPercent = startOffset / totalDays;
    final widthPercent = duration / totalDays;

    final barStartPosition = chartWidth * startPercent;
    final barWidth = chartWidth * widthPercent;

    // Alternating colors: dark blue (#0C1935) and orange (#FF7A18)
    final barColor = index % 2 == 0
        ? const Color(0xFF0C1935)
        : const Color(0xFFFF7A18);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase name (fixed width)
          SizedBox(
            width: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phase.phaseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0C1935),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${duration} days',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    if (phase.subtasks.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.checklist,
                        size: 12,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${phase.subtasks.where((s) => s.status == 'completed').length}/${phase.subtasks.length} completed',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Gantt bar container - clickable
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SubtaskManagePage(phase: phase),
                  ),
                );
              },
              child: Stack(
                children: [
                  // Background grid
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[200]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Gantt bar
                  Positioned(
                    left: barStartPosition,
                    child: Container(
                      width: barWidth,
                      height: 50,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            phase.phaseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_formatDate(startDate)} - ${_formatDate(endDate)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
