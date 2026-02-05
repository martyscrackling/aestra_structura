import 'package:flutter/material.dart';
import 'widgets/responsive_page_layout.dart';
import 'workforce_page.dart';
import 'modals/view_edit_worker_modal.dart';

class WorkerProject {
  final String projectName;
  final String location;
  final String startDate;
  final String endDate;
  final double progress;
  final String status;

  WorkerProject({
    required this.projectName,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.progress,
    required this.status,
  });
}

class WorkerProfilePage extends StatelessWidget {
  final WorkerInfo worker;

  const WorkerProfilePage({super.key, required this.worker});

  static final List<WorkerProject> _activeProjects = [
    WorkerProject(
      projectName: 'Super Highway',
      location: 'Divisoria, Zamboanga City',
      startDate: '08/20/2025',
      endDate: '08/20/2026',
      progress: 0.55,
      status: 'In Progress',
    ),
    WorkerProject(
      projectName: "Richmond's House",
      location: 'Sta. Maria, Zamboanga City',
      startDate: '02/03/2025',
      endDate: '09/20/2025',
      progress: 0.30,
      status: 'In Progress',
    ),
  ];

  static final List<WorkerProject> _finishedProjects = [
    WorkerProject(
      projectName: 'Bulacan Flood Control',
      location: 'Bulacan, Philippines',
      startDate: '01/15/2024',
      endDate: '08/20/2024',
      progress: 1.0,
      status: 'Completed',
    ),
    WorkerProject(
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
    return ResponsivePageLayout(
      currentPage: 'Workforce',
      title: 'Workforce',
      child: Builder(
        builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 768;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: isMobile ? 16 : 24,
            ),
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
                    Expanded(
                      child: Text(
                        '${worker.role} Profile',
                        style: TextStyle(
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0C1935),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 16 : 24),

                // Worker Profile Card
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
                              radius: 40,
                              backgroundImage: NetworkImage(worker.avatarUrl),
                            ),
                            const SizedBox(height: 16),
                            // Profile Info
                            Column(
                              children: [
                                Text(
                                  worker.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0C1935),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF2E8),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    worker.role,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFFF7A18),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.email_outlined,
                                      size: 16,
                                      color: Color(0xFF6B7280),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        worker.email,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6B7280),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.phone_outlined,
                                      size: 16,
                                      color: Color(0xFF6B7280),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      worker.phone,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Edit Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) =>
                                        ViewEditWorkerModal(worker: worker),
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
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            // Profile Image
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: NetworkImage(worker.avatarUrl),
                            ),
                            const SizedBox(width: 24),
                            // Profile Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    worker.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0C1935),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF2E8),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      worker.role,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFFF7A18),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.email_outlined,
                                        size: 16,
                                        color: Color(0xFF6B7280),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        worker.email,
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
                                        worker.phone,
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
                                      ViewEditWorkerModal(worker: worker),
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
                SizedBox(height: isMobile ? 24 : 32),

                // Active Projects Section
                _ProjectSection(
                  title: 'Active Projects',
                  count: _activeProjects.length,
                  projects: _activeProjects,
                  isMobile: isMobile,
                ),
                SizedBox(height: isMobile ? 24 : 32),

                // Finished Projects Section
                _ProjectSection(
                  title: 'Finished Projects',
                  count: _finishedProjects.length,
                  projects: _finishedProjects,
                  isMobile: isMobile,
                ),
                SizedBox(height: isMobile ? 80 : 0),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProjectSection extends StatelessWidget {
  final String title;
  final int count;
  final List<WorkerProject> projects;
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
  final WorkerProject project;
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
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
                              fontSize: 11,
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
                          size: 14,
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
                    const SizedBox(height: 4),
                    Text(
                      '${(project.progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0C1935),
                      ),
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
