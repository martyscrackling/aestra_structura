import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import '../../services/auth_service.dart';
import '../../services/app_config.dart';
import '../project_infos.dart';

class ActiveProject extends StatefulWidget {
  final Function(int)? onProjectLoaded;
  final bool enableSelection;

  const ActiveProject({
    super.key,
    this.onProjectLoaded,
    this.enableSelection = true,
  });

  @override
  State<ActiveProject> createState() => _ActiveProjectState();
}

class _ActiveProjectState extends State<ActiveProject> {
  List<Map<String, dynamic>> _projects = [];
  Map<int, List<dynamic>> _phasesByProjectId = {};
  int? _selectedProjectId;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _ProjectSortOrder _sortOrder = _ProjectSortOrder.oldestToNewest;
  String? _projectTypeFilter;

  @override
  void initState() {
    super.initState();
    _fetchSupervisorProjects();
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

  String _formatDate(String? date) {
    if (date == null || date.trim().isEmpty) return 'TBA';
    try {
      final parsed = DateTime.parse(date);
      return '${parsed.month.toString().padLeft(2, '0')}/${parsed.day.toString().padLeft(2, '0')}/${parsed.year}';
    } catch (_) {
      return date;
    }
  }

  String _statusLabel(Map<String, dynamic> project) {
    final type = (project['project_type'] ?? '').toString().trim();
    if (type.isNotEmpty && type != 'null') return type;
    final status = (project['status'] ?? '').toString().trim();
    if (status.isNotEmpty && status != 'null') return status;
    return 'Project';
  }

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

  Widget _buildProjectImage(Map<String, dynamic> project) {
    final imagePath = (project['project_image'] ?? '').toString().trim();

    if (imagePath.isEmpty || imagePath == 'null') {
      return _buildPlaceholderImage();
    }

    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        height: 138,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
      );
    }

    final mediaUrl = _resolveMediaUrl(imagePath);
    if (mediaUrl != null) {
      return Image.network(
        mediaUrl,
        height: 138,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
      );
    }

    try {
      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          height: 138,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
        );
      }
    } catch (_) {
      // Ignore local file path parsing errors and use fallback.
    }

    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 138,
      width: double.infinity,
      color: const Color(0xFFF3F4F6),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Color(0xFF9CA3AF),
        ),
      ),
    );
  }

  Future<void> _fetchSupervisorProjects() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?['user_id'];
      final supervisorId = authService.currentUser?['supervisor_id'];
      final fallbackProjectId = authService.currentUser?['project_id'];
      final scopeSuffix = userId != null ? '&user_id=$userId' : '';

      print('Fetching projects for supervisor_id: $supervisorId');

      if (supervisorId == null && fallbackProjectId == null) {
        print('No supervisor_id or fallback project_id found for this user');
        setState(() {
          _isLoading = false;
          _projects = [];
        });
        return;
      }

      late final http.Response projectResponse;
      if (supervisorId != null) {
        projectResponse = await http.get(
          AppConfig.apiUri('projects/?supervisor_id=$supervisorId$scopeSuffix'),
        );
      } else {
        final projectUrl = userId != null
            ? 'projects/$fallbackProjectId/?user_id=$userId'
            : 'projects/$fallbackProjectId/';
        projectResponse = await http.get(AppConfig.apiUri(projectUrl));
      }

      print('Projects API response status: ${projectResponse.statusCode}');

      if (projectResponse.statusCode != 200) {
        print(
          'Failed to fetch projects: ${projectResponse.statusCode} ${projectResponse.body}',
        );
        setState(() {
          _isLoading = false;
          _projects = [];
        });
        return;
      }

      final decoded = jsonDecode(projectResponse.body);

      final List<Map<String, dynamic>> projects;
      if (decoded is List) {
        projects = decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (decoded is Map<String, dynamic>) {
        projects = [Map<String, dynamic>.from(decoded)];
      } else {
        projects = [];
      }

      print('Projects fetched successfully: ${projects.length}');

      final Map<int, List<dynamic>> phasesByProjectId = {};
      for (final project in projects) {
        final projectIdRaw = project['project_id'];
        if (projectIdRaw == null) continue;

        final int projectId = projectIdRaw is int
            ? projectIdRaw
            : int.parse(projectIdRaw.toString());

        try {
          final phasesUrl = userId != null
              ? 'phases/?project_id=$projectId&user_id=$userId'
              : 'phases/?project_id=$projectId';
          final phasesResponse = await http.get(
            AppConfig.apiUri(phasesUrl),
          );
          if (phasesResponse.statusCode == 200) {
            phasesByProjectId[projectId] =
                jsonDecode(phasesResponse.body) as List<dynamic>;
          } else {
            phasesByProjectId[projectId] = const [];
          }
        } catch (e) {
          print('Error fetching phases for project $projectId: $e');
          phasesByProjectId[projectId] = const [];
        }
      }

      final firstProjectId = projects.isNotEmpty
          ? (projects.first['project_id'] is int
                ? projects.first['project_id'] as int
                : int.parse(projects.first['project_id'].toString()))
          : null;

      setState(() {
        _projects = projects;
        _phasesByProjectId = phasesByProjectId;
        _selectedProjectId = firstProjectId;
        _isLoading = false;
      });

      if (firstProjectId != null && widget.onProjectLoaded != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onProjectLoaded!(firstProjectId);
        });
      }
    } catch (e) {
      print('Error fetching supervisor projects: $e');
      setState(() {
        _isLoading = false;
        _projects = [];
      });
    }
  }

  double _calculateProgress(int projectId) {
    final phases = _phasesByProjectId[projectId] ?? const [];
    if (phases.isEmpty) return 0.0;

    // Count all subtasks across all phases (matching task_progress.dart)
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

  void _selectProject(int projectId) {
    setState(() {
      _selectedProjectId = projectId;
    });
    widget.onProjectLoaded?.call(projectId);
  }

  String _getLocation(Map<String, dynamic> project) {
    final street = project['street'] ?? '';
    final barangay = project['barangay_name'] ?? '';
    final city = project['city_name'] ?? '';
    final province = project['province_name'] ?? '';

    List<String> addressParts = [];
    if (street.isNotEmpty) addressParts.add(street);
    if (barangay.isNotEmpty) addressParts.add(barangay);
    if (city.isNotEmpty) addressParts.add(city);
    if (province.isNotEmpty) addressParts.add(province);

    return addressParts.isNotEmpty ? addressParts.join(', ') : 'Location TBA';
  }

  List<Map<String, dynamic>> get _visibleProjects {
    final query = _searchQuery.trim().toLowerCase();
    final filteredByType = (_projectTypeFilter == null)
        ? List<Map<String, dynamic>>.from(_projects)
        : _projects
              .where(
                (project) =>
                    (project['project_type'] ?? '').toString().trim() ==
                    _projectTypeFilter,
              )
              .toList();

    final filtered = query.isEmpty
        ? filteredByType
        : filteredByType.where((project) {
            final name = (project['project_name'] ?? '')
                .toString()
                .toLowerCase();
            final status = (project['status'] ?? '').toString().toLowerCase();
            final type = (project['project_type'] ?? '')
                .toString()
                .toLowerCase();
            final location = _getLocation(project).toLowerCase();

            return name.contains(query) ||
                status.contains(query) ||
                type.contains(query) ||
                location.contains(query);
          }).toList();

    int dateCompare(Map<String, dynamic> a, Map<String, dynamic> b) {
      DateTime? parseDate(Map<String, dynamic> value) {
        final createdAt = (value['created_at'] ?? '').toString().trim();
        final startDate = (value['start_date'] ?? '').toString().trim();

        if (createdAt.isNotEmpty && createdAt != 'null') {
          return DateTime.tryParse(createdAt);
        }
        if (startDate.isNotEmpty && startDate != 'null') {
          return DateTime.tryParse(startDate);
        }
        return null;
      }

      final dateA = parseDate(a);
      final dateB = parseDate(b);
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateA.compareTo(dateB);
    }

    filtered.sort((a, b) {
      final result = dateCompare(a, b);
      return _sortOrder == _ProjectSortOrder.newestToOldest ? -result : result;
    });

    return filtered;
  }

  List<String> get _projectTypes {
    final types =
        _projects
            .map((project) => (project['project_type'] ?? '').toString().trim())
            .where((type) => type.isNotEmpty && type != 'null')
            .toSet()
            .toList()
          ..sort();
    return types;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    // Show loading spinner
    if (_isLoading) {
      return Container(
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
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show no project message
    if (_projects.isEmpty) {
      return Container(
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
        child: const Center(
          child: Text(
            'No projects assigned',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }

    final visibleProjects = _visibleProjects;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProjectsHeader(
          searchController: _searchController,
          sortOrder: _sortOrder,
          onSortOrderChanged: (value) {
            setState(() {
              _sortOrder = value;
            });
          },
          projectTypeFilter: _projectTypeFilter,
          onProjectTypeFilterChanged: (value) {
            setState(() {
              _projectTypeFilter = value;
            });
          },
          projectTypes: _projectTypes,
        ),
        const SizedBox(height: 18),
        if (visibleProjects.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
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
              final columnCount = constraints.maxWidth >= 1200
                  ? 3
                  : constraints.maxWidth >= 760
                  ? 2
                  : 1;
              const spacing = 16.0;
              final cardWidth =
                  (constraints.maxWidth - ((columnCount - 1) * spacing)) /
                  columnCount;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: visibleProjects.map((project) {
                  final projectName =
                      project['project_name'] ?? 'Unknown Project';
                  final projectIdRaw = project['project_id'];
                  if (projectIdRaw == null) return const SizedBox.shrink();

                  final int projectId = projectIdRaw is int
                      ? projectIdRaw
                      : int.parse(projectIdRaw.toString());

                  final location = _getLocation(project);
                  final progress = _calculateProgress(projectId);
                  final progressPercentage = (progress * 100).round();
                  final startDate = _formatDate(
                    project['start_date']?.toString(),
                  );
                  final endDate = _formatDate(project['end_date']?.toString());
                  final label = _statusLabel(project);
                    final bool isSelected =
                      widget.enableSelection && _selectedProjectId == projectId;

                  return SizedBox(
                    width: cardWidth,
                    child: GestureDetector(
                      onTap: widget.enableSelection
                          ? () => _selectProject(projectId)
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFF7A18)
                                : const Color(0xFFE5E7EB),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isSelected ? 0.08 : 0.05,
                              ),
                              blurRadius: isSelected ? 16 : 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: _buildProjectImage(project),
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
                                      color: progress >= 1
                                          ? const Color(0xFFE5F8ED)
                                          : const Color(0xFFFFF2E8),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: progress >= 1
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFFF7A18),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    projectName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0C1935),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                                      Expanded(
                                        child: Text(
                                          '$startDate   •   $endDate',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 8,
                                      backgroundColor: const Color(0xFFF3F4F6),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        progress >= 1
                                            ? const Color(0xFF22C55E)
                                            : const Color(0xFFFF7A18),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: widget.enableSelection
                                        ? MainAxisAlignment.spaceBetween
                                        : MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$progressPercentage%',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0C1935),
                                        ),
                                      ),
                                      if (widget.enableSelection)
                                        Text(
                                          isSelected
                                              ? 'Selected'
                                              : 'Tap to select',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? const Color(0xFFFF7A18)
                                                : const Color(0xFF9CA3AF),
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
                                            pageBuilder: (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                            ) => ProjectInfosPage(
                                              projectTitle:
                                                  projectName.toString(),
                                              projectLocation: location,
                                              projectImage:
                                                  (project['project_image'] ?? '')
                                                      .toString(),
                                              progress: progress,
                                              budget: project['budget']
                                                  ?.toString(),
                                              projectId: projectId,
                                            ),
                                            transitionDuration: Duration.zero,
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: progress >= 1
                                              ? const Color(0xFF22C55E)
                                              : const Color(0xFFFF7A18),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'View more',
                                        style: TextStyle(
                                          color: progress >= 1
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
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        SizedBox(height: isMobile ? 8 : 12),
      ],
    );
  }
}

enum _ProjectSortOrder { oldestToNewest, newestToOldest }

class _ProjectsHeader extends StatelessWidget {
  const _ProjectsHeader({
    required this.searchController,
    required this.sortOrder,
    required this.onSortOrderChanged,
    required this.projectTypeFilter,
    required this.onProjectTypeFilterChanged,
    required this.projectTypes,
  });

  final TextEditingController searchController;
  final _ProjectSortOrder sortOrder;
  final ValueChanged<_ProjectSortOrder> onSortOrderChanged;
  final String? projectTypeFilter;
  final ValueChanged<String?> onProjectTypeFilterChanged;
  final List<String> projectTypes;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Sites',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xFFFF7A18),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Projects',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0C1935),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Monitor construction progress across all active sites.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _SearchField(
                  controller: searchController,
                  isMobile: true,
                ),
              ),
              const SizedBox(width: 8),
              _ProjectTypeFilterDropdown(
                value: projectTypeFilter,
                onChanged: onProjectTypeFilterChanged,
                types: projectTypes,
                isMobile: true,
              ),
              const SizedBox(width: 8),
              _SortOrderDropdown(
                value: sortOrder,
                onChanged: onSortOrderChanged,
                isMobile: true,
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Active Sites',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Color(0xFFFF7A18),
                ),
              ),
              SizedBox(height: 4),
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
        ),
        const SizedBox(width: 12),
        _SearchField(controller: searchController, isMobile: false),
        const SizedBox(width: 12),
        _ProjectTypeFilterDropdown(
          value: projectTypeFilter,
          onChanged: onProjectTypeFilterChanged,
          types: projectTypes,
          isMobile: false,
        ),
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
  const _SearchField({required this.controller, required this.isMobile});

  final TextEditingController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isMobile ? null : 220,
      height: 36,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[100],
          prefixIcon: const Icon(Icons.search, size: 18),
          hintText: 'Search projects...',
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

class _ProjectTypeFilterDropdown extends StatelessWidget {
  const _ProjectTypeFilterDropdown({
    required this.value,
    required this.onChanged,
    required this.types,
    required this.isMobile,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final List<String> types;
  final bool isMobile;
  static const String _allValue = '__all__';

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return SizedBox(
        height: 36,
        child: PopupMenuButton<String>(
          onSelected: (selected) {
            onChanged(selected == _allValue ? null : selected);
          },
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(value: _allValue, child: Text('All')),
            ...types.map(
              (type) => PopupMenuItem<String>(value: type, child: Text(type)),
            ),
          ],
          child: Container(
            height: 36,
            width: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              color: Colors.white,
            ),
            child: const Icon(Icons.tune, size: 16, color: Color(0xFF0C1935)),
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: PopupMenuButton<String>(
        onSelected: (selected) {
          onChanged(selected == _allValue ? null : selected);
        },
        itemBuilder: (context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(value: _allValue, child: Text('All')),
          ...types.map(
            (type) => PopupMenuItem<String>(value: type, child: Text(type)),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            color: Colors.white,
          ),
          child: Row(
            children: [
              const Icon(Icons.tune, size: 16, color: Color(0xFF0C1935)),
              const SizedBox(width: 6),
              Text(
                value ?? 'All',
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
          itemBuilder: (context) => _ProjectSortOrder.values
              .map(
                (order) => PopupMenuItem<_ProjectSortOrder>(
                  value: order,
                  child: Text(_label(order)),
                ),
              )
              .toList(),
          child: Container(
            height: 36,
            width: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              color: Colors.white,
            ),
            child: const Icon(
              Icons.swap_vert,
              size: 16,
              color: Color(0xFF0C1935),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: PopupMenuButton<_ProjectSortOrder>(
        onSelected: onChanged,
        itemBuilder: (context) => _ProjectSortOrder.values
            .map(
              (order) => PopupMenuItem<_ProjectSortOrder>(
                value: order,
                child: Text(_label(order)),
              ),
            )
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            color: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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

class _DropdownShell extends StatelessWidget {
  const _DropdownShell({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        color: Colors.white,
      ),
      child: Center(child: child),
    );
  }
}
