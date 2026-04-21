import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/responsive_page_layout.dart';
import 'project_details_page.dart' as task_details;
import 'all_workers_page.dart';
import '../services/app_config.dart';
import '../services/auth_service.dart';
import '../services/app_time_service.dart';

class ProjectDetailsPage extends StatefulWidget {
  final String projectTitle;
  final String projectLocation;
  final String projectImage;
  final double progress;
  final String? budget;
  final int projectId;
  final bool useResponsiveLayout;

  const ProjectDetailsPage({
    super.key,
    required this.projectTitle,
    required this.projectLocation,
    required this.projectImage,
    required this.progress,
    this.budget,
    required this.projectId,
    this.useResponsiveLayout = true,
  });

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  String? _asNonEmptyString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  String? _resolveMediaUrl(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();
    if (value.isEmpty || value == 'null') return null;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    // AppConfig.apiBaseUrl includes `/api/`; media is served from the same origin.
    final base = Uri.parse(AppConfig.apiBaseUrl);
    final origin = Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
    );

    if (value.startsWith('/')) {
      return origin.resolve(value).toString();
    }
    if (value.startsWith('media/')) {
      return origin.resolve('/$value').toString();
    }
    if (value.startsWith('client_images/')) {
      return origin.resolve('/media/$value').toString();
    }
    if (value.startsWith('fieldworker_images/')) {
      return origin.resolve('/media/$value').toString();
    }

    // Fallback: assume it's under MEDIA_URL.
    return origin.resolve('/media/$value').toString();
  }

  Widget _buildProfileAvatar({
    required double radius,
    required String? photoUrl,
    IconData fallbackIcon = Icons.person_outline,
  }) {
    final size = radius * 2;
    final url = (photoUrl ?? '').trim();

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        color: Colors.grey[200],
        child: Icon(fallbackIcon, color: Colors.grey[500], size: radius),
      );
    }

    if (url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[200],
        child: Icon(fallbackIcon, color: Colors.grey[500], size: radius),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return fallback();
          },
          errorBuilder: (context, error, stackTrace) {
            return fallback();
          },
        ),
      ),
    );
  }

  bool _showDaysLeftReminder = true;

  @override
  void initState() {
    super.initState();
    AppTimeService.overrideNotifier.addListener(_onTestTimeChanged);
    _fetchProjectDetails();
  }

  @override
  void dispose() {
    AppTimeService.overrideNotifier.removeListener(_onTestTimeChanged);
    super.dispose();
  }

  void _onTestTimeChanged() {
    if (!mounted) return;
    setState(() {});
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is Map) {
      final map = value.cast<String, dynamic>();
      return _toInt(map['id'] ?? map['client_id']);
    }
    return int.tryParse(value.toString());
  }

  Map<String, dynamic>? _firstRecordFromResponse(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('results') && decoded['results'] is List) {
        final results = decoded['results'] as List<dynamic>;
        if (results.isNotEmpty && results.first is Map) {
          return Map<String, dynamic>.from(results.first as Map);
        }
      }
      return decoded;
    }

    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      return Map<String, dynamic>.from(decoded.first as Map);
    }

    return null;
  }

  int? _calculateDaysLeft() {
    if (_projectInfo == null || _projectInfo!['end_date'] == null) return null;
    try {
      final endDateStr = _projectInfo!['end_date'] as String;
      if (endDateStr.isEmpty) return null;
      final endDate = DateTime.parse(endDateStr);
      final now = AppTimeService.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = endDate.difference(today).inDays;
      return diff >= 0 ? diff : 0;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic>? _clientInfo;
  Map<String, dynamic>? _projectInfo;
  List<dynamic>? _phases;
  bool _isLoading = true;
  String? _error;

  // Calculate overall project progress based on phases (matching task_progress.dart)
  double _calculateProjectProgress() {
    if (_phases == null || _phases!.isEmpty) return 0.0;

    // Count all subtasks across all phases
    int totalSubtasks = 0;
    int completedSubtasks = 0;

    for (var phase in _phases!) {
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

  Future<Map<String, dynamic>?> _fetchClientInfo({
    required int? clientId,
    required dynamic userId,
    required String scopeSuffix,
    Map<String, dynamic>? embeddedClient,
  }) async {
    if (clientId != null) {
      final candidateClientUrls = <String>[
        if (userId != null) 'clients/$clientId/?user_id=$userId',
        'clients/$clientId/?project_id=${widget.projectId}',
        'clients/$clientId/',
      ];

      for (final url in candidateClientUrls) {
        try {
          final clientResponse = await http.get(AppConfig.apiUri(url));
          if (clientResponse.statusCode == 200) {
            final decoded = jsonDecode(clientResponse.body);
            final mapped = _firstRecordFromResponse(decoded);
            if (mapped != null) return mapped;
          }
        } catch (_) {
          // Continue to next candidate URL.
        }
      }
    }

    try {
      final listResponse = await http.get(
        AppConfig.apiUri('clients/?project_id=${widget.projectId}$scopeSuffix'),
      );
      if (listResponse.statusCode == 200) {
        final decoded = jsonDecode(listResponse.body);
        final mapped = _firstRecordFromResponse(decoded);
        if (mapped != null) return mapped;
      }
    } catch (_) {
      // Fall through to embedded client fallback.
    }

    return embeddedClient;
  }

  Future<List<dynamic>?> _fetchProjectPhases({required dynamic userId}) async {
    try {
      final phasesUrl = userId != null
          ? 'phases/?project_id=${widget.projectId}&user_id=$userId'
          : 'phases/?project_id=${widget.projectId}';
      final phasesResponse = await http.get(AppConfig.apiUri(phasesUrl));
      if (phasesResponse.statusCode == 200) {
        final phases = jsonDecode(phasesResponse.body) as List<dynamic>;
        phases.sort(_comparePhasesNewestFirst);
        return phases;
      }
    } catch (_) {
      // Keep existing phases if fetch fails.
    }
    return null;
  }

  int _phaseSortScore(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      final asInt = int.tryParse(value);
      if (asInt != null) return asInt;
      final asDate = DateTime.tryParse(value);
      if (asDate != null) return asDate.millisecondsSinceEpoch;
    }
    return 0;
  }

  int _comparePhasesNewestFirst(dynamic a, dynamic b) {
    final aMap = a is Map ? a.cast<String, dynamic>() : const <String, dynamic>{};
    final bMap = b is Map ? b.cast<String, dynamic>() : const <String, dynamic>{};

    final createdCompare =
        _phaseSortScore(bMap['created_at']).compareTo(_phaseSortScore(aMap['created_at']));
    if (createdCompare != 0) return createdCompare;

    return _phaseSortScore(bMap['phase_id']).compareTo(_phaseSortScore(aMap['phase_id']));
  }

  Future<void> _refreshProjectPlanPreview() async {
    final authUser = AuthService().currentUser;
    final userId = authUser?['user_id'];
    final refreshedPhases = await _fetchProjectPhases(userId: userId);
    if (!mounted || refreshedPhases == null) return;

    setState(() {
      _phases = refreshedPhases;
    });
  }

  Future<void> _fetchProjectDetails() async {
    try {
      final authUser = AuthService().currentUser;
      final userId = authUser?['user_id'];
      final authProjectId = authUser?['project_id'];
      final scopeSuffix = (userId != null) ? '&user_id=$userId' : '';

      // First fetch project details to get client_id
      final candidateProjectUrls = <String>[
        if (userId != null) 'projects/${widget.projectId}/?user_id=$userId',
        if (authProjectId != null)
          'projects/${widget.projectId}/?project_id=$authProjectId',
        'projects/${widget.projectId}/',
      ];

      http.Response? projectResponse;
      for (final url in candidateProjectUrls) {
        final response = await http.get(AppConfig.apiUri(url));
        if (response.statusCode == 200) {
          projectResponse = response;
          break;
        }
        print(
          'Project details request failed (${response.statusCode}) for URL: $url',
        );
      }

      if (projectResponse == null) {
        setState(() {
          _error = 'Failed to load project details';
          _isLoading = false;
        });
        return;
      }

      final projectData = jsonDecode(projectResponse.body);
      final clientId = _toInt(projectData['client']);
      Map<String, dynamic>? embeddedClient;

      // Some APIs embed client details directly in project payload.
      final embeddedClientRaw = projectData['client'];
      if (embeddedClientRaw is Map) {
        embeddedClient = Map<String, dynamic>.from(
          embeddedClientRaw.cast<String, dynamic>(),
        );
      }

      final clientFuture = _fetchClientInfo(
        clientId: clientId,
        userId: userId,
        scopeSuffix: scopeSuffix,
        embeddedClient: embeddedClient,
      );
      final phasesFuture = _fetchProjectPhases(userId: userId);

      final resolved = await Future.wait<dynamic>([clientFuture, phasesFuture]);
      final resolvedClient = resolved[0] as Map<String, dynamic>?;
      final resolvedPhases = resolved[1] as List<dynamic>?;

      setState(() {
        _projectInfo = projectData;
        _clientInfo = resolvedClient;
        _phases = resolvedPhases ?? _phases;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading project details: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = _calculateDaysLeft();
    final progressPercent = (_calculateProjectProgress() * 100).round();
    final projectDescription =
        _asNonEmptyString(_projectInfo?['description']) ??
        _asNonEmptyString(_projectInfo?['project_description']) ??
        _asNonEmptyString(_projectInfo?['details']);
    final projectBannerImage =
        _asNonEmptyString(_projectInfo?['project_image']) ??
        widget.projectImage;
    if (_isLoading) {
      if (!widget.useResponsiveLayout) {
        return const Center(child: CircularProgressIndicator());
      }

      return const Scaffold(
        backgroundColor: Color(0xFFF4F6F9),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      if (!widget.useResponsiveLayout) {
        return Center(child: Text('Error: $_error'));
      }

      return Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        body: Center(child: Text('Error: $_error')),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    final detailsContent = SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (daysLeft != null && _showDaysLeftReminder)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              decoration: BoxDecoration(
                color: daysLeft <= 3
                    ? const Color(0xFFFFE0B2)
                    : const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: daysLeft <= 3
                      ? const Color(0xFFFF9800)
                      : const Color(0xFF2196F3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.hourglass_bottom,
                    color: daysLeft <= 3
                        ? const Color(0xFFFF9800)
                        : const Color(0xFF2196F3),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      daysLeft == 0
                          ? 'Today is the expected end date for this project'
                          : daysLeft == 1
                          ? '1 day left before the expected end date.'
                          : '$daysLeft days left before the expected end date.',
                      style: TextStyle(
                        color: daysLeft <= 3
                            ? const Color(0xFFFF9800)
                            : const Color(0xFF0C1935),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Dismiss reminder',
                    onPressed: () {
                      setState(() {
                        _showDaysLeftReminder = false;
                      });
                    },
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: daysLeft <= 3
                          ? const Color(0xFFFF9800)
                          : const Color(0xFF2196F3),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ],
              ),
            ),
          // Back button
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                color: const Color(0xFF0C1935),
                tooltip: 'Back to Projects',
              ),
              const SizedBox(width: 8),
              Text(
                'Back to Projects',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Banner Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildProjectImage(projectBannerImage),
          ),

          const SizedBox(height: 24),

          // Project Title + Client Card
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.projectTitle,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.projectLocation,
                        style:
                            const TextStyle(fontSize: 15, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _clientInfo != null
                          ? _infoCard(
                              title: "Client:",
                              name:
                                  '${_clientInfo!['first_name']} ${_clientInfo!['last_name']}',
                              email: _clientInfo!['email'] ?? 'N/A',
                              phone: _clientInfo!['phone_number'] ?? 'N/A',
                              photoUrl: _resolveMediaUrl(_clientInfo!['photo']),
                              isMobile: true,
                            )
                          : Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Center(
                                  child: Text('No client assigned')),
                            ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.edit, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _showDeactivationModal,
                      icon: const Icon(Icons.settings, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.projectTitle,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.projectLocation,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 280,
                  child: Row(
                    children: [
                      Expanded(
                        child: _clientInfo != null
                            ? _infoCard(
                                title: "Client:",
                                name:
                              '${_clientInfo!['first_name']} ${_clientInfo!['last_name']}',
                          email: _clientInfo!['email'] ?? 'N/A',
                          phone: _clientInfo!['phone_number'] ?? 'N/A',
                          photoUrl: _resolveMediaUrl(_clientInfo!['photo']),
                          isMobile: false,
                        )
                            : Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child:
                                    const Center(child: Text('No client assigned')),
                              ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.edit, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _showDeactivationModal,
                        icon: const Icon(Icons.settings, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          if (projectDescription != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                projectDescription,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
            ),
          ],

          const SizedBox(height: 25),

          // Progress bar number
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "${(_calculateProjectProgress() * 100).round()}%",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red[400],
              ),
            ),
          ),

          // Progress bar
          LinearProgressIndicator(
            value: _calculateProjectProgress(),
            minHeight: 8,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade400),
          ),

          const SizedBox(height: 30),

          // Project Details Cards
          if (isMobile)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _projectDetailCard(
                        icon: Icons.calendar_today,
                        title: 'Duration',
                        value: _projectInfo != null
                            ? '${_projectInfo!['duration_days'] ?? 'N/A'} days'
                            : 'Loading...',
                        color: const Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _projectDetailCard(
                        icon: Icons.hourglass_bottom,
                        title: 'Days Left',
                        value: _calculateDaysLeft() != null
                            ? '${_calculateDaysLeft()} days'
                            : 'N/A',
                        color: const Color(0xFFFF9800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _projectDetailCard(
                  icon: Icons.event,
                  title: 'Start Date',
                  value: _projectInfo?['start_date'] ?? 'N/A',
                  color: const Color(0xFF4CAF50),
                ),
                const SizedBox(height: 12),
                _projectDetailCard(
                  icon: Icons.event_available,
                  title: 'Expected Date to End',
                  value: _projectInfo?['end_date'] ?? 'N/A',
                  color: const Color(0xFFF44336),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _projectDetailCard(
                    icon: Icons.calendar_today,
                    title: 'Duration',
                    value: _projectInfo != null
                        ? '${_projectInfo!['duration_days'] ?? 'N/A'} days'
                        : 'Loading...',
                    color: const Color(0xFF2196F3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _projectDetailCard(
                    icon: Icons.hourglass_bottom,
                    title: 'Days Left',
                    value: _calculateDaysLeft() != null
                        ? '${_calculateDaysLeft()} days'
                        : 'N/A',
                    color: const Color(0xFFFF9800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _projectDetailCard(
                    icon: Icons.event,
                    title: 'Start Date',
                    value: _projectInfo?['start_date'] ?? 'N/A',
                    color: const Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _projectDetailCard(
                    icon: Icons.event_available,
                    title: 'Expected Date to End',
                    value: _projectInfo?['end_date'] ?? 'N/A',
                    color: const Color(0xFFF44336),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 24),

          // Manage Workforce Button
          

          const SizedBox(height: 20),
          const Divider(),

          const SizedBox(height: 24),

          // Project Plan Title + View Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Project Plan",
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AllWorkersPage(
                            projectId: widget.projectId,
                            projectTitle: widget.projectTitle,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.people_outlined, size: 16),
                    label: const Text("View Workforce"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A18),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              task_details.ProjectTaskDetailsPage(
                                projectTitle: widget.projectTitle,
                                projectLocation: widget.projectLocation,
                                projectImage: widget.projectImage,
                                progress: widget.progress,
                                budget: widget.budget,
                                projectId: widget.projectId,
                                projectStartDate: _projectInfo?['start_date'],
                              ),
                        ),
                      );
                      await _refreshProjectPlanPreview();
                    },
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text("Manage Project Plan"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Phases Display
          if (_phases != null && _phases!.isNotEmpty)
            Column(
              children: [
                ..._phases!.take(3).map((phase) {
                  final phaseMap = phase as Map<String, dynamic>;
                  final subtasks = phaseMap['subtasks'] as List<dynamic>? ?? [];
                  final completedCount = subtasks
                      .where((s) =>
                          (s as Map<String, dynamic>)['status'] == 'completed')
                      .length;
                  final progress = subtasks.isEmpty
                      ? 0.0
                      : completedCount / subtasks.length;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                phaseMap['phase_name'] ?? 'Phase',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF7A18).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF7A18),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.assignment_outlined,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              '$completedCount / ${subtasks.length} subtasks completed',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF757575),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF7A18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (_phases!.length > 3)
                  Center(
                    child: Text(
                      '+${_phases!.length - 3} more phases',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Text(
                  'No phases available',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),

          SizedBox(height: isMobile ? 80 : 32), // Space for bottom nav
        ],
      ),
    );

    if (!widget.useResponsiveLayout) {
      return detailsContent;
    }

    return ResponsivePageLayout(
      currentPage: 'Projects',
      title: 'Project Details',
      child: detailsContent,
    );
  }

  Widget _projectDetailCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectImage(String imagePath) {
    try {
      // Asset image
      if (imagePath.startsWith('assets/')) {
        return Image.asset(
          imagePath,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        );
      }

      final resolvedUrl = _resolveMediaUrl(imagePath);
      if (resolvedUrl != null) {
        return Image.network(
          resolvedUrl,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        );
      }

      // File image (local path)
      try {
        final file = File(imagePath);
        if (file.existsSync()) {
          return Image.file(
            file,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholder();
            },
          );
        }
      } catch (e) {
        // Ignore file errors, fallback to placeholder
      }

      return _buildPlaceholder();
    } catch (e) {
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 220,
      width: double.infinity,
      color: Colors.grey[300],
      child: const Center(child: Icon(Icons.image_not_supported, size: 40)),
    );
  }

  bool _isProjectActive() {
    final status = _projectInfo?['status']?.toString().toLowerCase() ?? 'active';
    return status == 'active';
  }

  bool _isProjectOnHold() {
    final status = _projectInfo?['status']?.toString().toLowerCase() ?? 'active';
    return status == 'on hold';
  }

  void _showDeactivationModal() {
    final isActive = _isProjectActive();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Project Status'),
          content: isActive
              ? const Text('What would you like to do with this project?')
              : const Text('Activate this project or continue managing its status?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            if (isActive)
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _setProjectStatus('On Hold');
                },
                child: const Text(
                  'Hold the Project',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            if (isActive)
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _setProjectStatus('Deactivated');
                },
                child: const Text(
                  'Deactivate',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            if (!isActive)
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _setProjectStatus('Active');
                },
                child: const Text(
                  'Activate Project',
                  style: TextStyle(color: Colors.green),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _setProjectStatus(String targetStatus) async {
    try {
      final authUser = AuthService().currentUser;
      final userId = authUser?['user_id'];
      
      // Get the current status
      final currentStatus = _projectInfo?['status']?.toString() ?? 'Active';
      final url = userId != null
          ? 'projects/${widget.projectId}/deactivate/?user_id=$userId'
          : 'projects/${widget.projectId}/deactivate/';

      // Keep calling deactivate until we reach the target status
      var currentStatusLoop = currentStatus;
      while (currentStatusLoop != targetStatus) {
        final response = await http.post(AppConfig.apiUri(url));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          currentStatusLoop = data['status'] ?? 'Unknown';
          
          if (currentStatusLoop == targetStatus) {
            if (!mounted) return;
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Project status changed to: $targetStatus'),
                backgroundColor: Colors.green,
              ),
            );
            
            setState(() {
              _projectInfo?['status'] = targetStatus;
            });
            break;
          }
        } else {
          if (!mounted) return;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to change project status (${response.statusCode})'),
              backgroundColor: Colors.red,
            ),
          );
          break;
        }
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _infoCard({
    required String title,
    required String name,
    required String email,
    required String phone,
    required String? photoUrl,
    required bool isMobile,
  }) {
    return isMobile
        ? Row(
            children: [
              _buildProfileAvatar(radius: 24, photoUrl: photoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        : Row(
            children: [
              _buildProfileAvatar(radius: 24, photoUrl: photoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
  }
}
