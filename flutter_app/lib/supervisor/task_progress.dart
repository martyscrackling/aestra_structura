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
import '../services/subscription_helper.dart';
import 'widgets/sidebar.dart';
import 'widgets/supervisor_user_badge.dart';

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
  final Color primary = const Color(0xFFFF6F00);
  final Color neutral = const Color(0xFFF4F6F9);
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
      case 'Workers':
      case 'Worker Management':
        context.go('/supervisor/workers');
        break;
      case 'Attendance':
        context.go('/supervisor/attendance');
        break;
      case 'Logs':
      case 'Daily Logs':
        context.go('/supervisor/daily-logs');
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
      final projectProgressPoints = await _loadSupervisorProjectProgress(
        authService,
      );

      if (projectId == null) {
        if (!mounted) return;
        setState(() {
          _phases = [];
          _projectProgressPoints = projectProgressPoints;
          _phasesError = 'No project assigned to this supervisor yet.';
          _isLoadingPhases = false;
        });
        return;
      }

      // Fetch project details
      final projectResponse = await http.get(
        AppConfig.apiUri('projects/$projectId/'),
      );

      if (projectResponse.statusCode == 200) {
        _projectInfo = jsonDecode(projectResponse.body) as Map<String, dynamic>;
      }

      final response = await http.get(
        AppConfig.apiUri('phases/?project_id=$projectId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> payload =
            jsonDecode(response.body) as List<dynamic>;
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
          _phases = phases;
          _projectProgressPoints = projectProgressPoints;
          _isLoadingPhases = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _phasesError =
              'Failed to load phases (status ${response.statusCode}).';
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

    final List<ProjectProgressPoint> progressPoints = [];
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
            ProjectProgressPoint(projectName: projectName, progress: 0),
          );
          continue;
        }

        final List<dynamic> phasesPayload =
            jsonDecode(phasesResponse.body) as List<dynamic>;
        final progress = _calculateProjectProgress(phasesPayload);
        progressPoints.add(
          ProjectProgressPoint(projectName: projectName, progress: progress),
        );
      } catch (_) {
        progressPoints.add(
          ProjectProgressPoint(projectName: projectName, progress: 0),
        );
      }
    }

    return progressPoints;
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
                    // Creative white header with blue vertical accent on the left (keeps notification bell + AESTRA)
                    Container(
                      color: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 24,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: isMobile ? 3 : 4,
                            height: isMobile ? 40 : 56,
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Task Progress',
                                  style: TextStyle(
                                    fontSize: isMobile ? 16 : 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0C1935),
                                  ),
                                ),
                                if (!isMobile) const SizedBox(height: 6),
                                if (!isMobile)
                                  StreamBuilder<DateTime>(
                                    stream: Stream.periodic(
                                      const Duration(seconds: 1),
                                      (_) => DateTime.now(),
                                    ),
                                    builder: (context, snap) {
                                      final now = snap.data ?? DateTime.now();
                                      final formatted =
                                          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                                      return Text(
                                        formatted,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                          if (!isMobile) const SizedBox(width: 12),
                          if (!isMobile) ...[
                            _miniKPI(
                              'Projects',
                              '${_projectProgressPoints.length}',
                              Icons.apartment,
                              const Color(0xFF9C27B0),
                            ),
                            const SizedBox(width: 12),
                            if (_projectInfo != null) ...[
                              _miniKPI(
                                'Duration',
                                '${_projectInfo!['duration_days'] ?? 0} days',
                                Icons.calendar_today,
                                const Color(0xFF2196F3),
                              ),
                              const SizedBox(width: 12),
                              _miniKPI(
                                'Start Date',
                                _projectInfo!['start_date'] ?? 'N/A',
                                Icons.event,
                                const Color(0xFF4CAF50),
                              ),
                              const SizedBox(width: 12),
                              _miniKPI(
                                'End Date',
                                _projectInfo!['end_date'] ?? 'N/A',
                                Icons.event_available,
                                const Color(0xFFF44336),
                              ),
                              const SizedBox(width: 16),
                            ],
                            _miniKPI(
                              'Phases',
                              '${_phases.length}',
                              Icons.view_list,
                              const Color(0xFF757575),
                            ),
                            const SizedBox(width: 12),
                            _miniKPI(
                              'Subtasks',
                              '${_phases.fold<int>(0, (t, p) => t + p.subtasks.length)}',
                              Icons.task,
                              primary,
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (!isMobile)
                            Stack(
                              children: [
                                IconButton(
                                  onPressed: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Notifications opened (demo)',
                                          ),
                                        ),
                                      ),
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_outlined,
                                      color: Color(0xFF0C1935),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF6B6B),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (!isMobile) const SizedBox(width: 8),
                          if (!isMobile)
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'switch') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Switch account (demo)'),
                                    ),
                                  );
                                } else if (value == 'logout') {
                                  await AuthService().logout();
                                  if (!context.mounted) return;
                                  context.go('/login');
                                }
                              },
                              offset: const Offset(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              itemBuilder: (context) =>
                                  const <PopupMenuEntry<String>>[
                                    PopupMenuItem<String>(
                                      value: 'switch',
                                      height: 48,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.swap_horiz,
                                            size: 18,
                                            color: Colors.black87,
                                          ),
                                          SizedBox(width: 12),
                                          Text('Switch Account'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuDivider(height: 1),
                                    PopupMenuItem<String>(
                                      value: 'logout',
                                      height: 48,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.logout,
                                            size: 18,
                                            color: Color(0xFFFF6B6B),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Logout',
                                            style: TextStyle(
                                              color: Color(0xFFFF6B6B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const SupervisorUserBadge(
                                  showSubtitle: false,
                                  gap: 8,
                                ),
                              ),
                            ),
                          if (isMobile)
                            IconButton(
                              icon: Stack(
                                children: [
                                  const Icon(
                                    Icons.notifications_outlined,
                                    color: Color(0xFF0C1935),
                                    size: 22,
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6B6B),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              onPressed: () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Notifications opened (demo)',
                                      ),
                                    ),
                                  ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),
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
                _buildNavItem(Icons.dashboard, 'Dashboard', false),
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
}
