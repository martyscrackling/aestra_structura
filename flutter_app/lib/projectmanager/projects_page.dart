import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'modals/create_project_modal.dart';
import 'project_info.dart';
import '../services/auth_service.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  List<ProjectOverviewData> _projects = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    try {
      final authService = AuthService();
      final userId = authService.currentUser?['user_id'];

      print('🔍 _fetchProjects called');
      print('🔍 User ID: $userId');
      print('🔍 Current user data: ${authService.currentUser}');

      if (userId == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      final url = 'http://127.0.0.1:8000/api/projects/?user_id=$userId';
      print('🔍 Fetching from: $url');

      final response = await http.get(Uri.parse(url));

      print('✅ Response status: ${response.statusCode}');
      print('✅ Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('📊 Projects fetched: ${data.length}');

        setState(() {
          _projects = data.map((project) {
            try {
              print('📌 Processing project: ${project['project_name']}');

              // Safely convert all fields
              final int projectId = (project['project_id'] as int?) ?? 0;
              final String projectName =
                  (project['project_name'] as String?) ?? 'Unknown';
              final String status =
                  (project['status'] as String?) ?? 'Planning';
              final String startDateStr =
                  (project['start_date'] as String?) ?? '';
              final String endDateStr = (project['end_date'] as String?) ?? '';
              final String budget = (project['budget']?.toString()) ?? '0';
              final String createdAt = (project['created_at'] as String?) ?? '';

              print('✅ Project ID: $projectId, Name: $projectName');

              // Calculate progress
              DateTime startDate = DateTime.now();
              DateTime endDate = DateTime.now().add(const Duration(days: 30));

              try {
                if (startDateStr.isNotEmpty) {
                  startDate = DateTime.parse(startDateStr);
                }
                if (endDateStr.isNotEmpty) {
                  endDate = DateTime.parse(endDateStr);
                }
              } catch (e) {
                print('⚠️ Date parsing error: $e');
              }

              final today = DateTime.now();
              final totalDays = endDate.difference(startDate).inDays;
              final elapsedDays = today.difference(startDate).inDays;

              // Calculate progress: 0% if project hasn't started yet
              final progress = (totalDays > 0 && elapsedDays > 0)
                  ? (elapsedDays / totalDays).clamp(0.0, 1.0)
                  : 0.0;
              return ProjectOverviewData(
                projectId: projectId,
                title: projectName,
                status: status,
                location: _buildLocation(project),
                startDate: _formatDate(startDateStr),
                endDate: _formatDate(endDateStr),
                progress: progress,
                crewCount: 0,
                image: _getProjectImage(project),
                budget: budget,
                createdAt: createdAt,
              );
            } catch (e) {
              print('❌ Error processing project: $e');
              rethrow;
            }
          }).toList();

          // Sort projects by created_at (newest to oldest, with date and time)
          _projects.sort((a, b) {
            try {
              if (a.createdAt.isEmpty || b.createdAt.isEmpty) {
                return 0;
              }
              final dateA = DateTime.parse(a.createdAt);
              final dateB = DateTime.parse(b.createdAt);
              return dateB.compareTo(dateA); // Descending (newest first)
            } catch (e) {
              print('⚠️ Error sorting by created_at: $e');
              return 0;
            }
          });

          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load projects: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
      print('Error fetching projects: $e');
    }
  }

  String _buildLocation(Map<String, dynamic> project) {
    try {
      List<String> parts = [];

      final street = project['street'];
      if (street != null) parts.add(street.toString());

      final barangay = project['barangay'];
      if (barangay != null) parts.add(barangay.toString());

      final city = project['city'];
      if (city != null) parts.add(city.toString());

      return parts.isNotEmpty ? parts.join(', ') : 'Unknown Location';
    } catch (e) {
      print('⚠️ Error building location: $e');
      return 'Unknown Location';
    }
  }

  String _getProjectImage(Map<String, dynamic> project) {
    try {
      final image = project['project_image'];

      // If null, return default
      if (image == null) {
        print('🖼️ project_image is null, using default');
        return 'assets/images/engineer.jpg';
      }

      // Convert to string safely
      String imageStr = image.toString().trim();

      // If empty string, return default
      if (imageStr.isEmpty || imageStr == 'null') {
        print('🖼️ project_image is empty, using default');
        return 'assets/images/engineer.jpg';
      }

      print('🖼️ project_image: $imageStr');
      return imageStr;
    } catch (e) {
      print('❌ Error getting project image: $e');
      return 'assets/images/engineer.jpg';
    }
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '';
    try {
      final parsed = DateTime.parse(date);
      return '${parsed.month.toString().padLeft(2, '0')}/${parsed.day.toString().padLeft(2, '0')}/${parsed.year}';
    } catch (e) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          const Sidebar(currentPage: 'Projects'),
          Expanded(
            child: Column(
              children: [
                const DashboardHeader(title: 'Projects'),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(_error!),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchProjects,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _projects.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.folder_open,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No projects yet added.',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) =>
                                        const CreateProjectModal(),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[600],
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Add Now',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ProjectsHeader(onRefresh: _fetchProjects),
                              const SizedBox(height: 24),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final columnCount =
                                      constraints.maxWidth > 1400
                                      ? 4
                                      : constraints.maxWidth > 1100
                                      ? 3
                                      : constraints.maxWidth > 800
                                      ? 2
                                      : 1;
                                  final cardWidth =
                                      (constraints.maxWidth -
                                          (columnCount - 1) * 20) /
                                      columnCount;

                                  return Wrap(
                                    spacing: 20,
                                    runSpacing: 20,
                                    children: _projects
                                        .map(
                                          (project) => SizedBox(
                                            width: cardWidth,
                                            child: ProjectOverviewCard(
                                              data: project,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  );
                                },
                              ),
                              const SizedBox(height: 32),
                              ProjectListPanel(items: _projects),
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

class _ProjectsHeader extends StatelessWidget {
  const _ProjectsHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Projects',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0C1935),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Monitor construction progress across all active sites.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          height: 40,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A18),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const CreateProjectModal(),
              ).then((_) {
                onRefresh();
              });
            },
            icon: const Icon(Icons.add, size: 18, color: Colors.black),
            label: const Text(
              'Create Project',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        const _SearchField(),
        const SizedBox(width: 12),
        _SortButton(onPressed: onRefresh),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 40,
      child: TextField(
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          prefixIcon: const Icon(Icons.search, size: 18),
          hintText: 'Search projects…',
          hintStyle: const TextStyle(fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0C1935),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: const Icon(Icons.sort, size: 18),
        label: const Text(
          'Sort',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class ProjectOverviewCard extends StatelessWidget {
  const ProjectOverviewCard({super.key, required this.data});

  final ProjectOverviewData data;

  Widget _buildProjectImage(String imagePath) {
    try {
      print('🔍 Loading image: $imagePath');

      // Validate input
      if (imagePath.isEmpty || imagePath == 'null') {
        print('⚠️ Invalid image path');
        return _buildPlaceholder();
      }

      // Check if it's an asset path
      if (imagePath.startsWith('assets/')) {
        return Image.asset(
          imagePath,
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('⚠️ Asset image failed to load: $imagePath');
            return _buildPlaceholder();
          },
        );
      }

      // Check if it's a file path
      try {
        final file = File(imagePath);
        if (file.existsSync()) {
          print('✅ Loading file: $imagePath');
          return Image.file(
            file,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print('⚠️ File image failed to load: $imagePath');
              return _buildPlaceholder();
            },
          );
        } else {
          print('⚠️ File does not exist: $imagePath');
          return _buildPlaceholder();
        }
      } catch (e) {
        print('⚠️ File check error: $e');
        return _buildPlaceholder();
      }
    } catch (e) {
      print('❌ Critical error in _buildProjectImage: $e');
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 150,
      width: double.infinity,
      color: Colors.grey[300],
      child: const Center(child: Icon(Icons.image_not_supported, size: 40)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: _buildProjectImage(data.image),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: data.progress >= 1
                        ? const Color(0xFFE5F8ED)
                        : const Color(0xFFFFF2E8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: data.progress >= 1
                          ? const Color(0xFF10B981)
                          : const Color(0xFFFF7A18),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0C1935),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.location,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Color(0xFFA0AEC0),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${data.startDate}   •   ${data.endDate}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: data.progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF3F4F6),
                    valueColor: AlwaysStoppedAnimation(
                      data.progress >= 1
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFFF7A18),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(data.progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                    Text(
                      '${data.crewCount} crew assigned',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  ProjectDetailsPage(
                                    projectTitle: data.title,
                                    projectLocation: data.location,
                                    projectImage: data.image,
                                    progress: data.progress,
                                    budget: data.budget,
                                    projectId: data.projectId,
                                  ),
                          transitionDuration: Duration.zero,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: data.progress >= 1
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFFF7A18),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'View more',
                      style: TextStyle(
                        color: data.progress >= 1
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFFF7A18),
                        fontWeight: FontWeight.w600,
                      ),
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

class ProjectListPanel extends StatelessWidget {
  const ProjectListPanel({super.key, required this.items});

  final List<ProjectOverviewData> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              const Text(
                'Projects',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C1935),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                color: const Color(0xFF6B7280),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (project) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: project.progress >= 1
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF8B5CF6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0C1935),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          project.status,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(project.progress * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0C1935),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectOverviewData {
  const ProjectOverviewData({
    required this.projectId,
    required this.title,
    required this.status,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.progress,
    required this.crewCount,
    required this.image,
    this.budget,
    this.createdAt = '',
  });

  final int projectId;
  final String title;
  final String status;
  final String location;
  final String startDate;
  final String endDate;
  final double progress;
  final int crewCount;
  final String image;
  final String? budget;
  final String createdAt;
}
