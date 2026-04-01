import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/responsive_page_layout.dart';
import 'modals/create_project_modal.dart';
import 'project_info.dart';
import '../services/auth_service.dart';
import '../services/app_config.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  List<ProjectOverviewData> _projects = [];
  bool _isLoading = true;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _ProjectSortOrder _sortOrder = _ProjectSortOrder.oldestToNewest;
  String? _projectTypeFilter; // null = All
  String? _statusFilter = 'Active'; // defaults to Active

  @override
  void initState() {
    super.initState();
    _fetchProjects();

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
    print('🔍 _visibleProjects called: typeFilter=$_projectTypeFilter, statusFilter=$_statusFilter, searchQuery=$_searchQuery');
    final filteredByType = (_projectTypeFilter == null)
        ? List<ProjectOverviewData>.from(_projects)
        : _projects.where((p) => p.projectType == _projectTypeFilter).toList();
    
    print('🔍 After type filter: ${filteredByType.length} projects');
    
    final filteredByStatus = (_statusFilter == null)
        ? filteredByType
        : filteredByType.where((p) => p.status.toLowerCase() == _statusFilter!.toLowerCase()).toList();
    
    print('🔍 After status filter: ${filteredByStatus.length} projects');

    final filtered = query.isEmpty
        ? filteredByStatus
        : filteredByStatus.where((project) {
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
        return dateA.compareTo(dateB); // oldest -> newest
      } catch (_) {
        return 0;
      }
    }

    int comparator(ProjectOverviewData a, ProjectOverviewData b) {
      int result = compareCreatedAt(a, b);

      if (_sortOrder == _ProjectSortOrder.newestToOldest) {
        result = -result;
      }
      return result;
    }

    filtered.sort(comparator);
    return filtered;
  }

  // Calculate progress based on subtasks (matching task_progress.dart)
  Future<double> _calculateProjectProgress(int projectId) async {
    try {
      final response = await http.get(
        AppConfig.apiUri('phases/?project_id=$projectId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> phases = jsonDecode(response.body);

        int totalSubtasks = 0;
        int completedSubtasks = 0;

        for (var phase in phases) {
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
    } catch (e) {
      print('⚠️ Error calculating progress for project $projectId: $e');
    }
    return 0.0;
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

      final url = AppConfig.apiUri('projects/?user_id=$userId');
      print('🔍 Fetching from: $url');

      final response = await http.get(url);

      print('✅ Response status: ${response.statusCode}');
      print('✅ Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('📊 Projects fetched: ${data.length}');
        
        // Debug: Print all unique status values from API
        final uniqueStatuses = <String>{};
        for (var project in data) {
          final status = (project['status'] as String?) ?? 'Active';
          uniqueStatuses.add(status);
        }
        print('🔍 Unique status values from API: $uniqueStatuses');

        // Process projects and calculate progress from phases/subtasks
        List<ProjectOverviewData> projects = [];
        for (var project in data) {
          try {
            print('📌 Processing project: ${project['project_name']}');

            // Safely convert all fields
            final int projectId = (project['project_id'] as int?) ?? 0;
            final String projectName =
                (project['project_name'] as String?) ?? 'Unknown';
            final String status = (project['status'] as String?) ?? 'Active';
            final String startDateStr =
                (project['start_date'] as String?) ?? '';
            final String endDateStr = (project['end_date'] as String?) ?? '';
            final String budget = (project['budget']?.toString()) ?? '0';
            final String createdAt = (project['created_at'] as String?) ?? '';
            final String projectType =
                (project['project_type'] as String?) ?? '';

            print('✅ Project ID: $projectId, Name: $projectName');

            // Calculate progress based on subtasks (matching task_progress.dart)
            final progress = await _calculateProjectProgress(projectId);

            projects.add(
              ProjectOverviewData(
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
                projectType: projectType,
              ),
            );
          } catch (e) {
            print('❌ Error processing project: $e');
          }
        }

        setState(() {
          _projects = projects;
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
      String? asNonEmptyString(dynamic value, {bool allowNumericOnly = false}) {
        if (value == null) return null;
        final s = value.toString().trim();
        if (s.isEmpty || s == 'null') return null;
        final numericOnly = RegExp(r'^\d+$').hasMatch(s);
        if (!allowNumericOnly && numericOnly) return null;
        return s;
      }

      // Prefer human-readable *_name fields when available.
      final street = asNonEmptyString(project['street']);
      final barangay =
          asNonEmptyString(project['barangay_name']) ??
          asNonEmptyString(project['barangay']);
      final city =
          asNonEmptyString(project['city_name']) ??
          asNonEmptyString(project['city']);
      final province =
          asNonEmptyString(project['province_name']) ??
          asNonEmptyString(project['province']);

      final parts = <String>[];
      if (street != null) parts.add(street);
      if (barangay != null) parts.add(barangay);
      if (city != null) parts.add(city);
      if (province != null) parts.add(province);

      // Fallback for APIs that return a single address/location string.
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final visibleProjects = _visibleProjects;

    return ResponsivePageLayout(
      currentPage: 'Projects',
      title: 'Projects',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
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
                  const Icon(Icons.folder_open, size: 64, color: Colors.grey),
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
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (context) => const CreateProjectModal(),
                      );
                      // Refresh projects after dialog closes
                      if (mounted) {
                        _fetchProjects();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A18),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('Add Now'),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProjectsHeader(
                  onRefresh: _fetchProjects,
                  searchController: _searchController,
                  sortOrder: _sortOrder,
                  onSortOrderChanged: (value) {
                    setState(() {
                      _sortOrder = value;
                    });
                  },
                  projectTypeFilter: _projectTypeFilter,
                  onProjectTypeFilterChanged: (value) {
                    print('🔄 Project type filter changed to: $value');
                    print('📊 Filter is null: ${value == null}');
                    print('📊 Current projects count: ${_projects.length}');
                    setState(() {
                      _projectTypeFilter = value;
                    });
                    Future.delayed(const Duration(milliseconds: 100), () {
                      print('📊 Visible projects after filter: ${_visibleProjects.length}');
                    });
                  },
                  statusFilter: _statusFilter,
                  onStatusFilterChanged: (value) {
                    print('🔄 Status filter changed to: $value');
                    print('📊 Filter is null: ${value == null}');
                    print('📊 Current projects count: ${_projects.length}');
                    setState(() {
                      _statusFilter = value;
                    });
                    Future.delayed(const Duration(milliseconds: 100), () {
                      print('📊 Visible projects after filter: ${_visibleProjects.length}');
                    });
                  },
                ),
                const SizedBox(height: 24),
                if (visibleProjects.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        '0 Projects found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columnCount = constraints.maxWidth > 1400
                          ? 4
                          : constraints.maxWidth > 1100
                          ? 3
                          : constraints.maxWidth > 800
                          ? 2
                          : 1;
                      final cardWidth =
                          (constraints.maxWidth - (columnCount - 1) * 20) /
                          columnCount;

                      return Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: visibleProjects
                            .map(
                              (project) => SizedBox(
                                width: cardWidth,
                                child: ProjectOverviewCard(data: project),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                const SizedBox(height: 32),
                if (visibleProjects.isNotEmpty)
                  ProjectListPanel(items: visibleProjects),
                SizedBox(height: isMobile ? 80 : 32), // Space for bottom nav
              ],
            ),
    );
  }
}

class _ProjectsHeader extends StatelessWidget {
  const _ProjectsHeader({
    required this.onRefresh,
    required this.searchController,
    required this.sortOrder,
    required this.onSortOrderChanged,
    required this.projectTypeFilter,
    required this.onProjectTypeFilterChanged,
    required this.statusFilter,
    required this.onStatusFilterChanged,
  });

  final VoidCallback onRefresh;
  final TextEditingController searchController;
  final _ProjectSortOrder sortOrder;
  final ValueChanged<_ProjectSortOrder> onSortOrderChanged;
  final String? projectTypeFilter;
  final ValueChanged<String?> onProjectTypeFilterChanged;
  final String? statusFilter;
  final ValueChanged<String?> onStatusFilterChanged;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    if (isMobile) {
      // Mobile layout: Stack vertically
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Projects',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C1935),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Monitor construction progress across all active sites.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Controls row for mobile
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A18),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (context) => const CreateProjectModal(),
                      );
                      // Refresh projects after dialog closes
                      onRefresh();
                    },
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: const Text(
                      'Create',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _SearchField(
                  isMobile: true,
                  controller: searchController,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 36,
                    child: _ProjectTypeFilterDropdown(
                      value: projectTypeFilter,
                      onChanged: onProjectTypeFilterChanged,
                      isMobile: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 36,
                    child: _StatusFilterDropdown(
                      value: statusFilter,
                      onChanged: onStatusFilterChanged,
                      isMobile: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 36,
                    child: _SortOrderDropdown(
                      value: sortOrder,
                      onChanged: onSortOrderChanged,
                      isMobile: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    // Desktop layout: Single row
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
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (context) => const CreateProjectModal(),
              );
              // Refresh projects after dialog closes
              onRefresh();
            },
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: const Text(
              'Create Project',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        _SearchField(isMobile: false, controller: searchController),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Project Type',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            _ProjectTypeFilterDropdown(
              value: projectTypeFilter,
              onChanged: onProjectTypeFilterChanged,
              isMobile: false,
            ),
          ],
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Status',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            _StatusFilterDropdown(
              value: statusFilter,
              onChanged: onStatusFilterChanged,
              isMobile: false,
            ),
          ],
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sort By',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            _SortOrderDropdown(
              value: sortOrder,
              onChanged: onSortOrderChanged,
              isMobile: false,
            ),
          ],
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
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFF0C1935), width: 2),
          ),
        ),
      ),
    );
  }
}

enum _ProjectSortOrder { oldestToNewest, newestToOldest }

class _StatusFilterDropdown extends StatelessWidget {
  const _StatusFilterDropdown({
    required this.value,
    required this.onChanged,
    required this.isMobile,
  });

  final String? value; // null = All
  final ValueChanged<String?> onChanged;
  final bool isMobile;

  static const List<String> _statuses = [
    'Active',
    'On Hold',
    'Deactivated',
  ];

  @override
  Widget build(BuildContext context) {
    final displayText = value ?? 'All';

    if (isMobile) {
      return SizedBox(
        height: 36,
        child: PopupMenuButton<String?>(
          onSelected: (selected) {
            print('✅ Status (mobile) selected: $selected');
            // Convert placeholder 'ALL' back to null
            final result = selected == 'ALL' ? null : selected;
            print('✅ Status (mobile) after conversion: $result');
            onChanged(result);
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String?>>[
            const PopupMenuItem<String?>(value: 'ALL', child: Text('All')),
            ..._statuses.map(
              (status) => PopupMenuItem<String?>(value: status, child: Text(status)),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF0C1935)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF0C1935)),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: PopupMenuButton<String?>(
        onSelected: (selected) {
          print('✅ Status (desktop) selected: $selected');
          // Convert placeholder 'ALL' back to null
          final result = selected == 'ALL' ? null : selected;
          print('✅ Status (desktop) after conversion: $result');
          onChanged(result);
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String?>>[
          const PopupMenuItem<String?>(value: 'ALL', child: const Text('All')),
          ..._statuses.map(
            (status) => PopupMenuItem<String?>(value: status, child: Text(status)),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF0C1935)),
              const SizedBox(width: 6),
              Text(
                displayText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0C1935),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: Color(0xFF0C1935),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectTypeFilterDropdown extends StatelessWidget {
  const _ProjectTypeFilterDropdown({
    required this.value,
    required this.onChanged,
    required this.isMobile,
  });

  final String? value; // null = All
  final ValueChanged<String?> onChanged;
  final bool isMobile;

  static const List<String> _types = [
    'Residential',
    'Commercial',
    'Infrastructure',
    'Industrial',
  ];

  @override
  Widget build(BuildContext context) {
    final displayText = value ?? 'All';

    if (isMobile) {
      return SizedBox(
        height: 36,
        child: PopupMenuButton<String?>(
          onSelected: (selected) {
            print('✅ ProjectType (mobile) selected: $selected');
            // Convert placeholder 'ALL' back to null
            final result = selected == 'ALL' ? null : selected;
            print('✅ ProjectType (mobile) after conversion: $result');
            onChanged(result);
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String?>>[
            const PopupMenuItem<String?>(value: 'ALL', child: const Text('All')),
            ..._types.map(
              (type) => PopupMenuItem<String?>(value: type, child: Text(type)),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tune, size: 16, color: Color(0xFF0C1935)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF0C1935)),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: PopupMenuButton<String?>(
        onSelected: (selected) {
          print('✅ ProjectType (desktop) selected: $selected');
          // Convert placeholder 'ALL' back to null
          final result = selected == 'ALL' ? null : selected;
          print('✅ ProjectType (desktop) after conversion: $result');
          onChanged(result);
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String?>>[
          const PopupMenuItem<String?>(value: 'ALL', child: Text('All')),
          ..._types.map(
            (type) => PopupMenuItem<String?>(value: type, child: Text(type)),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.tune, size: 16, color: Color(0xFF0C1935)),
              const SizedBox(width: 6),
              Text(
                displayText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0C1935),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: Color(0xFF0C1935),
              ),
            ],
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

  final _ProjectSortOrder value;
  final ValueChanged<_ProjectSortOrder> onChanged;
  final bool isMobile;

  String _label(_ProjectSortOrder order) {
    switch (order) {
      case _ProjectSortOrder.oldestToNewest:
        return 'Oldest to Newest';
      case _ProjectSortOrder.newestToOldest:
        return 'Newest to Oldest';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return SizedBox(
        height: 36,
        child: PopupMenuButton<_ProjectSortOrder>(
          onSelected: onChanged,
          itemBuilder: (BuildContext context) => _ProjectSortOrder.values
              .map(
                (order) => PopupMenuItem<_ProjectSortOrder>(
                  value: order,
                  child: Text(_label(order)),
                ),
              )
              .toList(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.swap_vert, size: 16, color: Color(0xFF0C1935)),
                SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF0C1935)),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: PopupMenuButton<_ProjectSortOrder>(
        onSelected: onChanged,
        itemBuilder: (BuildContext context) => _ProjectSortOrder.values
            .map(
              (order) => PopupMenuItem<_ProjectSortOrder>(
                value: order,
                child: Text(_label(order)),
              ),
            )
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.swap_vert, size: 16, color: Color(0xFF0C1935)),
              const SizedBox(width: 6),
              Text(
                _label(value),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0C1935),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: Color(0xFF0C1935),
              ),
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

    // Default fallback for any stored relative media path.
    return origin.resolve('/media/$value').toString();
  }

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

      final mediaUrl = _resolveMediaUrl(imagePath);
      if (mediaUrl != null) {
        return Image.network(
          mediaUrl,
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('⚠️ Network image failed to load: $mediaUrl');
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

  Color _getStatusColor(String status, {required bool isBackground}) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus == 'active') {
      return isBackground ? const Color(0xFFE5F8ED) : const Color(0xFF10B981);
    } else if (lowerStatus == 'on hold') {
      return isBackground ? const Color(0xFFFFF2E8) : const Color(0xFFFF7A18);
    } else if (lowerStatus == 'deactivated') {
      return isBackground ? const Color(0xFFFEECEC) : const Color(0xFFDC2626);
    }
    // Default
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
                Row(
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
                        data.projectType.isNotEmpty
                            ? data.projectType
                            : 'Project',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: data.progress >= 1
                              ? const Color(0xFF10B981)
                              : const Color(0xFFFF7A18),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(data.status, isBackground: true),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        data.status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(data.status, isBackground: false),
                        ),
                      ),
                    ),
                  ],
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
                          project.projectType.isNotEmpty
                              ? project.projectType
                              : project.status,
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
