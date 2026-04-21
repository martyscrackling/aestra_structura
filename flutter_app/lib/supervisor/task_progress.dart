import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/auth_service.dart';
import '../services/app_config.dart';
import '../services/app_theme_tokens.dart';
import '../services/subscription_helper.dart';
import 'widgets/sidebar.dart';
import 'widgets/mobile_bottom_nav.dart';
import 'widgets/dashboard_header.dart';

class Subtask {
  Subtask({
    required this.id,
    required this.title,
    this.assignedWorkers = const [],
    this.status = 'Pending',
    this.photos = const [],
    this.notes = '',
  });

  final String id;
  String title;
  List<String> assignedWorkers;
  String status; // 'Pending' | 'In Progress' | 'Completed'
  List<XFile> photos;
  String notes;
}

class Phase {
  Phase({required this.id, required this.title, required this.subtasks});
  final String id;
  String title;
  List<Subtask> subtasks;
}

class ProjectProgressPoint {
  ProjectProgressPoint({required this.projectName, required this.progress});

  final String projectName;
  final int progress;
}

class TaskProgressPage extends StatefulWidget {
  final bool initialSidebarVisible;

  const TaskProgressPage({super.key, this.initialSidebarVisible = false});

  @override
  State<TaskProgressPage> createState() => _TaskProgressPageState();
}

class _TaskProgressPageState extends State<TaskProgressPage> {
  final Color primary = AppColors.accent;
  final Color neutral = AppColors.surface;
  final ImagePicker _picker = ImagePicker();
  List<Phase> _phases = [];
  bool _isLoadingPhases = true;
  String? _phasesError;
  Map<String, dynamic>? _projectInfo;
  List<ProjectProgressPoint> _projectProgressPoints = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadPhases);
  }

  void _navigateToPage(String page) {
    switch (page) {
      case 'Dashboard':
        context.go('/supervisor');
        break;
      case 'Projects':
        context.go('/supervisor/projects');
        break;
      case 'Workers':
      case 'Worker Management':
        context.go('/supervisor/workers');
        break;
      case 'Attendance':
        context.go('/supervisor/attendance');
        break;
      case 'Tasks':
      case 'Task Progress':
        return; // Already on tasks page
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

  Future<void> _loadPhases() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final projectId = authService.currentUser?['project_id'];

    setState(() {
      _isLoadingPhases = true;
      _phasesError = null;
    });

    try {
      final projectProgressFuture = _loadSupervisorProjectProgress(authService);

      if (projectId == null) {
        final projectProgressPoints = await projectProgressFuture;
        if (!mounted) return;
        setState(() {
          _phases = [];
          _projectProgressPoints = projectProgressPoints;
          _phasesError = 'No project assigned to this supervisor yet.';
          _isLoadingPhases = false;
        });
        return;
      }

      final projectInfoFuture = _fetchProjectInfo(projectId: projectId);
      final phasesFuture = _fetchPhasesForProject(projectId: projectId);

      final resolved = await Future.wait<dynamic>([
        projectProgressFuture,
        projectInfoFuture,
        phasesFuture,
      ]);

      final projectProgressPoints =
          (resolved[0] as List<ProjectProgressPoint>?) ??
          <ProjectProgressPoint>[];
      final projectInfo = resolved[1] as Map<String, dynamic>?;
      final payload = (resolved[2] as List<dynamic>?) ?? <dynamic>[];

      if (payload.isNotEmpty) {
        final List<Phase> phases = payload.map((phaseJson) {
          final Map<String, dynamic> phaseMap =
              phaseJson as Map<String, dynamic>;
          final List<dynamic> subtasksData =
              (phaseMap['subtasks'] as List<dynamic>?) ?? [];
          final subtasks = subtasksData.map((subtaskJson) {
            final Map<String, dynamic> subtaskMap =
                subtaskJson as Map<String, dynamic>;
            final assigned =
                (subtaskMap['assigned_workers'] as List<dynamic>? ?? [])
                    .map((workerJson) {
                      final Map<String, dynamic> workerMap =
                          workerJson as Map<String, dynamic>;
                      final first = (workerMap['first_name'] as String?) ?? '';
                      final last = (workerMap['last_name'] as String?) ?? '';
                      final name = '$first $last'.trim();
                      return name.isNotEmpty
                          ? name
                          : ((workerMap['role'] as String?) ?? 'Worker');
                    })
                    .cast<String>()
                    .toList();
            return Subtask(
              id: (subtaskMap['subtask_id'] ?? '').toString(),
              title: subtaskMap['title'] as String? ?? 'Untitled Subtask',
              status: _mapBackendStatus(subtaskMap['status'] as String?),
              assignedWorkers: assigned,
              notes: subtaskMap['progress_notes'] as String? ?? '',
            );
          }).toList();

          return Phase(
            id: (phaseMap['phase_id'] ?? '').toString(),
            title: phaseMap['phase_name'] as String? ?? 'Untitled Phase',
            subtasks: subtasks,
          );
        }).toList();

        if (!mounted) return;
        setState(() {
          _projectInfo = projectInfo;
          _phases = phases;
          _projectProgressPoints = projectProgressPoints;
          _isLoadingPhases = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _projectInfo = projectInfo;
          _phasesError =
              'Failed to load phases.';
          _projectProgressPoints = projectProgressPoints;
          _isLoadingPhases = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phasesError = 'Failed to connect to the server.';
        _projectProgressPoints = [];
        _isLoadingPhases = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchProjectInfo({required dynamic projectId}) async {
    try {
      final projectResponse = await http.get(
        AppConfig.apiUri('projects/$projectId/'),
      );
      if (projectResponse.statusCode == 200) {
        return jsonDecode(projectResponse.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // Keep existing fallback behavior.
    }
    return null;
  }

  Future<List<dynamic>> _fetchPhasesForProject({required dynamic projectId}) async {
    try {
      final response = await http.get(
        AppConfig.apiUri('phases/?project_id=$projectId'),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return _parsePhasesPayload(decoded);
      }
    } catch (_) {
      // Keep existing fallback behavior.
    }
    return <dynamic>[];
  }

  Future<List<ProjectProgressPoint>> _loadSupervisorProjectProgress(
    AuthService authService,
  ) async {
    final userId = authService.currentUser?['user_id'];
    final supervisorId = authService.currentUser?['supervisor_id'];
    final fallbackProjectId = authService.currentUser?['project_id'];
    final scopeSuffix = userId != null ? '&user_id=$userId' : '';

    if (supervisorId == null && fallbackProjectId == null) {
      return [];
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
      return [];
    }

    final decoded = jsonDecode(projectsResponse.body);
    final projects = _parseProjectsPayload(decoded);

    final progressFutures = projects.map((project) async {
      final projectIdRaw = project['project_id'];
      if (projectIdRaw == null) return null;

      final int projectId = projectIdRaw is int
          ? projectIdRaw
          : int.tryParse(projectIdRaw.toString()) ?? -1;
      if (projectId <= 0) return null;

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
          return ProjectProgressPoint(projectName: projectName, progress: 0);
        }

        final phasesPayload = _parsePhasesPayload(
          jsonDecode(phasesResponse.body),
        );
        final progress = _calculateProjectProgress(phasesPayload);
        return ProjectProgressPoint(projectName: projectName, progress: progress);
      } catch (_) {
        return ProjectProgressPoint(projectName: projectName, progress: 0);
      }
    }).toList(growable: false);

    final resolved = await Future.wait<ProjectProgressPoint?>(progressFutures);
    return resolved.whereType<ProjectProgressPoint>().toList(growable: false);
  }

  List<dynamic> _parsePhasesPayload(dynamic payload) {
    if (payload is List) {
      return payload;
    }
    if (payload is Map<String, dynamic>) {
      if (payload['results'] is List) {
        return payload['results'] as List<dynamic>;
      }
      if (payload['data'] is List) {
        return payload['data'] as List<dynamic>;
      }
    }
    return <dynamic>[];
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

  String _mapBackendStatus(String? backendStatus) {
    switch (backendStatus) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return 'Pending';
    }
  }

  // compute phase progress as percent of subtasks completed
  int _phaseProgress(int pIndex) {
    final subs = _phases[pIndex].subtasks;
    if (subs.isEmpty) return 0;
    final completed = subs.where((s) => s.status == 'Completed').length;
    return ((completed / subs.length) * 100).round();
  }

  // pick one or multiple images and append to subtask photos
  Future<void> _pickPhotosForSubtask(int phaseIndex, int subtaskIndex) async {
    try {
      final List<XFile>? picked = await _picker.pickMultiImage(
        imageQuality: 80,
      );
      if (picked != null && picked.isNotEmpty) {
        setState(() {
          _phases[phaseIndex].subtasks[subtaskIndex].photos = [
            ..._phases[phaseIndex].subtasks[subtaskIndex].photos,
            ...picked,
          ];
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to pick images')));
    }
  }

  // Submit subtask update to Project Manager
  Future<void> _submitSubtaskUpdate(int phaseIndex, int subtaskIndex) async {
    final subtask = _phases[phaseIndex].subtasks[subtaskIndex];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.send, color: primary),
            const SizedBox(width: 12),
            const Text('Submit Update'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Submit update for:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '"${subtask.title}"',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status: ${subtask.status}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Photos: ${subtask.photos.length}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Notes: ${subtask.notes.isEmpty ? "None" : subtask.notes}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will notify the Project Manager.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit to PM'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Submitting update...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      try {
        // Map UI status to backend format
        String backendStatus;
        switch (subtask.status) {
          case 'Pending':
            backendStatus = 'pending';
            break;
          case 'In Progress':
            backendStatus = 'in_progress';
            break;
          case 'Completed':
            backendStatus = 'completed';
            break;
          default:
            backendStatus = 'pending';
        }

        // Prepare the request body
        final Map<String, dynamic> requestBody = {'status': backendStatus};

        // Send PATCH request to update subtask
        final response = await http.patch(
          AppConfig.apiUri('subtasks/${subtask.id}/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Check for subscription expiry first
        if (SubscriptionHelper.handleResponse(context, response)) {
          return;
        }

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Update for "${subtask.title}" submitted to Project Manager',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit update: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // remove single photo from subtask
  void _removePhoto(int phaseIndex, int subtaskIndex, int photoIndex) {
    setState(() {
      _phases[phaseIndex].subtasks[subtaskIndex].photos.removeAt(photoIndex);
    });
  }

  // single subtask detail dialog (edit notes and status; progress tracked at phase level)
  void _openSubtaskDialog(int phaseIndex, int subtaskIndex) {
    final sub = _phases[phaseIndex].subtasks[subtaskIndex];
    final notesCtrl = TextEditingController(text: sub.notes);
    String status = sub.status;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.edit_note, color: primary),
            const SizedBox(width: 12),
            Expanded(child: Text(sub.title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assigned Workers',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sub.assignedWorkers.isEmpty
                            ? 'No workers assigned yet'
                            : sub.assignedWorkers.join(', '),
                        style: TextStyle(
                          color: sub.assignedWorkers.isEmpty
                              ? Colors.grey[500]
                              : Colors.grey[800],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Update Status',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: status,
                items: ['Pending', 'In Progress', 'Completed']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => status = v ?? status,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Progress Notes',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(
                  hintText: 'Add notes about progress, issues, or updates...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            onPressed: () async {
              final notes = notesCtrl.text.trim();

              // Show loading
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Text('Saving changes...'),
                    ],
                  ),
                  duration: Duration(seconds: 30),
                ),
              );

              try {
                // Map UI status to backend format
                String backendStatus;
                switch (status) {
                  case 'Pending':
                    backendStatus = 'pending';
                    break;
                  case 'In Progress':
                    backendStatus = 'in_progress';
                    break;
                  case 'Completed':
                    backendStatus = 'completed';
                    break;
                  default:
                    backendStatus = 'pending';
                }

                // Prepare the request body
                final Map<String, dynamic> requestBody = {
                  'status': backendStatus,
                  'progress_notes': notes,
                };

                // Send PATCH request to update subtask
                final response = await http.patch(
                  AppConfig.apiUri('subtasks/${sub.id}/'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(requestBody),
                );

                if (!mounted) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();

                // Check for subscription expiry first
                if (SubscriptionHelper.handleResponse(context, response)) {
                  return;
                }

                if (response.statusCode == 200) {
                  setState(() {
                    sub.notes = notes;
                    sub.status = status;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Subtask updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save: ${response.statusCode}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error saving changes: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumb(
    int phaseIndex,
    int subtaskIndex,
    int photoIndex,
    XFile xfile,
  ) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FutureBuilder<Uint8List>(
            future: xfile.readAsBytes(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return SizedBox(
                  width: 120,
                  height: 80,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              if (snap.hasError || snap.data == null) {
                return SizedBox(
                  width: 120,
                  height: 80,
                  child: Center(child: Icon(Icons.broken_image)),
                );
              }
              return Image.memory(
                snap.data!,
                width: 120,
                height: 80,
                fit: BoxFit.cover,
              );
            },
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removePhoto(phaseIndex, subtaskIndex, photoIndex),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // small KPI chip used in header
  Widget _miniKPI(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhasesContent(bool isMobile) {
    final horizontalPadding = isMobile ? 12.0 : 24.0;
    final padding = EdgeInsets.fromLTRB(
      horizontalPadding,
      0,
      horizontalPadding,
      MediaQuery.of(context).viewInsets.bottom + 24,
    );

    if (_isLoadingPhases) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: const [
          SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (_phasesError != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: [
          _buildProjectProgressChart(isMobile),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: Center(
              child: Text(
                _phasesError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primary),
              onPressed: _loadPhases,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: [
        const SizedBox(height: 4),
        _buildProjectProgressChart(isMobile),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildProjectProgressChart(bool isMobile) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Progress By Project',
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
              'Overall completion per project assigned to this supervisor',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            if (_projectProgressPoints.isEmpty)
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
                          getTitlesWidget: (value, axisMeta) {
                            return Text(
                              '${value.toInt()}%',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 10,
                              ),
                            );
                          },
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
                        color: primary,
                        barWidth: 3,
                        isCurved: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                                radius: 3,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: primary,
                              ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: primary.withOpacity(0.12),
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 1024;
    final isMobile = width <= 600;

    return Scaffold(
      backgroundColor: neutral,
      body: Stack(
        children: [
          Row(
            children: [
              if (isDesktop)
                Sidebar(activePage: 'Task Progress', keepVisible: true),
              Expanded(
                child: Column(
                  children: [
                    const DashboardHeader(title: 'Task Progress'),
                    const SizedBox(height: 12),
                    Expanded(
                      child: RefreshIndicator(
                        color: primary,
                        onRefresh: _loadPhases,
                        child: _buildPhasesContent(isMobile),
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
      activeTab: SupervisorMobileTab.more,
      activeMorePage: 'Tasks',
      onSelect: _navigateToPage,
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    final color = isActive ? AppColors.accent : Colors.white70;

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
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accent.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.mobileNavLabel(color, isActive: isActive),
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
          color: AppColors.navSurface,
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
}
