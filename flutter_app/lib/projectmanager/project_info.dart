import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/responsive_page_layout.dart';
import 'project_details_page.dart' as task_details;
import '../services/app_config.dart';
import '../services/auth_service.dart';

class ProjectDetailsPage extends StatefulWidget {
  final String projectTitle;
  final String projectLocation;
  final String projectImage;
  final double progress;
  final String? budget;
  final int projectId;
  final bool useResponsiveLayout;
  final bool showSupervisorAssigned;

  const ProjectDetailsPage({
    super.key,
    required this.projectTitle,
    required this.projectLocation,
    required this.projectImage,
    required this.progress,
    this.budget,
    required this.projectId,
    this.useResponsiveLayout = true,
    this.showSupervisorAssigned = true,
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

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is Map) {
      final map = value.cast<String, dynamic>();
      return _toInt(map['id'] ?? map['client_id'] ?? map['supervisor_id']);
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
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = endDate.difference(today).inDays;
      return diff >= 0 ? diff : 0;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic>? _clientInfo;
  Map<String, dynamic>? _supervisorInfo;
  Map<String, dynamic>? _projectInfo;
  List<dynamic>? _phases;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProjectDetails();
  }

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

  Future<void> _fetchProjectDetails() async {
    try {
      final authUser = AuthService().currentUser;
      final userId = authUser?['user_id'];
      final authProjectId = authUser?['project_id'];
      final scopeSuffix = (userId != null) ? '&user_id=$userId' : '';

      // First fetch project details to get client_id and supervisor_id
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
      final supervisorId = _toInt(projectData['supervisor']);

      // Some APIs embed client details directly in project payload.
      final embeddedClient = projectData['client'];
      if (embeddedClient is Map<String, dynamic>) {
        _clientInfo = Map<String, dynamic>.from(embeddedClient);
      }

      setState(() {
        _projectInfo = projectData;
      });

      print('🔍 Project ID: ${widget.projectId}');
      print('🔍 Client ID: $clientId');
      print('🔍 Supervisor ID: $supervisorId');

      // Fetch client information
      if (clientId != null) {
        try {
          final candidateClientUrls = <String>[
            if (userId != null) 'clients/$clientId/?user_id=$userId',
            'clients/$clientId/?project_id=${widget.projectId}',
            'clients/$clientId/',
          ];

          bool fetched = false;
          for (final url in candidateClientUrls) {
            final clientResponse = await http.get(AppConfig.apiUri(url));
            if (clientResponse.statusCode == 200) {
              final decoded = jsonDecode(clientResponse.body);
              final mapped = _firstRecordFromResponse(decoded);
              if (mapped != null) {
                setState(() {
                  _clientInfo = mapped;
                  print('✅ Client info fetched: ${_clientInfo?['email']}');
                });
                fetched = true;
                break;
              }
            } else {
              print(
                '❌ Failed to fetch client: ${clientResponse.statusCode} ${clientResponse.body}',
              );
            }
          }

          if (!fetched) {
            // Fallback: if FK is only set on the Client side, fetch by project_id.
            final listResponse = await http.get(
              AppConfig.apiUri(
                'clients/?project_id=${widget.projectId}$scopeSuffix',
              ),
            );
            if (listResponse.statusCode == 200) {
              final decoded = jsonDecode(listResponse.body);
              final mapped = _firstRecordFromResponse(decoded);
              if (mapped != null) {
                setState(() {
                  _clientInfo = mapped;
                });
              }
            }
          }
        } catch (e) {
          print('⚠️ Error fetching client: $e');
        }
      } else {
        // Fallback: project has no client FK set, but a Client may still be linked via Client.project_id
        try {
          final listResponse = await http.get(
            AppConfig.apiUri(
              'clients/?project_id=${widget.projectId}$scopeSuffix',
            ),
          );
          if (listResponse.statusCode == 200) {
            final decoded = jsonDecode(listResponse.body);
            final mapped = _firstRecordFromResponse(decoded);
            if (mapped != null) {
              setState(() {
                _clientInfo = mapped;
              });
            }
          }
        } catch (e) {
          print('⚠️ Error fetching client list fallback: $e');
        }
      }

      // Fetch supervisor information
      if (supervisorId != null) {
        try {
          print('🔍 Attempting to fetch supervisor with ID: $supervisorId');
          final supervisorResponse = await http.get(
            (userId != null)
                ? AppConfig.apiUri('supervisors/$supervisorId/?user_id=$userId')
                : AppConfig.apiUri(
                    'supervisors/$supervisorId/?project_id=${widget.projectId}',
                  ),
          );
          print(
            '📡 Supervisor response status: ${supervisorResponse.statusCode}',
          );
          print('📡 Supervisor response body: ${supervisorResponse.body}');

          if (supervisorResponse.statusCode == 200) {
            setState(() {
              _supervisorInfo = jsonDecode(supervisorResponse.body);
              print('✅ Supervisor info fetched: ${_supervisorInfo?['email']}');
            });
          } else {
            print(
              '❌ Failed to fetch supervisor: ${supervisorResponse.statusCode}',
            );
            // Fallback: fetch by project_id in case the FK is only set on the Supervisor side
            final listResponse = await http.get(
              AppConfig.apiUri(
                'supervisors/?project_id=${widget.projectId}$scopeSuffix',
              ),
            );
            if (listResponse.statusCode == 200) {
              final decoded = jsonDecode(listResponse.body);
              if (decoded is List &&
                  decoded.isNotEmpty &&
                  decoded.first is Map) {
                setState(() {
                  _supervisorInfo = Map<String, dynamic>.from(decoded.first);
                });
              }
            }
          }
        } catch (e) {
          print('Error fetching supervisor: $e');
        }
      } else {
        print('⚠️ No supervisor_id found in project data');
        // Fallback: project has no supervisor FK set, but a Supervisor may still be linked via Supervisors.project_id
        try {
          final listResponse = await http.get(
            AppConfig.apiUri(
              'supervisors/?project_id=${widget.projectId}$scopeSuffix',
            ),
          );
          if (listResponse.statusCode == 200) {
            final decoded = jsonDecode(listResponse.body);
            if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
              setState(() {
                _supervisorInfo = Map<String, dynamic>.from(decoded.first);
              });
            }
          }
        } catch (e) {
          print('⚠️ Error fetching supervisor list fallback: $e');
        }
      }

      // Fetch phases for accurate progress calculation
      try {
        final phasesUrl = userId != null
            ? 'phases/?project_id=${widget.projectId}&user_id=$userId'
            : 'phases/?project_id=${widget.projectId}';
        final phasesResponse = await http.get(AppConfig.apiUri(phasesUrl));
        if (phasesResponse.statusCode == 200) {
          setState(() {
            _phases = jsonDecode(phasesResponse.body) as List<dynamic>;
            print('Phases fetched: ${_phases?.length ?? 0} phases');
          });
        }
      } catch (e) {
        print('Error fetching phases: $e');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error: $e');
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

          // Project Title + Edit icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  widget.projectTitle,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Icon(Icons.edit, size: 20),
            ],
          ),

          const SizedBox(height: 6),

          // Location
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
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
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

          // Client & Supervisor Cards
          if (isMobile)
            Column(
              children: [
                if (_clientInfo != null)
                  _infoCard(
                    title: "Client:",
                    name:
                        '${_clientInfo!['first_name']} ${_clientInfo!['last_name']}',
                    email: _clientInfo!['email'] ?? 'N/A',
                    phone: _clientInfo!['phone_number'] ?? 'N/A',
                    photoUrl: _resolveMediaUrl(_clientInfo!['photo']),
                    isMobile: true,
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Center(child: Text('No client assigned')),
                  ),
                if (widget.showSupervisorAssigned) ...[
                  const SizedBox(height: 12),
                  if (_supervisorInfo != null)
                    _infoCard(
                      title: "Supervisor-in charge:",
                      name:
                          '${_supervisorInfo!['first_name']} ${_supervisorInfo!['last_name']}',
                      email: _supervisorInfo!['email'] ?? 'N/A',
                      phone: _supervisorInfo!['phone_number'] ?? 'N/A',
                      photoUrl: _resolveMediaUrl(_supervisorInfo!['photo']),
                      isMobile: true,
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Center(
                        child: Text('No supervisor assigned'),
                      ),
                    ),
                ],
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_clientInfo != null)
                  _infoCard(
                    title: "Client:",
                    name:
                        '${_clientInfo!['first_name']} ${_clientInfo!['last_name']}',
                    email: _clientInfo!['email'] ?? 'N/A',
                    phone: _clientInfo!['phone_number'] ?? 'N/A',
                    photoUrl: _resolveMediaUrl(_clientInfo!['photo']),
                    isMobile: false,
                  )
                else
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Center(child: Text('No client assigned')),
                    ),
                  ),
                if (widget.showSupervisorAssigned)
                  if (_supervisorInfo != null)
                    _infoCard(
                      title: "Supervisor-in charge:",
                      name:
                          '${_supervisorInfo!['first_name']} ${_supervisorInfo!['last_name']}',
                      email: _supervisorInfo!['email'] ?? 'N/A',
                      phone: _supervisorInfo!['phone_number'] ?? 'N/A',
                      photoUrl: _resolveMediaUrl(_supervisorInfo!['photo']),
                      isMobile: false,
                    )
                  else
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Center(
                          child: Text('No supervisor assigned'),
                        ),
                      ),
                    ),
              ],
            ),

          const SizedBox(height: 12),

          // Manage Workforce Button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {},
              child: const Text(
                "Manage Workforce",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),

          const SizedBox(height: 24),

          // Project Plan Title
          const Text(
            "Project Plan",
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 16),

          // No plans message
          Center(
            child: Column(
              children: [
                Text(
                  "",
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
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
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "View Project Plan",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
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

  Widget _infoCard({
    required String title,
    required String name,
    required String email,
    required String phone,
    required String? photoUrl,
    required bool isMobile,
  }) {
    return isMobile
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildProfileAvatar(radius: 26, photoUrl: photoUrl),
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
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            phone,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.bottomRight,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      side: const BorderSide(color: Colors.orangeAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "View Profile",
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        : Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildProfileAvatar(radius: 26, photoUrl: photoUrl),
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
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              phone,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        side: const BorderSide(color: Colors.orangeAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "View Profile",
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
  }
}
