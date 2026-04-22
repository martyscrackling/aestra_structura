import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/app_config.dart';
import '../services/auth_service.dart';
import 'models/project_item.dart';

class ProjectViewPage extends StatefulWidget {
  const ProjectViewPage({super.key, required this.project});

  final ProjectItem project;

  @override
  State<ProjectViewPage> createState() => _ProjectViewPageState();
}

class _ProjectViewPageState extends State<ProjectViewPage> {
  late Future<List<_PhaseSection>> _future;
  final TextEditingController _reviewController = TextEditingController();
  List<_BackJobReviewItem> _reviews = [];
  bool _isLoadingReviews = true;
  bool _isSubmittingReview = false;
  String? _reviewsError;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadBackJobReviews();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<List<_PhaseSection>> _load() async {
    final projectId = widget.project.projectId;
    if (projectId == 0) return const [];

    final response = await http.get(
      AppConfig.apiUri('phases/?project_id=$projectId'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load phases');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw Exception('Unexpected phases response');

    final phases = decoded.whereType<Map<String, dynamic>>().toList();
    final sections = <_PhaseSection>[];

    for (final p in phases) {
      final title = (p['phase_name'] as String?) ?? 'Phase';
      final updatedAt = DateTime.tryParse((p['updated_at'] as String?) ?? '');
      final tasksRaw = (p['subtasks'] is List)
          ? (p['subtasks'] as List)
          : const [];
      final tasks = tasksRaw
          .whereType<Map<String, dynamic>>()
          .map((t) {
            final taskTitle = (t['title'] as String?) ?? 'Untitled task';
            final status = (t['status'] as String?) ?? 'pending';
            return _TaskItem(title: taskTitle, status: status);
          })
          .toList(growable: false);

      sections.add(
        _PhaseSection(
          title: title,
          date: _formatDateLabel(updatedAt),
          tasks: tasks,
        ),
      );
    }

    return sections;
  }

  String _formatDateLabel(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Updated today';
    if (diff.inDays == 1) return 'Updated yesterday';
    return 'Updated ${diff.inDays} days ago';
  }

  Future<void> _loadBackJobReviews() async {
    final projectId = widget.project.projectId;
    if (projectId == 0) {
      setState(() {
        _reviews = [];
        _reviewsError = null;
        _isLoadingReviews = false;
      });
      return;
    }

    setState(() {
      _isLoadingReviews = true;
      _reviewsError = null;
    });

    try {
      final response = await http.get(
        AppConfig.apiUri('back-job-reviews/?project_id=$projectId'),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to load reviews');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) throw Exception('Unexpected reviews response');

      final reviews = decoded
          .whereType<Map<String, dynamic>>()
          .map(_BackJobReviewItem.fromJson)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _isLoadingReviews = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reviewsError = 'Unable to load back job reviews.';
        _isLoadingReviews = false;
      });
    }
  }

  Future<void> _submitBackJobReview() async {
    final reviewText = _reviewController.text.trim();
    if (reviewText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a review before submitting.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentUser = AuthService().currentUser;
    final clientIdRaw = currentUser?['client_id'] ?? currentUser?['user_id'];
    final clientId = int.tryParse('$clientIdRaw');
    final userId = int.tryParse('${currentUser?['user_id']}');
    final projectId = widget.project.projectId;

    if (clientId == null || projectId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to submit review: missing client or project.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmittingReview = true;
    });

    try {
      final response = await http.post(
        AppConfig.apiUri('back-job-reviews/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'project': projectId,
          'client': clientId,
          'client_user_id': userId,
          'review_text': reviewText,
        }),
      );

      if (response.statusCode == 201) {
        _reviewController.clear();
        await _loadBackJobReviews();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Back job review submitted.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        String detail = 'Failed to submit review (${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['detail'] != null) {
            detail = decoded['detail'].toString();
          }
        } catch (_) {}

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(detail),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error submitting review.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingReview = false;
        });
      }
    }
  }

  String _formatReviewDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  void _showTasksModal(BuildContext context, _PhaseSection week) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? screenWidth * 0.9 : 700,
            maxHeight: isMobile
                ? MediaQuery.of(context).size.height * 0.7
                : 520,
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        week.title,
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Subtasks',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: week.tasks.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final t = week.tasks[index];
                      final dotColor = switch (t.status.toLowerCase()) {
                        'completed' => Colors.green,
                        'in_progress' || 'in progress' => Colors.blue,
                        _ => Colors.orange,
                      };
                      return ListTile(
                        leading: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(t.title),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<int>(
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 1,
                                  child: Text('...'),
                                ),
                              ],
                              icon: const Icon(Icons.more_horiz),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final project = widget.project;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          project.title,
          style: const TextStyle(color: Color(0xFF0C1935)),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: FutureBuilder<List<_PhaseSection>>(
        future: _future,
        builder: (context, snapshot) {
          final phases = snapshot.data ?? const <_PhaseSection>[];

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = _load();
              });
              await _future;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      project.imageUrl,
                      height: isMobile ? 160 : 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: isMobile ? 160 : 200,
                        color: Colors.grey[200],
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    project.title,
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0C1935),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${project.startDate}  •  ${project.endDate}',
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: project.progress,
                          minHeight: 8,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(
                            project.progress > 0.7
                                ? Colors.green
                                : project.progress > 0.4
                                ? Colors.orange
                                : Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(project.progress * 100).toInt()}%',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFFFF7A18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(project.location)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Back Job Reviews',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tell us what needs to be fixed:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _reviewController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText:
                                'Example: Paint finish in bedroom has uneven texture...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: _isSubmittingReview
                                ? null
                                : _submitBackJobReview,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF7A18),
                            ),
                            child: _isSubmittingReview
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Submit Review',
                                    style: TextStyle(color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingReviews)
                    const Center(child: CircularProgressIndicator())
                  else if (_reviewsError != null)
                    Text(
                      _reviewsError!,
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    )
                  else if (_reviews.isEmpty)
                    const Text(
                      'No back job reviews yet.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    )
                  else
                    ..._reviews.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          width: double.infinity,
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
                                      r.clientName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatReviewDate(r.createdAt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                r.reviewText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'To Do',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(child: CircularProgressIndicator())
                  else if (snapshot.hasError)
                    const Text(
                      'Unable to load tasks.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    )
                  else if (phases.isEmpty)
                    const Text(
                      'No tasks found for this project.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    )
                  else
                    ...phases.map((w) {
                      final completed = w.tasks
                          .where((t) => t.status.toLowerCase() == 'completed')
                          .length;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(8),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 12 : 16,
                              vertical: isMobile ? 10 : 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: isMobile ? 14 : 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  w.date,
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 13,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Text(
                                      '$completed/${w.tasks.length}',
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    const Spacer(),
                                    ElevatedButton(
                                      onPressed: () =>
                                          _showTasksModal(context, w),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFFF7A18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isMobile ? 12 : 16,
                                          vertical: isMobile ? 8 : 10,
                                        ),
                                      ),
                                      child: Text(
                                        'View more',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isMobile ? 12 : 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PhaseSection {
  _PhaseSection({required this.title, required this.date, required this.tasks});
  final String title;
  final String date;
  final List<_TaskItem> tasks;
}

class _TaskItem {
  _TaskItem({required this.title, required this.status});
  final String title;
  final String status;
}

class _BackJobReviewItem {
  _BackJobReviewItem({
    required this.reviewId,
    required this.clientName,
    required this.reviewText,
    required this.createdAt,
    required this.isResolved,
  });

  final int reviewId;
  final String clientName;
  final String reviewText;
  final DateTime createdAt;
  final bool isResolved;

  factory _BackJobReviewItem.fromJson(Map<String, dynamic> json) {
    return _BackJobReviewItem(
      reviewId: (json['review_id'] as num?)?.toInt() ?? 0,
      clientName: (json['client_name'] as String?) ?? 'Client',
      reviewText: (json['review_text'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.now(),
      isResolved: json['is_resolved'] == true,
    );
  }
}
