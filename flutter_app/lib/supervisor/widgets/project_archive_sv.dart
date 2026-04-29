import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import '../../services/auth_service.dart';
import '../../services/app_config.dart';
import '../../services/app_theme_tokens.dart';
import '../project_infos.dart';

class ProjectArchiveSv extends StatefulWidget {
  final Function(int)? onProjectLoaded;

  const ProjectArchiveSv({
    super.key,
    this.onProjectLoaded,
  });

  @override
  State<ProjectArchiveSv> createState() => _ProjectArchiveSvState();
}

class _ProjectArchiveSvState extends State<ProjectArchiveSv> {
  List<ProjectOverviewData> _archivedProjects = [];
  bool _isLoading = true;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _ArchivedSortOrder _sortOrder = _ArchivedSortOrder.newestToOldest;

  @override
  void initState() {
    super.initState();
    _fetchArchivedProjects();

    _searchController.addListener(() {
      final value = _searchController.text;
      if (value == _searchQuery) return;
      setState(() {
        _searchQuery = value;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProjectOverviewData> get _visibleProjects {
    final query = _searchQuery.trim().toLowerCase();
    print(
      '🔍 _visibleArchivedProjects called with searchQuery=$_searchQuery',
    );

    final filtered = query.isEmpty
        ? List<ProjectOverviewData>.from(_archivedProjects)
        : _archivedProjects.where((project) {
            return project.title.toLowerCase().contains(query) ||
                project.location.toLowerCase().contains(query) ||
                project.status.toLowerCase().contains(query) ||
                project.projectType.toLowerCase().contains(query);
          }).toList();

    DateTime? parseDate(String value) {
      if (value.isEmpty) return null;
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }

    // Use end date (completion date) first, fall back to created_at.
    int compareCompletion(ProjectOverviewData a, ProjectOverviewData b) {
      final dateA = parseDate(a.endDateRaw) ?? parseDate(a.createdAt);
      final dateB = parseDate(b.endDateRaw) ?? parseDate(b.createdAt);
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateA.compareTo(dateB);
    }

    int comparator(ProjectOverviewData a, ProjectOverviewData b) {
      int result = compareCompletion(a, b);

      if (_sortOrder == _ArchivedSortOrder.newestToOldest) {
        result = -result;
      }
      return result;
    }

    filtered.sort(comparator);
    return filtered;
  }

  Future<_ProjectMetrics> _calculateProjectMetrics(int projectId) async {
    try {
      final response = await http.get(
        AppConfig.apiUri('phases/?project_id=$projectId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> phases = jsonDecode(response.body);

        int totalSubtasks = 0;
        int completedSubtasks = 0;
        final Set<int> assignedWorkerIds = <int>{};

        for (var phase in phases) {
          final phaseMap = phase as Map<String, dynamic>;
          final List<dynamic> subtasks = phaseMap['subtasks'] ?? [];

          totalSubtasks += subtasks.length;
          for (var subtask in subtasks) {
            final subtaskMap = subtask as Map<String, dynamic>;
            if (subtaskMap['status'] == 'completed') {
              completedSubtasks++;
            }
            final assignedWorkers =
                subtaskMap['assigned_workers'] as List<dynamic>?;
            if (assignedWorkers != null) {
              for (var worker in assignedWorkers) {
                final workerId = worker['fieldworker_id'] as int?;
                if (workerId != null) assignedWorkerIds.add(workerId);
              }
            }
          }
        }

        final progress = totalSubtasks == 0
            ? 0.0
            : completedSubtasks / totalSubtasks;
        return _ProjectMetrics(
          progress: progress,
          assignedCrewCount: assignedWorkerIds.length,
        );
      }
    } catch (e) {
      print('⚠️ Error calculating project metrics for project $projectId: $e');
    }
    return const _ProjectMetrics(progress: 0.0, assignedCrewCount: 0);
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  Future<void> _fetchArchivedProjects() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final supervisorId = authService.currentUser?['supervisor_id'];
      final userId = authService.currentUser?['user_id'];

      print('🔍 _fetchArchivedProjects called');
      print('🔍 Supervisor ID: $supervisorId');
      print('🔍 User ID: $userId');

      if (supervisorId == null) {
        setState(() {
          _error = 'Supervisor not assigned';
          _isLoading = false;
        });
        return;
      }

      final url = AppConfig.apiUri('projects/?supervisor_id=$supervisorId');
      print('🔍 Fetching from: $url');

      final response = await http.get(url);

      print('✅ Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded is List ? decoded : [];
        print('📊 Projects fetched: ${data.length}');

        // Include only projects that are completed by status or progress.
        List<ProjectOverviewData> projects = [];
        for (var project in data) {
          try {
            final projectIdRaw = project['project_id'];
            final int? projectId =
                projectIdRaw is int ? projectIdRaw : int.tryParse(projectIdRaw.toString());
            if (projectId == null) continue;

            final status = (project['status'] ?? '').toString().toLowerCase();

            final metrics = await _calculateProjectMetrics(projectId);

            final title = project['project_name'] ?? 'Untitled Project';
            final location = _buildLocation(project);
            final startDateRaw = project['start_date'] ?? '';
            final endDateRaw = project['end_date'] ?? '';
            final image = _getProjectImage(project);
            final projectType = project['project_type'] ?? 'Project';
            final budget = project['budget'] ?? project['project_budget'];
            final createdAt = project['created_at'] ?? '';

            projects.add(
              ProjectOverviewData(
                projectId: projectId,
                title: title,
                status: status,
                location: location,
                startDate: _formatDate(startDateRaw),
                endDate: _formatDate(endDateRaw),
                progress: metrics.progress,
                crewCount: metrics.assignedCrewCount,
                image: image,
                projectType: projectType,
                budget: budget,
                createdAt: createdAt,
                endDateRaw: endDateRaw,
              ),
            );
          } catch (e) {
            print('⚠️ Error processing project: $e');
          }
        }

print('📊 Projects for supervisor: ${projects.length}');

        setState(() {
          _archivedProjects = projects;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load archived projects: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
      print('Error fetching archived projects: $e');
    }
  }

  String _buildLocation(Map<String, dynamic> project) {
    try {
      String? asNonEmptyString(dynamic value, {bool allowNumericOnly = false}) {
        if (value == null) return null;
        final s = value.toString().trim();
        if (s.isEmpty || s == 'null') return null;
        final numericOnly = RegExp(r'^\d+$').hasMatch(s);
        if (!allowNumericOnly && numericOnly) return null;
        return s;
      }

      final street = asNonEmptyString(project['street']);
      final barangay = asNonEmptyString(project['barangay_name']) ??
          asNonEmptyString(project['barangay']);
      final city = asNonEmptyString(project['city_name']) ??
          asNonEmptyString(project['city']);
      final province = asNonEmptyString(project['province_name']) ??
          asNonEmptyString(project['province']);

      final parts = <String>[];
      if (street != null) parts.add(street);
      if (barangay != null) parts.add(barangay);
      if (city != null) parts.add(city);
      if (province != null) parts.add(province);

      if (parts.isEmpty) {
        final fallback = asNonEmptyString(project['project_location']) ??
            asNonEmptyString(project['project_address']) ??
            asNonEmptyString(project['address']) ??
            asNonEmptyString(project['location']);
        if (fallback != null) return fallback;
      }

      return parts.isNotEmpty ? parts.join(', ') : 'Unknown Location';
    } catch (e) {
      print('⚠️ Error building location: $e');
      return 'Unknown Location';
    }
  }

  String _getProjectImage(Map<String, dynamic> project) {
    try {
      final image = project['project_image'];

      if (image == null) {
        print('🖼️ project_image is null, using default');
        return 'assets/images/engineer.jpg';
      }

      String imageStr = image.toString().trim();

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

  void _openProjectInfoPage(
    BuildContext context,
    ProjectOverviewData project,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ProjectInfosPage(
          projectTitle: project.title,
          projectLocation: project.location,
          projectImage: project.image,
          progress: project.progress,
          budget: project.budget,
          projectId: project.projectId,
        ),
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final visibleProjects = _visibleProjects;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 32,
          vertical: isMobile ? 16 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _isLoading
                ? const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  )
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
                            Text(
                              _error ?? 'An error occurred',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.red,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isLoading = true;
                                  _error = null;
                                });
                                _fetchArchivedProjects();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _archivedProjects.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.archive_outlined,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No archived projects yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Completed projects will appear here',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ArchivedProjectsHeader(
                                sortOrder: _sortOrder,
                                onSortOrderChanged: (order) {
                                  setState(() {
                                    _sortOrder = order;
                                  });
                                },
                                searchController: _searchController,
                              ),
                              const SizedBox(height: 32),
                              if (visibleProjects.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 32.0),
                                  child: Center(
                                    child: Text(
                                      'No projects match your search',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final available = constraints.maxWidth;
                                    final cardWidth = isMobile ? available : 280.0;
                                    final crossAxisCount = isMobile
                                        ? 1
                                        : (available / (cardWidth + 20)).floor()
                                            .clamp(1, 5);

                                    return GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        mainAxisSpacing: 20,
                                        crossAxisSpacing: 20,
                                        childAspectRatio: 0.85,
                                      ),
                                      itemCount: visibleProjects.length,
                                      itemBuilder: (context, index) {
                                        final project = visibleProjects[index];
                                        return GestureDetector(
                                          onTap: () =>
                                              _openProjectInfoPage(context, project),
                                          child: ProjectOverviewCard(
                                            data: project,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                            ],
                          ),
          ],
        ),
      ),
    );
  }
}

enum _ArchivedSortOrder { oldestToNewest, newestToOldest }

class _ArchivedProjectsHeader extends StatelessWidget {
  const _ArchivedProjectsHeader({
    required this.sortOrder,
    required this.onSortOrderChanged,
    required this.searchController,
  });

  final _ArchivedSortOrder sortOrder;
  final ValueChanged<_ArchivedSortOrder> onSortOrderChanged;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Projects',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0C1935),
                ),
              ),
              _SortOrderDropdown(
                value: sortOrder,
                onChanged: onSortOrderChanged,
                isMobile: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'View all projects under your supervision',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          _SearchField(isMobile: true, controller: searchController),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'All Projects',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0C1935),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'View all projects under your supervision',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        const Spacer(),
        _SearchField(isMobile: false, controller: searchController),
        const SizedBox(width: 12),
        _SortOrderDropdown(
          value: sortOrder,
          onChanged: onSortOrderChanged,
          isMobile: false,
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.isMobile, required this.controller});

  final bool isMobile;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isMobile ? null : 200,
      height: 36,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[100],
          prefixIcon: const Icon(Icons.search, size: 18),
          hintText: 'Search projects…',
          hintStyle: TextStyle(fontSize: isMobile ? 12 : 13),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF0C1935), width: 2),
          ),
        ),
      ),
    );
  }
}

class _SortOrderDropdown extends StatelessWidget {
  const _SortOrderDropdown({
    required this.value,
    required this.onChanged,
    required this.isMobile,
  });

  final _ArchivedSortOrder value;
  final ValueChanged<_ArchivedSortOrder> onChanged;
  final bool isMobile;

  String _label(_ArchivedSortOrder order) {
    switch (order) {
      case _ArchivedSortOrder.oldestToNewest:
        return 'Oldest';
      case _ArchivedSortOrder.newestToOldest:
        return 'Newest';
    }
  }

  String _fullLabel(_ArchivedSortOrder order) {
    switch (order) {
      case _ArchivedSortOrder.oldestToNewest:
        return 'Oldest to Newest';
      case _ArchivedSortOrder.newestToOldest:
        return 'Newest to Oldest';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return SizedBox(
        height: 36,
        child: PopupMenuButton<_ArchivedSortOrder>(
          onSelected: onChanged,
          itemBuilder: (BuildContext context) => _ArchivedSortOrder.values
              .map(
                (order) => PopupMenuItem(
                  value: order,
                  child: Text(_fullLabel(order)),
                ),
              )
              .toList(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label(value),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: PopupMenuButton<_ArchivedSortOrder>(
        onSelected: onChanged,
        itemBuilder: (BuildContext context) => _ArchivedSortOrder.values
            .map(
              (order) => PopupMenuItem(
                value: order,
                child: Text(_fullLabel(order)),
              ),
            )
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _fullLabel(value),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class ProjectOverviewCard extends StatelessWidget {
  const ProjectOverviewCard({super.key, required this.data});

  final ProjectOverviewData data;

  String? _resolveMediaUrl(String imagePath) {
    final value = imagePath.trim();
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

    if (value.startsWith('/')) {
      return origin.resolve(value).toString();
    }
    if (value.startsWith('media/')) {
      return origin.resolve('/$value').toString();
    }
    if (value.startsWith('project_images/')) {
      return origin.resolve('/media/$value').toString();
    }

    return origin.resolve('/media/$value').toString();
  }

  Widget _buildProjectImage(String imagePath) {
    try {
      print('🔍 Loading image: $imagePath');

      if (imagePath.isEmpty || imagePath == 'null') {
        print('⚠️ Invalid image path');
        return _buildPlaceholder();
      }

      if (imagePath.startsWith('assets/')) {
        return Image.asset(
          imagePath,
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('⚠️ Asset image load failed: $imagePath');
            return _buildPlaceholder();
          },
        );
      }

      final mediaUrl = _resolveMediaUrl(imagePath);
      if (mediaUrl != null) {
        return Image.network(
          mediaUrl,
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('⚠️ Network image load failed: $mediaUrl');
            return _buildPlaceholder();
          },
        );
      }

      try {
        final file = File(imagePath);
        if (file.existsSync()) {
          return Image.file(
            file,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print('⚠️ File image load failed: $imagePath');
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

  Color _getStatusColor(String status, {required bool isBackground}) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus == 'completed') {
      return isBackground ? const Color(0xFFE5F8ED) : const Color(0xFF10B981);
    } else if (lowerStatus == 'deactivated') {
      return isBackground ? const Color(0xFFFEECEC) : const Color(0xFFDC2626);
    } else if (lowerStatus == 'cancelled') {
      return isBackground ? const Color(0xFFFEECEC) : const Color(0xFFDC2626);
    }
    return isBackground ? const Color(0xFFF3F4F6) : const Color(0xFF6B7280);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
            ),
            child: _buildProjectImage(data.image),
          ),
          // Project Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(data.status, isBackground: true),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    data.status[0].toUpperCase() + data.status.substring(1),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(data.status, isBackground: false),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Project Title
                Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0C1935),
                  ),
                ),
                const SizedBox(height: 4),
                // Location
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        data.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Dates Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Start',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data.startDate.isNotEmpty ? data.startDate : 'TBA',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0C1935),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'End',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data.endDate.isNotEmpty ? data.endDate : 'TBA',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0C1935),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Progress',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: data.progress,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(
                          data.progress >= 1.0
                              ? const Color(0xFF10B981)
                              : const Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(data.progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Crew Info
                Row(
                  children: [
                    const Icon(Icons.people, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      '${data.crewCount} crew members',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
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
    this.onHoldReason = '',
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.progress,
    required this.crewCount,
    required this.image,
    required this.projectType,
    this.budget,
    this.createdAt = '',
    this.endDateRaw = '',
  });

  final int projectId;
  final String title;
  final String status;
  final String onHoldReason;
  final String location;
  final String startDate;
  final String endDate;
  final double progress;
  final int crewCount;
  final String image;
  final String projectType;
  final String? budget;
  final String createdAt;
  final String endDateRaw;
}

class _ProjectMetrics {
  const _ProjectMetrics({
    required this.progress,
    required this.assignedCrewCount,
  });

  final double progress;
  final int assignedCrewCount;
}
