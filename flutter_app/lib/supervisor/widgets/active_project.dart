import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/auth_service.dart';
import '../../services/app_config.dart';

class ActiveProject extends StatefulWidget {
  final Function(int)? onProjectLoaded;

  const ActiveProject({super.key, this.onProjectLoaded});

  @override
  State<ActiveProject> createState() => _ActiveProjectState();
}

class _ActiveProjectState extends State<ActiveProject> {
  Map<String, dynamic>? _cachedProject;
  List<dynamic>? _cachedPhases;
  bool _isLoading = true;
  bool _hasNotifiedParent = false;

  @override
  void initState() {
    super.initState();
    _fetchSupervisorProject();
  }

  Future<void> _fetchSupervisorProject() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final projectId = authService.currentUser?['project_id'];

      print('Fetching project for supervisor with project_id: $projectId');

      if (projectId == null) {
        print('No project assigned to this supervisor');
        setState(() {
          _isLoading = false;
          _cachedProject = null;
        });
        return;
      }

      final projectResponse = await http.get(
        AppConfig.apiUri('projects/$projectId/'),
      );

      print('Project API response status: ${projectResponse.statusCode}');

      if (projectResponse.statusCode != 200) {
        print('Failed to fetch project: ${projectResponse.statusCode}');
        setState(() {
          _isLoading = false;
          _cachedProject = null;
        });
        return;
      }

      final Map<String, dynamic> project = jsonDecode(projectResponse.body);
      print('Project fetched successfully: ${project['project_name']}');

      // Fetch phases to calculate accurate progress
      try {
        final phasesResponse = await http.get(
          AppConfig.apiUri('phases/?project_id=$projectId'),
        );
        if (phasesResponse.statusCode == 200) {
          _cachedPhases = jsonDecode(phasesResponse.body) as List<dynamic>;
          print('Phases fetched: ${_cachedPhases?.length ?? 0} phases');
        }
      } catch (e) {
        print('Error fetching phases: $e');
      }

      setState(() {
        _cachedProject = project;
        _isLoading = false;
      });

      // Notify parent after state is updated
      if (!_hasNotifiedParent &&
          widget.onProjectLoaded != null &&
          projectId != null) {
        _hasNotifiedParent = true;
        final int finalProjectId = projectId is int
            ? projectId
            : int.parse(projectId.toString());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          print('🔔 Calling onProjectLoaded with projectId: $finalProjectId');
          widget.onProjectLoaded!(finalProjectId);
          print('✅ onProjectLoaded callback executed');
        });
      }
    } catch (e) {
      print('Error fetching supervisor project: $e');
      setState(() {
        _isLoading = false;
        _cachedProject = null;
      });
    }
  }

  void _notifyParentIfNeeded(int projectId) {
    if (!_hasNotifiedParent && widget.onProjectLoaded != null) {
      _hasNotifiedParent = true;
      // Defer the callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('🔔 Calling onProjectLoaded with projectId: $projectId');
        widget.onProjectLoaded!(projectId);
        print('✅ onProjectLoaded callback executed');
      });
    }
  }

  double _calculateProgress(Map<String, dynamic> project) {
    if (_cachedPhases == null || _cachedPhases!.isEmpty) return 0.0;

    // Count all subtasks across all phases (matching task_progress.dart)
    int totalSubtasks = 0;
    int completedSubtasks = 0;

    for (var phase in _cachedPhases!) {
      final phaseMap = phase as Map<String, dynamic>;
      final List<dynamic> subtasks = phaseMap['subtasks'] ?? [];

      totalSubtasks += subtasks.length;
      for (var subtask in subtasks) {
        final subtaskMap = subtask as Map<String, dynamic>;
        if (subtaskMap['status'] == 'completed') {
          completedSubtasks++;
        }
      }
    }

    if (totalSubtasks == 0) return 0.0;
    return completedSubtasks / totalSubtasks;
  }

  String _getLocation(Map<String, dynamic> project) {
    final street = project['street'] ?? '';
    final barangay = project['barangay_name'] ?? '';
    final city = project['city_name'] ?? '';
    final province = project['province_name'] ?? '';

    List<String> addressParts = [];
    if (street.isNotEmpty) addressParts.add(street);
    if (barangay.isNotEmpty) addressParts.add(barangay);
    if (city.isNotEmpty) addressParts.add(city);
    if (province.isNotEmpty) addressParts.add(province);

    return addressParts.isNotEmpty ? addressParts.join(', ') : 'Location TBA';
  }

  @override
  Widget build(BuildContext context) {
    // Show loading spinner
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show no project message
    if (_cachedProject == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Center(child: Text('No project assigned')),
      );
    }

    // Show project data (cached, won't disappear on rebuild)
    final project = _cachedProject!;
    final projectName = project['project_name'] ?? 'Unknown Project';
    final projectId = project['project_id'];
    final location = _getLocation(project);
    final progress = _calculateProgress(project);
    final progressPercentage = (progress * 100).toStringAsFixed(0);

    // Notify parent after successful build
    if (projectId != null) {
      final int finalProjectId = projectId is int
          ? projectId
          : int.parse(projectId.toString());
      _notifyParentIfNeeded(finalProjectId);
    }

    return GestureDetector(
      onTap: () {
        // TODO: navigate to project details
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => Placeholder()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    projectName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E3A44),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "$progressPercentage%",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color.fromARGB(255, 243, 146, 1),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 150,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey,
                    color: const Color.fromARGB(255, 243, 146, 1),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
