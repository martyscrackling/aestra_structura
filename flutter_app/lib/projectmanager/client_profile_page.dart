import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/responsive_page_layout.dart';
import 'clients_page.dart';
import 'modals/view_edit_client_modal.dart';
import '../services/app_config.dart';
import '../services/auth_service.dart';

class ClientProject {
  final String projectName;
  final String location;
  final String startDate;
  final String endDate;
  final double progress;
  final String status;

  ClientProject({
    required this.projectName,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.progress,
    required this.status,
  });
}

class _ClientProjectsData {
  const _ClientProjectsData({
    required this.activeProjects,
    required this.finishedProjects,
  });

  final List<ClientProject> activeProjects;
  final List<ClientProject> finishedProjects;
}

class ClientProfilePage extends StatefulWidget {
  final ClientInfo client;

  const ClientProfilePage({super.key, required this.client});

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage> {
  late ClientInfo _client;
  late Future<_ClientProjectsData> _projectsFuture;

  @override
  void initState() {
    super.initState();
    _client = widget.client;
    _projectsFuture = _fetchClientProjects();
    _refreshClientFromServer();
  }

  int? _currentUserId() {
    final raw = AuthService().currentUser?['user_id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  String _resolvePhotoUrl(dynamic rawPhoto) {
    final photo = (rawPhoto?.toString() ?? '').trim();
    if (photo.isEmpty) return _client.avatarUrl;
    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      return photo;
    }

    final apiBase = Uri.parse(AppConfig.apiBaseUrl);
    final origin = apiBase.origin;
    if (photo.startsWith('/')) {
      return '$origin$photo';
    }
    return '$origin/$photo';
  }

  String _buildClientLocation(Map<String, dynamic> data) {
    final parts = [
      data['barangay_name']?.toString().trim() ?? '',
      data['city_name']?.toString().trim() ?? '',
      data['province_name']?.toString().trim() ?? '',
      data['region_name']?.toString().trim() ?? '',
    ].where((e) => e.isNotEmpty).toList(growable: false);

    if (parts.isNotEmpty) {
      return parts.join(', ');
    }
    return _client.location;
  }

  Future<void> _refreshClientFromServer() async {
    final clientId = _client.id;
    final userId = _currentUserId();
    if (clientId == null || userId == null) return;

    try {
      final response = await http.get(
        AppConfig.apiUri('clients/$clientId/?user_id=$userId'),
      );
      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;

      final firstName = (decoded['first_name']?.toString() ?? '').trim();
      final lastName = (decoded['last_name']?.toString() ?? '').trim();
      final fullName = '$firstName $lastName'.trim();

      if (!mounted) return;
      setState(() {
        _client = ClientInfo(
          id: _client.id,
          name: fullName.isNotEmpty ? fullName : _client.name,
          company: '',
          email: (decoded['email']?.toString() ?? _client.email).trim(),
          phone: (decoded['phone_number']?.toString() ?? _client.phone).trim(),
          location: _buildClientLocation(decoded),
          avatarUrl: _resolvePhotoUrl(decoded['photo']),
        );
      });
    } catch (_) {
      // Keep current UI data when refresh fails.
    }
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _formatDate(String rawDate) {
    if (rawDate.trim().isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(rawDate);
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$month/$day/$year';
    } catch (_) {
      return rawDate;
    }
  }

  int? _extractClientId(Map<String, dynamic> project) {
    final directClientId = _parseInt(project['client_id']);
    if (directClientId != null) return directClientId;

    final clientField = project['client'];
    if (clientField is Map<String, dynamic>) {
      return _parseInt(clientField['client_id']) ??
          _parseInt(clientField['id']);
    }

    return _parseInt(clientField);
  }

  String _extractClientName(Map<String, dynamic> project) {
    final directName = (project['client_name']?.toString() ?? '').trim();
    if (directName.isNotEmpty) return directName;

    final clientField = project['client'];
    if (clientField is Map<String, dynamic>) {
      final firstName = (clientField['first_name']?.toString() ?? '').trim();
      final lastName = (clientField['last_name']?.toString() ?? '').trim();
      final fullName = '$firstName $lastName'.trim();
      if (fullName.isNotEmpty) return fullName;
      return (clientField['name']?.toString() ?? '').trim();
    }

    return '';
  }

  bool _isProjectForSelectedClient(Map<String, dynamic> project) {
    final selectedClientId = _client.id;
    final projectClientId = _extractClientId(project);

    if (selectedClientId != null && projectClientId != null) {
      return selectedClientId == projectClientId;
    }

    final selectedName = _client.name.trim().toLowerCase();
    final projectClientName = _extractClientName(project).toLowerCase();

    if (selectedName.isEmpty || projectClientName.isEmpty) {
      return false;
    }

    return projectClientName == selectedName ||
        projectClientName.contains(selectedName) ||
        selectedName.contains(projectClientName);
  }

  String _buildProjectLocation(Map<String, dynamic> project) {
    String? asText(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      if (text.isEmpty || text == 'null') return null;
      return text;
    }

    final parts = <String?>[
      asText(project['street']),
      asText(project['barangay_name']) ?? asText(project['barangay']),
      asText(project['city_name']) ?? asText(project['city']),
      asText(project['province_name']) ?? asText(project['province']),
      asText(project['region_name']) ?? asText(project['region']),
    ].whereType<String>().toList();

    if (parts.isNotEmpty) {
      return parts.join(', ');
    }

    return 'No location provided';
  }

  Future<double> _calculateProgressFromPhases(int projectId) async {
    try {
      final response = await http.get(
        AppConfig.apiUri('phases/?project_id=$projectId'),
      );

      if (response.statusCode != 200) return 0.0;

      final List<dynamic> phases = jsonDecode(response.body);
      int totalSubtasks = 0;
      int completedSubtasks = 0;

      for (final phase in phases) {
        if (phase is! Map<String, dynamic>) continue;
        final subtasks = phase['subtasks'];
        if (subtasks is! List) continue;

        totalSubtasks += subtasks.length;
        for (final subtask in subtasks) {
          if (subtask is! Map<String, dynamic>) continue;
          final status = (subtask['status']?.toString() ?? '').toLowerCase();
          if (status == 'completed') {
            completedSubtasks++;
          }
        }
      }

      if (totalSubtasks == 0) return 0.0;
      return completedSubtasks / totalSubtasks;
    } catch (_) {
      return 0.0;
    }
  }

  double _progressFromProjectField(Map<String, dynamic> project) {
    final candidates = [
      project['progress'],
      project['completion'],
      project['completion_rate'],
      project['completion_percentage'],
    ];

    for (final value in candidates) {
      if (value == null) continue;
      final parsed = double.tryParse(value.toString());
      if (parsed == null) continue;

      final normalized = parsed > 1 ? (parsed / 100) : parsed;
      return normalized.clamp(0.0, 1.0);
    }

    return 0.0;
  }

  Future<_ClientProjectsData> _fetchClientProjects() async {
    final userId = AuthService().currentUser?['user_id'];
    if (userId == null) {
      return const _ClientProjectsData(
        activeProjects: [],
        finishedProjects: [],
      );
    }

    final response = await http.get(
      AppConfig.apiUri('projects/?user_id=$userId'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load projects: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data is! List) {
      return const _ClientProjectsData(
        activeProjects: [],
        finishedProjects: [],
      );
    }

    final activeProjects = <ClientProject>[];
    final finishedProjects = <ClientProject>[];

    for (final rawProject in data) {
      if (rawProject is! Map<String, dynamic>) continue;
      if (!_isProjectForSelectedClient(rawProject)) continue;

      final projectId = _parseInt(rawProject['project_id']) ?? 0;
      var progress = _progressFromProjectField(rawProject);
      if (progress == 0.0 && projectId > 0) {
        progress = await _calculateProgressFromPhases(projectId);
      }

      final statusRaw = (rawProject['status']?.toString() ?? 'In Progress')
          .trim();
      final isCompleted =
          statusRaw.toLowerCase() == 'completed' || progress >= 1.0;
      final normalizedStatus = isCompleted
          ? 'Completed'
          : (statusRaw.isEmpty ? 'In Progress' : statusRaw);

      final project = ClientProject(
        projectName:
            (rawProject['project_name']?.toString() ?? 'Unnamed Project')
                .trim(),
        location: _buildProjectLocation(rawProject),
        startDate: _formatDate(rawProject['start_date']?.toString() ?? ''),
        endDate: _formatDate(rawProject['end_date']?.toString() ?? ''),
        progress: progress,
        status: normalizedStatus,
      );

      if (isCompleted) {
        finishedProjects.add(project);
      } else {
        activeProjects.add(project);
      }
    }

    return _ClientProjectsData(
      activeProjects: activeProjects,
      finishedProjects: finishedProjects,
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return ResponsivePageLayout(
      currentPage: 'Clients',
      title: 'Clients',
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
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
                Text(
                  'Client Profile',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0C1935),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 24),

            // Client Profile Card
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
                          radius: 50,
                          backgroundImage: client.avatarUrl.trim().isNotEmpty
                              ? NetworkImage(client.avatarUrl)
                              : null,
                          backgroundColor: Colors.grey[200],
                          child: client.avatarUrl.trim().isNotEmpty
                              ? null
                              : const Icon(
                                  Icons.person_outline,
                                  color: Color(0xFF6B7280),
                                ),
                        ),
                        const SizedBox(height: 16),
                        // Profile Info
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              client.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0C1935),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (client.company.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                client.company,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF6B7280),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.location_on_outlined,
                              client.location,
                              center: true,
                            ),
                            const SizedBox(height: 6),
                            _buildInfoRow(
                              Icons.email_outlined,
                              client.email,
                              center: true,
                            ),
                            const SizedBox(height: 6),
                            _buildInfoRow(
                              Icons.phone_outlined,
                              client.phone,
                              center: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Edit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final saved = await showDialog(
                                context: context,
                                builder: (context) =>
                                    ViewEditClientModal(client: client),
                              );
                              if (saved == true) {
                                _refreshClientFromServer();
                              }
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
                          backgroundImage: client.avatarUrl.trim().isNotEmpty
                              ? NetworkImage(client.avatarUrl)
                              : null,
                          backgroundColor: Colors.grey[200],
                          child: client.avatarUrl.trim().isNotEmpty
                              ? null
                              : const Icon(
                                  Icons.person_outline,
                                  color: Color(0xFF6B7280),
                                ),
                        ),
                        const SizedBox(width: 24),
                        // Profile Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                client.name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0C1935),
                                ),
                              ),
                              if (client.company.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  client.company,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                Icons.location_on_outlined,
                                client.location,
                              ),
                              const SizedBox(height: 6),
                              _buildInfoRow(Icons.email_outlined, client.email),
                              const SizedBox(height: 6),
                              _buildInfoRow(Icons.phone_outlined, client.phone),
                            ],
                          ),
                        ),
                        // Edit Button
                        ElevatedButton.icon(
                          onPressed: () async {
                            final saved = await showDialog(
                              context: context,
                              builder: (context) =>
                                  ViewEditClientModal(client: client),
                            );
                            if (saved == true) {
                              _refreshClientFromServer();
                            }
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
            FutureBuilder<_ClientProjectsData>(
              future: _projectsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Unable to load client projects. ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final data =
                    snapshot.data ??
                    const _ClientProjectsData(
                      activeProjects: [],
                      finishedProjects: [],
                    );

                return Column(
                  children: [
                    _ProjectSection(
                      title: 'Active Projects',
                      count: data.activeProjects.length,
                      projects: data.activeProjects,
                      isMobile: isMobile,
                    ),
                    SizedBox(height: isMobile ? 24 : 32),
                    _ProjectSection(
                      title: 'Finished Projects',
                      count: data.finishedProjects.length,
                      projects: data.finishedProjects,
                      isMobile: isMobile,
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: isMobile ? 80 : 0), // Space for bottom navbar
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {bool center = false}) {
    return Row(
      mainAxisAlignment: center
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            textAlign: center ? TextAlign.center : TextAlign.start,
          ),
        ),
      ],
    );
  }
}

class _ProjectSection extends StatelessWidget {
  final String title;
  final int count;
  final List<ClientProject> projects;
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
            'No projects found for this client.',
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
  final ClientProject project;
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
                        const SizedBox(width: 8),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
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
