import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

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
    this.completed = false,
  });

  final String id;
  String title;
  List<String> assignedWorkers;
  String status; // 'Pending' | 'In Progress' | 'Completed'
  List<XFile> photos;
  String notes;
  bool completed; // Checkbox flag for completion
}

class Phase {
  Phase({
    required this.id,
    required this.title,
    required this.subtasks,
    this.phasePhotos = const [],
    this.phaseNotes = '',
  });
  final String id;
  String title;
  List<Subtask> subtasks;
  List<XFile> phasePhotos; // Phase-level photos
  String phaseNotes; // Phase-level notes
}

class TaskProgressPage extends StatefulWidget {
  final bool initialSidebarVisible;
  final int? projectId;

  const TaskProgressPage({
    super.key,
    this.initialSidebarVisible = false,
    this.projectId,
  });

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

  String _projectDisplayName() {
    final rawName = _projectInfo?['project_name'];
    if (rawName is String && rawName.trim().isNotEmpty) {
      return rawName.trim();
    }

    final projectId = widget.projectId;
    if (projectId != null) {
      return 'Project #$projectId';
    }

    return 'Project';
  }

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
    final projectId =
        widget.projectId ?? authService.currentUser?['project_id'];

    if (projectId == null) {
      setState(() {
        _phases = [];
        _phasesError = 'No project assigned to this supervisor yet.';
        _isLoadingPhases = false;
      });
      return;
    }

    setState(() {
      _isLoadingPhases = true;
      _phasesError = null;
    });

    try {
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
          _isLoadingPhases = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _phasesError =
              'Failed to load phases (status ${response.statusCode}).';
          _isLoadingPhases = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phasesError = 'Failed to connect to the server.';
        _isLoadingPhases = false;
      });
    }
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

  // Pick multiple images for phase level update
  Future<void> _pickPhotosForPhase(int phaseIndex) async {
    try {
      final List<XFile>? picked = await _picker.pickMultiImage(
        imageQuality: 80,
      );
      if (picked != null && picked.isNotEmpty) {
        setState(() {
          _phases[phaseIndex].phasePhotos = [
            ..._phases[phaseIndex].phasePhotos,
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

  // Remove photo from phase
  void _removePhasePhoto(int phaseIndex, int photoIndex) {
    setState(() {
      _phases[phaseIndex].phasePhotos.removeAt(photoIndex);
    });
  }

  // Open phase-level update dialog
  void _openPhaseUpdateDialog(int phaseIndex) {
    final phase = _phases[phaseIndex];
    final notesCtrl = TextEditingController(text: phase.phaseNotes);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.update, color: primary),
            const SizedBox(width: 12),
            Expanded(child: Text(phase.title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Subtasks',
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
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    for (
                      var sIndex = 0;
                      sIndex < phase.subtasks.length;
                      sIndex++
                    )
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: sIndex < phase.subtasks.length - 1 ? 8 : 0,
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: phase.subtasks[sIndex].completed,
                              onChanged: (val) {
                                ctx.findAncestorStateOfType<State>()?.setState(
                                  () {
                                    phase.subtasks[sIndex].completed =
                                        val ?? false;
                                  },
                                );
                              },
                              activeColor: primary,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    phase.subtasks[sIndex].title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    phase
                                            .subtasks[sIndex]
                                            .assignedWorkers
                                            .isEmpty
                                        ? 'No workers'
                                        : phase.subtasks[sIndex].assignedWorkers
                                              .join(', '),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
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
                  hintText: 'Add progress notes for this phase...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              const Text(
                'Photos',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: Icon(Icons.photo_camera, color: primary, size: 16),
                label: const Text('Add Photos'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onPressed: () => _pickPhotosForPhase(phaseIndex),
              ),
              if (phase.phasePhotos.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: phase.phasePhotos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, photoIndex) {
                      return _buildPhasePhotoThumb(phaseIndex, photoIndex);
                    },
                  ),
                ),
              ],
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
              Navigator.pop(ctx);

              // Show loading
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
                      Text('Submitting phase update...'),
                    ],
                  ),
                  duration: Duration(seconds: 30),
                ),
              );

              try {
                // Update all completed subtasks
                List<Future<http.Response>> requests = [];

                for (var subtask in phase.subtasks) {
                  if (subtask.completed) {
                    final requestBody = {
                      'status': 'completed',
                      'progress_notes': notes,
                    };

                    requests.add(
                      http.patch(
                        AppConfig.apiUri('subtasks/${subtask.id}/'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode(requestBody),
                      ),
                    );
                  }
                }

                // Wait for all requests
                if (requests.isNotEmpty) {
                  final responses = await Future.wait(requests);

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();

                  // Check first response for subscription
                  if (responses.isNotEmpty &&
                      SubscriptionHelper.handleResponse(
                        context,
                        responses[0],
                      )) {
                    return;
                  }

                  // Check if all succeeded
                  final allSuccess = responses.every(
                    (r) => r.statusCode == 200,
                  );

                  if (allSuccess && responses.isNotEmpty) {
                    setState(() {
                      phase.phaseNotes = notes;
                      phase.phasePhotos = [];
                      for (var subtask in phase.subtasks) {
                        if (subtask.completed) {
                          subtask.status = 'Completed';
                          subtask.completed = false;
                          subtask.notes = notes;
                        }
                      }
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Phase update submitted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to submit some updates'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select at least one subtask'),
                      backgroundColor: Colors.orange,
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
            },
            child: const Text('Submit Phase Update'),
          ),
        ],
      ),
    );
  }

  // Build photo thumbnail for phase
  Widget _buildPhasePhotoThumb(int phaseIndex, int photoIndex) {
    final xfile = _phases[phaseIndex].phasePhotos[photoIndex];
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
            onTap: () => _removePhasePhoto(phaseIndex, photoIndex),
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
          SizedBox(
            height: 200,
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

    if (_phases.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: const [
          SizedBox(
            height: 200,
            child: Center(
              child: Text(
                'No phases found for this project yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
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
        Row(
          children: [
            IconButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/supervisor');
                }
              },
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0C1935)),
              tooltip: 'Back',
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _projectDisplayName(),
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0C1935),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var pIndex = 0; pIndex < _phases.length; pIndex++) ...[
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _phases[pIndex].title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: (_phaseProgress(pIndex) / 100),
                          color: primary,
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${_phaseProgress(pIndex)}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      for (
                        var sIndex = 0;
                        sIndex < _phases[pIndex].subtasks.length;
                        sIndex++
                      ) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value:
                                    _phases[pIndex].subtasks[sIndex].completed,
                                onChanged: (val) {
                                  setState(() {
                                    _phases[pIndex].subtasks[sIndex].completed =
                                        val ?? false;
                                  });
                                },
                                activeColor: primary,
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _phases[pIndex].subtasks[sIndex].title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _phases[pIndex]
                                              .subtasks[sIndex]
                                              .assignedWorkers
                                              .isEmpty
                                          ? 'No workers assigned'
                                          : 'Workers: ${_phases[pIndex].subtasks[sIndex].assignedWorkers.join(', ')}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Phase level Update button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.update, size: 16),
                        label: const Text(
                          'Update Phase',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 40),
                        ),
                        onPressed: () => _openPhaseUpdateDialog(pIndex),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 24),
      ],
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
              if (isDesktop) Sidebar(activePage: 'Projects', keepVisible: true),
              Expanded(
                child: Column(
                  children: [
                    const DashboardHeader(title: 'Task Update'),
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
