import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'clients_page.dart';
import 'modals/view_edit_client_modal.dart';


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

class ClientProfilePage extends StatelessWidget {
  final ClientInfo client;

  const ClientProfilePage({super.key, required this.client});

  static final List<ClientProject> _activeProjects = [
    ClientProject(
      projectName: 'Super Highway',
      location: 'Divisoria, Zamboanga City',
      startDate: '08/20/2025',
      endDate: '08/20/2026',
      progress: 0.55,
      status: 'In Progress',
    ),
    ClientProject(
      projectName: "Richmond's House",
      location: 'Sta. Maria, Zamboanga City',
      startDate: '02/03/2025',
      endDate: '09/20/2025',
      progress: 0.30,
      status: 'In Progress',
    ),
    ClientProject(
      projectName: 'Diversion Road',
      location: 'Luyahan, Zamboanga City',
      startDate: '05/12/2025',
      endDate: '02/20/2026',
      progress: 0.89,
      status: 'In Progress',
    ),
  ];

  static final List<ClientProject> _finishedProjects = [
    ClientProject(
      projectName: 'Bulacan Flood Control',
      location: 'Bulacan, Philippines',
      startDate: '01/15/2024',
      endDate: '08/20/2024',
      progress: 1.0,
      status: 'Completed',
    ),
    ClientProject(
      projectName: 'City Hall Renovation',
      location: 'Zamboanga City',
      startDate: '05/10/2023',
      endDate: '12/15/2023',
      progress: 1.0,
      status: 'Completed',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          const Sidebar(currentPage: 'Clients'),
          Expanded(
            child: Column(
              children: [
                const DashboardHeader(title: 'Clients'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
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
                            const Text(
                              'Client Profile',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0C1935),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Client Profile Card
                        Container(
                          padding: const EdgeInsets.all(24),
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
                          child: Row(
                            children: [
                              // Profile Image
                              CircleAvatar(
                                radius: 50,
                                backgroundImage: NetworkImage(client.avatarUrl),
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
                                    const SizedBox(height: 4),
                                    Text(
                                      client.company,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 16,
                                          color: Color(0xFF6B7280),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          client.location,
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
                                          Icons.email_outlined,
                                          size: 16,
                                          color: Color(0xFF6B7280),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          client.email,
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
                                          client.phone,
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
                                        ViewEditClientModal(client: client),
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
                        const SizedBox(height: 32),

                        // Active Projects Section
                        _ProjectSection(
                          title: 'Active Projects',
                          count: _activeProjects.length,
                          projects: _activeProjects,
                        ),
                        const SizedBox(height: 32),

                        // Finished Projects Section
                        _ProjectSection(
                          title: 'Finished Projects',
                          count: _finishedProjects.length,
                          projects: _finishedProjects,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectSection extends StatelessWidget {
  final String title;
  final int count;
  final List<ClientProject> projects;

  const _ProjectSection({
    required this.title,
    required this.count,
    required this.projects,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title ($count)',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0C1935),
          ),
        ),
        const SizedBox(height: 16),
        ...projects.map(
          (project) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _ProjectCard(project: project),
          ),
        ),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final ClientProject project;

  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
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
          const SizedBox(height: 16),
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
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
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
