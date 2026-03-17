import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import '../services/app_config.dart';
import '../services/auth_service.dart';
import '../services/app_time_service.dart';
import 'task_update.dart';
import 'all_workforce.dart';

class ProjectInfosPage extends StatefulWidget {
  final String projectTitle;
  final String projectLocation;
  final String projectImage;
  final double progress;
  final String? budget;
  final int projectId;

  const ProjectInfosPage({
    super.key,
    required this.projectTitle,
    required this.projectLocation,
    required this.projectImage,
    required this.progress,
    this.budget,
    required this.projectId,
  });

  @override
  State<ProjectInfosPage> createState() => _ProjectInfosPageState();
}

class _ProjectInfosPageState extends State<ProjectInfosPage> {
  Map<String, dynamic>? _clientInfo;
  Map<String, dynamic>? _projectInfo;
  List<dynamic>? _phases;
  bool _isLoading = true;
  String? _error;
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

  String? _asNonEmptyString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
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

  String? _resolveMediaUrl(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();
    if (value.isEmpty || value == 'null') return null;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final base = Uri.parse(AppConfig.apiBaseUrl);
    final origin = Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
    );

    if (value.startsWith('/')) return origin.resolve(value).toString();
    if (value.startsWith('media/')) return origin.resolve('/$value').toString();
    if (value.startsWith('client_images/')) {
      return origin.resolve('/media/$value').toString();
    }

    return origin.resolve('/media/$value').toString();
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
    } catch (_) {
      return null;
    }
  }

  double _calculateProjectProgress() {
    if (_phases == null || _phases!.isEmpty) return 0.0;

    int totalSubtasks = 0;
    int completedSubtasks = 0;

    for (final phase in _phases!) {
      final phaseMap = phase as Map<String, dynamic>;
      final List<dynamic> subtasks = phaseMap['subtasks'] ?? [];
      totalSubtasks += subtasks.length;
      for (final subtask in subtasks) {
        final subtaskMap = subtask as Map<String, dynamic>;
        if (subtaskMap['status'] == 'completed') completedSubtasks++;
      }
    }

    if (totalSubtasks == 0) return 0.0;
    return completedSubtasks / totalSubtasks;
  }

  Future<void> _fetchProjectDetails() async {
    try {
      final authUser = AuthService().currentUser;
      final userId = authUser?['user_id'];
      final authProjectId = authUser?['project_id'];
      final scopeSuffix = (userId != null) ? '&user_id=$userId' : '';

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
      final embeddedClient = projectData['client'];
      if (embeddedClient is Map<String, dynamic>) {
        _clientInfo = Map<String, dynamic>.from(embeddedClient);
      }

      setState(() {
        _projectInfo = projectData;
      });

      if (clientId != null) {
        final candidateClientUrls = <String>[
          if (userId != null) 'clients/$clientId/?user_id=$userId',
          'clients/$clientId/?project_id=${widget.projectId}',
          'clients/$clientId/',
        ];

        bool fetched = false;
        for (final url in candidateClientUrls) {
          final response = await http.get(AppConfig.apiUri(url));
          if (response.statusCode == 200) {
            final mapped = _firstRecordFromResponse(jsonDecode(response.body));
            if (mapped != null) {
              setState(() {
                _clientInfo = mapped;
              });
              fetched = true;
              break;
            }
          }
        }

        if (!fetched) {
          final listResponse = await http.get(
            AppConfig.apiUri(
              'clients/?project_id=${widget.projectId}$scopeSuffix',
            ),
          );
          if (listResponse.statusCode == 200) {
            final mapped = _firstRecordFromResponse(
              jsonDecode(listResponse.body),
            );
            if (mapped != null) {
              setState(() {
                _clientInfo = mapped;
              });
            }
          }
        }
      } else {
        final listResponse = await http.get(
          AppConfig.apiUri(
            'clients/?project_id=${widget.projectId}$scopeSuffix',
          ),
        );
        if (listResponse.statusCode == 200) {
          final mapped = _firstRecordFromResponse(
            jsonDecode(listResponse.body),
          );
          if (mapped != null) {
            setState(() {
              _clientInfo = mapped;
            });
          }
        }
      }

      final phasesUrl = userId != null
          ? 'phases/?project_id=${widget.projectId}&user_id=$userId'
          : 'phases/?project_id=${widget.projectId}';
      final phasesResponse = await http.get(AppConfig.apiUri(phasesUrl));
      if (phasesResponse.statusCode == 200) {
        setState(() {
          _phases = jsonDecode(phasesResponse.body) as List<dynamic>;
        });
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading project details: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildProfileAvatar({
    required double radius,
    required String? photoUrl,
  }) {
    final url = (photoUrl ?? '').trim();
    if (url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[200],
        child: Icon(
          Icons.person_outline,
          color: Colors.grey[500],
          size: radius,
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: Image.network(
          url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.person_outline, color: Colors.grey[500], size: radius),
        ),
      ),
    );
  }

  Widget _buildProjectImage(String imagePath) {
    try {
      if (imagePath.startsWith('assets/')) {
        return Image.asset(
          imagePath,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }

      final resolvedUrl = _resolveMediaUrl(imagePath);
      if (resolvedUrl != null) {
        return Image.network(
          resolvedUrl,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }

      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }

      return _buildPlaceholder();
    } catch (_) {
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

  Widget _clientCard({required bool isMobile}) {
    if (_clientInfo == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(child: Text('No client assigned')),
      );
    }

    final client = _clientInfo!;
    final fullName =
        '${client['first_name'] ?? ''} ${client['last_name'] ?? ''}'.trim();

    return Container(
      width: isMobile ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Client:',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildProfileAvatar(
                radius: 26,
                photoUrl: _resolveMediaUrl(client['photo']),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? 'N/A' : fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (client['email'] ?? 'N/A').toString(),
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    Text(
                      (client['phone_number'] ?? 'N/A').toString(),
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatSubtaskStatus(dynamic rawStatus) {
    final status = (rawStatus ?? '').toString().toLowerCase();
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'in_progress':
        return 'In Progress';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'Completed':
        return const Color(0xFF757575);
      case 'In Progress':
        return const Color(0xFFFF6F00);
      default:
        return Colors.grey.shade700;
    }
  }

  Color _statusBackgroundColor(String status) {
    switch (status) {
      case 'Completed':
        return const Color(0xFF757575).withOpacity(0.12);
      case 'In Progress':
        return const Color(0xFFFF6F00).withOpacity(0.12);
      default:
        return Colors.grey.shade200;
    }
  }

  int _phaseProgressPercent(Map<String, dynamic> phaseMap) {
    final subtasks = (phaseMap['subtasks'] as List<dynamic>? ?? []);
    if (subtasks.isEmpty) return 0;
    final completed = subtasks.where((subtask) {
      final map = subtask as Map<String, dynamic>;
      return (map['status'] ?? '').toString().toLowerCase() == 'completed';
    }).length;
    return ((completed / subtasks.length) * 100).round();
  }

  String _assignedWorkersLabel(dynamic assignedWorkersRaw) {
    final assignedWorkers = assignedWorkersRaw as List<dynamic>? ?? [];
    if (assignedWorkers.isEmpty) return 'No workers assigned';

    final names = assignedWorkers.map((worker) {
      final workerMap = worker as Map<String, dynamic>;
      final first = (workerMap['first_name'] ?? '').toString().trim();
      final last = (workerMap['last_name'] ?? '').toString().trim();
      final fullName = '$first $last'.trim();
      if (fullName.isNotEmpty) return fullName;
      return (workerMap['role'] ?? 'Worker').toString();
    }).toList();

    return 'Workers: ${names.join(', ')}';
  }

  Widget _buildTasksToDoSection() {
    if (_phases == null || _phases!.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Text(
          'No tasks available yet for this project.',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
      );
    }

    return Column(
      children: _phases!.map((phase) {
        final phaseMap = phase as Map<String, dynamic>;
        final phaseName = (phaseMap['phase_name'] ?? 'Untitled Phase')
            .toString();
        final subtasks = (phaseMap['subtasks'] as List<dynamic>? ?? []);
        final progress = _phaseProgressPercent(phaseMap);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 2,
            margin: EdgeInsets.zero,
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
                          phaseName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: progress / 100,
                          color: const Color(0xFFFF6F00),
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '$progress%',
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
                  child: subtasks.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Text(
                            'No subtasks yet in this phase.',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                        )
                      : Column(
                          children: subtasks.map((subtask) {
                            final subtaskMap = subtask as Map<String, dynamic>;
                            final title =
                                (subtaskMap['title'] ?? 'Untitled Subtask')
                                    .toString();
                            final status = _formatSubtaskStatus(
                              subtaskMap['status'],
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Card(
                                color: Colors.white,
                                margin: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _statusBackgroundColor(
                                                status,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                color: _statusTextColor(status),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey[200]!,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.person_outline,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _assignedWorkersLabel(
                                                  subtaskMap['assigned_workers'],
                                                ),
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if ((subtaskMap['progress_notes'] ?? '')
                                          .toString()
                                          .trim()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Notes: ${(subtaskMap['progress_notes']).toString().trim()}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isMobile = screenWidth < 768;

    final daysLeft = _calculateDaysLeft();
    final projectDescription =
        _asNonEmptyString(_projectInfo?['description']) ??
        _asNonEmptyString(_projectInfo?['project_description']) ??
        _asNonEmptyString(_projectInfo?['details']);
    final projectBannerImage =
        _asNonEmptyString(_projectInfo?['project_image']) ??
        widget.projectImage;

    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text('Error: $_error'))
        : SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (daysLeft != null && _showDaysLeftReminder)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 18,
                    ),
                    decoration: BoxDecoration(
                      color: daysLeft <= 3
                          ? const Color(0xFFFFE0B2)
                          : const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(10),
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
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showDaysLeftReminder = false;
                            });
                          },
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      color: const Color(0xFF0C1935),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildProjectImage(projectBannerImage),
                ),
                const SizedBox(height: 24),
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
                if (projectDescription != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    projectDescription,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
                const SizedBox(height: 25),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(_calculateProjectProgress() * 100).round()}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[400],
                    ),
                  ),
                ),
                LinearProgressIndicator(
                  value: _calculateProjectProgress(),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(20),
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 30),
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
                                  : 'N/A',
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
                        value: (_projectInfo?['start_date'] ?? 'N/A')
                            .toString(),
                        color: const Color(0xFF4CAF50),
                      ),
                      const SizedBox(height: 12),
                      _projectDetailCard(
                        icon: Icons.event_available,
                        title: 'Expected Date to End',
                        value: (_projectInfo?['end_date'] ?? 'N/A').toString(),
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
                              : 'N/A',
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
                          value: (_projectInfo?['start_date'] ?? 'N/A')
                              .toString(),
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _projectDetailCard(
                          icon: Icons.event_available,
                          title: 'Expected Date to End',
                          value: (_projectInfo?['end_date'] ?? 'N/A')
                              .toString(),
                          color: const Color(0xFFF44336),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AllWorkforcePage(
                            projectId: widget.projectId,
                            projectTitle: widget.projectTitle,
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF6F00),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'View Workforce',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _clientCard(isMobile: isMobile),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tasks to Do',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6F00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TaskProgressPage(
                              initialSidebarVisible: false,
                              projectId: widget.projectId,
                            ),
                          ),
                        );
                      },
                      child: const Text('Manage'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTasksToDoSection(),
                const SizedBox(height: 32),
              ],
            ),
          );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          if (isDesktop)
            const Sidebar(activePage: 'Projects', keepVisible: true),
          Expanded(
            child: Column(
              children: [
                DashboardHeader(onMenuPressed: () {}, title: 'Projects'),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
