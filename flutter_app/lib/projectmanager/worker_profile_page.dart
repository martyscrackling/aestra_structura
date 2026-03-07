import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/responsive_page_layout.dart';
import 'workforce_page.dart';
import 'modals/view_edit_worker_modal.dart';
import '../services/app_config.dart';
import '../services/auth_service.dart';

class WorkerProject {
  final String projectName;
  final String location;
  final String startDate;
  final String endDate;
  final double progress;
  final String status;

  WorkerProject({
    required this.projectName,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.progress,
    required this.status,
  });
}

class WorkerProfilePage extends StatefulWidget {
  final WorkerInfo worker;

  const WorkerProfilePage({super.key, required this.worker});

  @override
  State<WorkerProfilePage> createState() => _WorkerProfilePageState();
}

class _WorkerProfilePageState extends State<WorkerProfilePage> {
  bool _isLoading = true;
  String? _error;
  List<WorkerProject> _activeProjects = const [];
  List<WorkerProject> _finishedProjects = const [];

  @override
  void initState() {
    super.initState();
    _fetchWorkerProjects();
  }

  int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _projectStatusLabel(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Planning';
    switch (value.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'in_progress':
      case 'in progress':
        return 'In Progress';
      case 'pending':
        return 'Pending';
      case 'planning':
        return 'Planning';
      default:
        return value;
    }
  }

  String _formatDate(String raw) {
    try {
      if (raw.trim().isEmpty) return 'N/A';
      final dt = DateTime.parse(raw);
      final mm = dt.month.toString().padLeft(2, '0');
      final dd = dt.day.toString().padLeft(2, '0');
      return '$mm/$dd/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  String _buildLocation(Map<String, dynamic> project) {
    try {
      String? asNonEmptyString(dynamic value, {bool allowNumericOnly = false}) {
        if (value == null) return null;
        final s = value.toString().trim();
        if (s.isEmpty || s == 'null') return null;
        final numericOnly = RegExp(r'^\d+$').hasMatch(s);
        if (!allowNumericOnly && numericOnly) return null;
        return s;
      }

      // Prefer human-readable *_name fields when available.
      final street = asNonEmptyString(project['street']);
      final barangay = asNonEmptyString(project['barangay_name']) ??
          asNonEmptyString(project['barangay']);
      final city = asNonEmptyString(project['city_name']) ??
          asNonEmptyString(project['city']);
      final province = asNonEmptyString(project['province_name']) ??
          asNonEmptyString(project['province']);

      final parts = <String>[];
      if (street != null) parts.add(street);
      if (barangay != null) parts.add(barangay);
      if (city != null) parts.add(city);
      if (province != null) parts.add(province);
      if (parts.isNotEmpty) return parts.join(', ');

      // Fallbacks
      return asNonEmptyString(project['location'], allowNumericOnly: false) ??
          'N/A';
    } catch (_) {
      return 'N/A';
    }
  }

  // Calculate progress based on subtasks (matching projects_page.dart)
  Future<double> _calculateProjectProgress(int projectId) async {
    try {
      final response = await http.get(
        AppConfig.apiUri('phases/?project_id=$projectId'),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! List) return 0.0;
        final phases = decoded.whereType<Map>().toList();

        int totalSubtasks = 0;
        int completedSubtasks = 0;

        for (final phase in phases) {
          final phaseMap = Map<String, dynamic>.from(phase);
          final subtasks = (phaseMap['subtasks'] as List<dynamic>?) ?? [];
          totalSubtasks += subtasks.length;

          for (final subtask in subtasks) {
            if (subtask is! Map) continue;
            final subtaskMap = Map<String, dynamic>.from(subtask);
            if ((subtaskMap['status'] as String?) == 'completed') {
              completedSubtasks++;
            }
          }
        }

        if (totalSubtasks == 0) return 0.0;
        return completedSubtasks / totalSubtasks;
      }
    } catch (_) {
      // ignore
    }
    return 0.0;
  }

  Future<List<Map<String, dynamic>>> _fetchProjectsList({int? userId}) async {
    try {
      final uri = (userId != null && userId > 0)
          ? AppConfig.apiUri('projects/?user_id=$userId')
          : AppConfig.apiUri('projects/');

      final response = await http.get(uri);
      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> _projectHasFieldWorker({
    required int projectId,
    required int fieldWorkerId,
  }) async {
    try {
      final response = await http.get(
        AppConfig.apiUri('field-workers/?project_id=$projectId'),
      );
      if (response.statusCode != 200) return false;
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return false;
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final id = _tryParseInt(map['fieldworker_id'] ?? map['field_worker_id']);
        if (id == fieldWorkerId) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _fetchWorkerProjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final currentUserId =
          _tryParseInt(AuthService().currentUser?['user_id']);

      final worker = widget.worker;
      List<Map<String, dynamic>> projects = [];

      if (worker.type == 'Supervisor' && worker.supervisorId != null) {
        // Primary: fetch projects visible to the current user, then filter by supervisor_id.
        final allProjects = await _fetchProjectsList(userId: currentUserId);
        final supervisorId = worker.supervisorId;
        projects = allProjects.where((p) {
          final pid = _tryParseInt(
            p['supervisor_id'] ?? p['supervisor'] ?? p['supervisorId'],
          );
          return pid != null && pid == supervisorId;
        }).toList();
      } else if (worker.type == 'Field Worker' && worker.fieldWorkerId != null) {
        // Best-effort: if backend supports projects-by-field-worker, use it.
        final id = worker.fieldWorkerId!;
        final queryKeys = ['field_worker_id', 'fieldworker_id', 'field_worker'];

        for (final key in queryKeys) {
          final uri = (currentUserId != null && currentUserId > 0)
              ? AppConfig.apiUri('projects/?$key=$id&user_id=$currentUserId')
              : AppConfig.apiUri('projects/?$key=$id');
          final response = await http.get(uri);
          if (response.statusCode != 200) continue;
          final decoded = jsonDecode(response.body);
          if (decoded is! List) continue;
          projects = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          break;
        }

        // Fallback: infer project membership via field-workers/?project_id.
        if (projects.isEmpty) {
          final allProjects = await _fetchProjectsList(userId: currentUserId);
          final matched = <Map<String, dynamic>>[];
          for (final project in allProjects) {
            final projectId = _tryParseInt(project['project_id']);
            if (projectId == null || projectId <= 0) continue;
            final hasWorker = await _projectHasFieldWorker(
              projectId: projectId,
              fieldWorkerId: id,
            );
            if (hasWorker) matched.add(project);
          }
          projects = matched;
        }
      } else {
        projects = [];
      }

      final active = <WorkerProject>[];
      final finished = <WorkerProject>[];

      for (final project in projects) {
        final projectId = _tryParseInt(project['project_id']) ?? 0;
        final rawStatus = (project['status'] as String?) ?? 'Planning';
        final status = _projectStatusLabel(rawStatus);

        final progress = (status == 'Completed' || projectId <= 0)
            ? 1.0
            : await _calculateProjectProgress(projectId);

        final startDate = _formatDate((project['start_date'] as String?) ?? '');
        final endDate = _formatDate((project['end_date'] as String?) ?? '');
        final location = _buildLocation(project);
        final name = (project['project_name'] as String?) ??
            (project['title'] as String?) ??
            'Unknown';

        final item = WorkerProject(
          projectName: name,
          location: location,
          startDate: startDate,
          endDate: endDate,
          progress: progress,
          status: status,
        );

        final isFinished =
            status.toLowerCase() == 'completed' || progress >= 0.999;
        if (isFinished) {
          finished.add(item);
        } else {
          active.add(item);
        }
      }

      if (!mounted) return;
      setState(() {
        _activeProjects = active;
        _finishedProjects = finished;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load projects: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePageLayout(
      currentPage: 'Workforce',
      title: 'Workforce',
      child: Builder(
        builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 768;

          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: isMobile ? 16 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button and header
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      color: const Color(0xFF0C1935),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.worker.role} Profile',
                        style: TextStyle(
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0C1935),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 16 : 24),

                // Worker Profile Card
                Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: isMobile
                      ? Column(
                          children: [
                            // Profile Image
                            CircleAvatar(
                              radius: 40,
                              backgroundImage:
                                  NetworkImage(widget.worker.avatarUrl),
                            ),
                            const SizedBox(height: 16),
                            // Profile Info
                            Column(
                              children: [
                                Text(
                                  widget.worker.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0C1935),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF2E8),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    widget.worker.role,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFFF7A18),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.email_outlined,
                                      size: 16,
                                      color: Color(0xFF6B7280),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        widget.worker.email,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6B7280),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.phone_outlined,
                                      size: 16,
                                      color: Color(0xFF6B7280),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.worker.phone,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Edit Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) =>
                                        ViewEditWorkerModal(worker: widget.worker),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF7A18),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Edit Profile',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            // Profile Image
                            CircleAvatar(
                              radius: 50,
                              backgroundImage:
                                  NetworkImage(widget.worker.avatarUrl),
                            ),
                            const SizedBox(width: 24),
                            // Profile Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.worker.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0C1935),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF2E8),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      widget.worker.role,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFFF7A18),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.email_outlined,
                                        size: 16,
                                        color: Color(0xFF6B7280),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        widget.worker.email,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.phone_outlined,
                                        size: 16,
                                        color: Color(0xFF6B7280),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        widget.worker.phone,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Edit Button
                            ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) =>
                                      ViewEditWorkerModal(worker: widget.worker),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF7A18),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Edit Profile',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                SizedBox(height: isMobile ? 24 : 32),

                // Active Projects Section
                _ProjectSection(
                  title: 'Active Projects',
                  count: _activeProjects.length,
                  projects: _activeProjects,
                  isMobile: isMobile,
                ),
                SizedBox(height: isMobile ? 24 : 32),

                // Finished Projects Section
                _ProjectSection(
                  title: 'Finished Projects',
                  count: _finishedProjects.length,
                  projects: _finishedProjects,
                  isMobile: isMobile,
                ),
                SizedBox(height: isMobile ? 80 : 0),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProjectSection extends StatelessWidget {
  final String title;
  final int count;
  final List<WorkerProject> projects;
  final bool isMobile;

  const _ProjectSection({
    required this.title,
    required this.count,
    required this.projects,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title ($count)',
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0C1935),
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        if (projects.isEmpty)
          Text(
            'No projects assigned.',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: const Color(0xFF6B7280),
            ),
          ),
        ...projects.map(
          (project) => Padding(
            padding: EdgeInsets.only(bottom: isMobile ? 12 : 16),
            child: _ProjectCard(project: project, isMobile: isMobile),
          ),
        ),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final WorkerProject project;
  final bool isMobile;

  const _ProjectCard({required this.project, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.projectName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0C1935),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: project.progress >= 1
                                ? const Color(0xFFE5F8ED)
                                : const Color(0xFFFFF2E8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            project.status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: project.progress >= 1
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFFF7A18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            project.location,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(project.progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                project.projectName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0C1935),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: project.progress >= 1
                                      ? const Color(0xFFE5F8ED)
                                      : const Color(0xFFFFF2E8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  project.status,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: project.progress >= 1
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFFF7A18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                project.location,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(project.progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                  ],
                ),
          SizedBox(height: isMobile ? 12 : 16),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                '${project.startDate} - ${project.endDate}',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: project.progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation(
                project.progress >= 1
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFFF7A18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
