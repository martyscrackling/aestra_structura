import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'widgets/responsive_page_layout.dart';
import '../services/auth_service.dart';
import '../services/app_config.dart';

class ArchivedProjectsPage extends StatefulWidget {
  const ArchivedProjectsPage({super.key});

  @override
  State<ArchivedProjectsPage> createState() => _ArchivedProjectsPageState();
}

class _ArchivedProjectsPageState extends State<ArchivedProjectsPage> {
  List<ProjectOverviewData> _archivedProjects = [];
  bool _isLoading = true;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _ArchivedSortOrder _sortOrder = _ArchivedSortOrder.oldestToNewest;

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

    int compareCreatedAt(ProjectOverviewData a, ProjectOverviewData b) {
      try {
        if (a.createdAt.isEmpty && b.createdAt.isEmpty) return 0;
        if (a.createdAt.isEmpty) return 1;
        if (b.createdAt.isEmpty) return -1;
        final dateA = DateTime.parse(a.createdAt);
        final dateB = DateTime.parse(b.createdAt);
        return dateA.compareTo(dateB);
      } catch (_) {
        return 0;
      }
    }

    int comparator(ProjectOverviewData a, ProjectOverviewData b) {
      int result = compareCreatedAt(a, b);

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
            final assignedWorkers = subtaskMap['assigned_workers'];
            if (assignedWorkers is List) {
              for (var worker in assignedWorkers) {
                final workerId = (worker['id'] as int?) ??
                    (worker['fieldworker_id'] as int?) ??
                    (worker['supervisor_id'] as int?);
                if (workerId != null) {
                  assignedWorkerIds.add(workerId);
                }
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

  Future<int> _fetchProjectWorkforceCount({
    required int projectId,
    required dynamic userId,
  }) async {
    try {
      final response = await http.get(
        AppConfig.apiUri(
          'field-workers/?project_id=$projectId&user_id=$userId',
        ),
      );

      if (response.statusCode != 200) return 0;

      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.length;
      }
      if (decoded is Map<String, dynamic>) {
        final results = decoded['results'];
        if (results is List) {
          return results.length;
        }
        final data = decoded['data'];
        if (data is List) {
          return data.length;
        }
      }
      return 0;
    } catch (e) {
      print('⚠️ Error fetching workforce count for project $projectId: $e');
      return 0;
    }
  }

  Future<void> _fetchArchivedProjects() async {
    try {
      final authService = AuthService();
      final userId = authService.currentUser?['user_id'];

      print('🔍 _fetchArchivedProjects called');
      print('🔍 User ID: $userId');

      if (userId == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      final url = AppConfig.apiUri('projects/?user_id=$userId');
      print('🔍 Fetching from: $url');

      final response = await http.get(url);

      print('✅ Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('📊 Projects fetched: ${data.length}');

        // Filter for archived statuses: Deactivated, Cancelled, Completed
        final archivedStatuses = ['Deactivated', 'Cancelled', 'Completed'];
        final archivedData =
            data.where((p) => archivedStatuses.contains(p['status'])).toList();

        print('📊 Archived projects: ${archivedData.length}');

        List<ProjectOverviewData> projects = [];
        for (var project in archivedData) {
          try {
            print('📌 Processing archived project: ${project['project_name']}');

            final int projectId = (project['project_id'] as int?) ?? 0;
            final String projectName =
                (project['project_name'] as String?) ?? 'Unknown';
            final String status = (project['status'] as String?) ?? 'Unknown';
            final String startDateStr =
                (project['start_date'] as String?) ?? '';
            final String endDateStr = (project['end_date'] as String?) ?? '';
            final String budget = (project['budget']?.toString()) ?? '0';
            final String createdAt = (project['created_at'] as String?) ?? '';
            final String projectType =
                (project['project_type'] as String?) ?? '';
            final metrics = await _calculateProjectMetrics(projectId);
            final int projectWorkforceCount = await _fetchProjectWorkforceCount(
              projectId: projectId,
              userId: userId,
            );

            print('✅ Archived Project ID: $projectId, Name: $projectName');

            projects.add(
              ProjectOverviewData(
                projectId: projectId,
                title: projectName,
                status: status,
                location: _buildLocation(project),
                startDate: _formatDate(startDateStr),
                endDate: _formatDate(endDateStr),
                progress: metrics.progress,
                crewCount: metrics.assignedCrewCount > 0
                    ? metrics.assignedCrewCount
                    : projectWorkforceCount,
                image: _getProjectImage(project),
                projectType: projectType,
                budget: budget,
                createdAt: createdAt,
              ),
            );
          } catch (e) {
            print('❌ Error processing archived project: $e');
          }
        }

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
      final city =
          asNonEmptyString(project['city_name']) ??
          asNonEmptyString(project['city']);
      final province = asNonEmptyString(project['province_name']) ??
          asNonEmptyString(project['province']);

      final parts = <String>[];
      if (street != null) parts.add(street);
      if (barangay != null) parts.add(barangay);
      if (city != null) parts.add(city);
      if (province != null) parts.add(province);

      if (parts.isEmpty) {
        final fallback =
            asNonEmptyString(project['project_location']) ??
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final visibleProjects = _visibleProjects;

    return ResponsivePageLayout(
      currentPage: 'Archived',
      title: 'Archived Projects',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 64, color: Color(0xFFDC2626)),
                  const SizedBox(height: 16),
                  Text(
                    'Error Loading Projects',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _error = null;
                      });
                      _fetchArchivedProjects();
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            )
          : _archivedProjects.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No Archived Projects',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Deactivated, cancelled, or completed projects will appear here.',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Active Projects'),
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
                    setState(() => _sortOrder = order);
                  },
                  searchController: _searchController,
                ),
                const SizedBox(height: 24),
                if (visibleProjects.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No projects match your search.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                else
                  ProjectListPanel(items: visibleProjects),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Archived Projects',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'View deactivated, cancelled, and completed projects.',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SearchField(isMobile: true, controller: searchController),
          const SizedBox(height: 12),
          _SortOrderDropdown(
            value: sortOrder,
            onChanged: onSortOrderChanged,
            isMobile: true,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Archived Projects',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'View deactivated, cancelled, and completed projects.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        const Spacer(),
        _SearchField(isMobile: false, controller: searchController),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sort By',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
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

enum _ArchivedSortOrder { oldestToNewest, newestToOldest }

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
                (order) => PopupMenuItem<_ArchivedSortOrder>(
                  value: order,
                  child: Text(_fullLabel(order)),
                ),
              )
              .toList(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label(value),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.expand_more, size: 16),
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
              (order) => PopupMenuItem<_ArchivedSortOrder>(
                value: order,
                child: Text(_fullLabel(order)),
              ),
            )
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _label(value),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.expand_more, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// Reuse the same ProjectOverviewCard and ProjectListPanel from projects_page.dart
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
            print('❌ Error loading asset: $imagePath');
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
            print('❌ Error loading network image: $mediaUrl');
            return _buildPlaceholder();
          },
        );
      }

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
              print('❌ Error loading file image: $imagePath');
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
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
            child: _buildProjectImage(data.image),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.location,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(data.status, isBackground: true),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        data.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(data.status, isBackground: false),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Progress',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
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
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(Color(0xFFFF7A18)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(data.progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Assigned Crew',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${data.crewCount} members',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Duration',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${data.startDate} - ${data.endDate}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1F2937),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Projects (${items.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () {
                  // Navigate to project details if needed
                  print('📌 Tapped project: ${item.title}');
                },
                child: ProjectOverviewCard(data: item),
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
    required this.projectType,
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
  final String projectType;
  final String? budget;
  final String createdAt;
}

class _ProjectMetrics {
  const _ProjectMetrics({
    required this.progress,
    required this.assignedCrewCount,
  });

  final double progress;
  final int assignedCrewCount;
}