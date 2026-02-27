import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/responsive_page_layout.dart';
import 'project_details_page.dart' as task_details;
import '../services/app_config.dart';

class ProjectDetailsPage extends StatefulWidget {
  final String projectTitle;
  final String projectLocation;
  final String projectImage;
  final double progress;
  final String? budget;
  final int projectId;

  const ProjectDetailsPage({
    super.key,
    required this.projectTitle,
    required this.projectLocation,
    required this.projectImage,
    required this.progress,
    this.budget,
    required this.projectId,
  });

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
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
      // First fetch project details to get client_id and supervisor_id
      final projectResponse = await http.get(
        AppConfig.apiUri('projects/${widget.projectId}/'),
      );

      if (projectResponse.statusCode != 200) {
        setState(() {
          _error = 'Failed to load project details';
          _isLoading = false;
        });
        return;
      }

      final projectData = jsonDecode(projectResponse.body);
      final clientId = projectData['client'];
      final supervisorId = projectData['supervisor'];

      setState(() {
        _projectInfo = projectData;
      });

      print('🔍 Project ID: ${widget.projectId}');
      print('🔍 Client ID: $clientId');
      print('🔍 Supervisor ID: $supervisorId');

      // Fetch client information
      if (clientId != null) {
        try {
          final clientResponse = await http.get(
            AppConfig.apiUri('clients/$clientId/'),
          );
          if (clientResponse.statusCode == 200) {
            setState(() {
              _clientInfo = jsonDecode(clientResponse.body);
              print('✅ Client info fetched: ${_clientInfo?['email']}');
            });
          }
        } catch (e) {
          print('⚠️ Error fetching client: $e');
        }
      }

      // Fetch supervisor information
      if (supervisorId != null) {
        try {
          print('🔍 Attempting to fetch supervisor with ID: $supervisorId');
          final supervisorResponse = await http.get(
            AppConfig.apiUri('supervisors/$supervisorId/'),
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
          }
        } catch (e) {
          print('Error fetching supervisor: $e');
        }
      } else {
        print('⚠️ No supervisor_id found in project data');
      }

      // Fetch phases for accurate progress calculation
      try {
        final phasesResponse = await http.get(
          AppConfig.apiUri('phases/?project_id=${widget.projectId}'),
        );
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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F6F9),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        body: Center(child: Text('Error: $_error')),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return ResponsivePageLayout(
      currentPage: 'Projects',
      title: 'Project Details',
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              child: _buildProjectImage(widget.projectImage),
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
            Text(
              widget.projectLocation,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),

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
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.red.shade400,
              ),
            ),

            const SizedBox(height: 30),

                        // Project Details Cards
                        if (isMobile)
                          Column(
                            children: [
                              _projectDetailCard(
                                icon: Icons.calendar_today,
                                title: 'Duration',
                                value: _projectInfo != null
                                    ? '${_projectInfo!['duration_days'] ?? 'N/A'} days'
                                    : 'Loading...',
                                color: const Color(0xFF2196F3),
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
                                title: 'End Date',
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
                                  title: 'End Date',
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
                                  isMobile: true,
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text('No client assigned'),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              if (_supervisorInfo != null)
                                _infoCard(
                                  title: "Supervisor-in charge:",
                                  name:
                                      '${_supervisorInfo!['first_name']} ${_supervisorInfo!['last_name']}',
                                  email: _supervisorInfo!['email'] ?? 'N/A',
                                  phone:
                                      _supervisorInfo!['phone_number'] ?? 'N/A',
                                  isMobile: true,
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text('No supervisor assigned'),
                                  ),
                                ),
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
                                  isMobile: false,
                                )
                              else
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Text('No client assigned'),
                                    ),
                                  ),
                                ),
                              if (_supervisorInfo != null)
                                _infoCard(
                                  title: "Supervisor-in charge:",
                                  name:
                                      '${_supervisorInfo!['first_name']} ${_supervisorInfo!['last_name']}',
                                  email: _supervisorInfo!['email'] ?? 'N/A',
                                  phone:
                                      _supervisorInfo!['phone_number'] ?? 'N/A',
                                  isMobile: false,
                                )
                              else
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
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
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade700,
                                ),
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
                                            projectLocation:
                                                widget.projectLocation,
                                            projectImage: widget.projectImage,
                                            progress: widget.progress,
                                            budget: widget.budget,
                                            projectId: widget.projectId,
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
                                  "Add now",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isMobile ? 80 : 32), // Space for bottom nav
                      ],
                    ),
      ),
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
      // Check if it's an asset path
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
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFFE8F5E9),
                      child: const Icon(
                        Icons.person,
                        size: 26,
                        color: Color(0xFF10B981),
                      ),
                    ),
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
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
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
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFE8F5E9),
                  child: const Icon(
                    Icons.person,
                    size: 26,
                    color: Color(0xFF10B981),
                  ),
                ),
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
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
