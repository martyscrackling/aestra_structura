import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import '../../services/auth_service.dart';
import '../../services/app_config.dart';
import '../../services/app_theme_tokens.dart';
import '../project_infos.dart';
import 'project_archive_sv.dart';

class ActiveProject extends StatefulWidget {
  final Function(int)? onProjectLoaded;
  final bool enableSelection;
  final bool scrollOnlyCards;
  final double? cardsViewportHeight;
  final bool compactCards;
  final bool carouselWhenMultiple;
  final int? deepLinkProjectId;
  final int? deepLinkPhaseId;
  final int? deepLinkSubtaskId;

  const ActiveProject({
    super.key,
    this.onProjectLoaded,
    this.enableSelection = true,
    this.scrollOnlyCards = false,
    this.cardsViewportHeight,
    this.compactCards = false,
    this.carouselWhenMultiple = false,
    this.deepLinkProjectId,
    this.deepLinkPhaseId,
    this.deepLinkSubtaskId,
  });

  @override
  State<ActiveProject> createState() => _ActiveProjectState();
}

class _ActiveProjectState extends State<ActiveProject> {
  List<Map<String, dynamic>> _projects = [];
  Map<int, List<dynamic>> _phasesByProjectId = {};
  Map<int, double> _progressByProjectId = {};
  int? _selectedProjectId;
  bool _isLoading = true;
  bool _inboxDeepLinkDetailOpened = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _cardsScrollController = ScrollController();
  final PageController _carouselController = PageController(
    viewportFraction: 0.8,
  );
  String _searchQuery = '';
  _ProjectSortOrder _sortOrder = _ProjectSortOrder.oldestToNewest;
  String? _projectTypeFilter;
  int _carouselIndex = 0;
  bool _isCarouselHovered = false;

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
    _cardsScrollController.dispose();
    _carouselController.dispose();
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

  Widget _buildProjectImage(
    Map<String, dynamic> project, {
    double height = 138,
  }) {
    final imagePath = (project['project_image'] ?? '').toString().trim();

    if (imagePath.isEmpty || imagePath == 'null') {
      return _buildPlaceholderImage(height: height);
    }

    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholderImage(height: height),
      );
    }

    final mediaUrl = _resolveMediaUrl(imagePath);
    if (mediaUrl != null) {
      return Image.network(
        mediaUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholderImage(height: height),
      );
    }

    try {
      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholderImage(height: height),
        );
      }
    } catch (_) {
      // Ignore local file path parsing errors and use fallback.
    }

    return _buildPlaceholderImage(height: height);
  }

  Widget _buildPlaceholderImage({double height = 138}) {
    return Container(
      height: height,
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

      if (supervisorId == null && fallbackProjectId == null) {
        if (!mounted) return;
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

      if (projectResponse.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _projects = [];
        });
        return;
      }

      final decoded = jsonDecode(projectResponse.body);

      final projects = _parseProjectsPayload(decoded);
      final phasesByProjectId = await _fetchPhasesByProjectId(
        projects: projects,
        userId: userId,
      );
      final progressByProjectId = _buildProgressByProjectId(phasesByProjectId);

      final firstProjectId = projects.isNotEmpty
          ? (projects.first['project_id'] is int
                ? projects.first['project_id'] as int
                : int.tryParse(projects.first['project_id'].toString()))
          : null;

      int? linkPid = widget.deepLinkProjectId;
      if (linkPid != null) {
        final exists = projects.any((p) {
          final r = p['project_id'];
          final id = r is int ? r : int.tryParse(r.toString());
          return id == linkPid;
        });
        if (!exists) linkPid = null;
      }
      final selectedId = linkPid ?? firstProjectId;

      if (!mounted) return;
      setState(() {
        _projects = projects;
        _phasesByProjectId = phasesByProjectId;
        _progressByProjectId = progressByProjectId;
        _selectedProjectId = selectedId;
        _isLoading = false;
      });

      if (selectedId != null && widget.onProjectLoaded != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onProjectLoaded!(selectedId);
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeOpenInboxDeepLink();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _projects = [];
      });
    }
  }

  List<Map<String, dynamic>> _parseProjectsPayload(dynamic payload) {
    if (payload is List) {
      return payload
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    if (payload is Map<String, dynamic>) {
      return [Map<String, dynamic>.from(payload)];
    }
    return <Map<String, dynamic>>[];
  }

  List<dynamic> _parsePhasesPayload(dynamic payload) {
    if (payload is List) {
      return payload;
    }
    if (payload is Map<String, dynamic>) {
      if (payload['results'] is List) {
        return payload['results'] as List<dynamic>;
      }
      if (payload['data'] is List) {
        return payload['data'] as List<dynamic>;
      }
    }
    return <dynamic>[];
  }

  Future<Map<int, List<dynamic>>> _fetchPhasesByProjectId({
    required List<Map<String, dynamic>> projects,
    required dynamic userId,
  }) async {
    final futures = projects.map((project) async {
      final projectIdRaw = project['project_id'];
      if (projectIdRaw == null) return null;

      final int? projectId = projectIdRaw is int
          ? projectIdRaw
          : int.tryParse(projectIdRaw.toString());
      if (projectId == null || projectId <= 0) return null;

      final phasesUrl = userId != null
          ? 'phases/?project_id=$projectId&user_id=$userId'
          : 'phases/?project_id=$projectId';

      try {
        final phasesResponse = await http.get(AppConfig.apiUri(phasesUrl));
        if (phasesResponse.statusCode == 200) {
          final decoded = jsonDecode(phasesResponse.body);
          return MapEntry(projectId, _parsePhasesPayload(decoded));
        }
      } catch (_) {
        // Keep fallback behavior.
      }

      return MapEntry(projectId, const <dynamic>[]);
    }).toList(growable: false);

    final resolved = await Future.wait<MapEntry<int, List<dynamic>>?>(futures);
    final map = <int, List<dynamic>>{};
    for (final entry in resolved.whereType<MapEntry<int, List<dynamic>>>()) {
      map[entry.key] = entry.value;
    }
    return map;
  }

  Map<int, double> _buildProgressByProjectId(
    Map<int, List<dynamic>> phasesByProjectId,
  ) {
    final progress = <int, double>{};
    for (final entry in phasesByProjectId.entries) {
      progress[entry.key] = _calculateProgressFromPhases(entry.value);
    }
    return progress;
  }

  double _calculateProgressFromPhases(List<dynamic> phases) {
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

  int? _parseProjectId(Map<String, dynamic> project) {
    final projectIdRaw = project['project_id'];
    if (projectIdRaw == null) return null;
    if (projectIdRaw is int) return projectIdRaw;
    return int.tryParse(projectIdRaw.toString());
  }

  Map<String, dynamic>? _projectById(int id) {
    for (final p in _projects) {
      if (_parseProjectId(p) == id) return p;
    }
    return null;
  }

  void _openProjectInfoPage(
    BuildContext context,
    Map<String, dynamic> project, {
    int? focusPhaseId,
    int? focusSubtaskId,
  }) {
    final projectName = project['project_name'] ?? 'Unknown Project';
    final projectId = _parseProjectId(project);
    if (projectId == null || projectId <= 0) return;
    final location = _getLocation(project);
    final progress = _progressByProjectId[projectId] ?? 0.0;
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ProjectInfosPage(
          projectTitle: projectName.toString(),
          projectLocation: location,
          projectImage: (project['project_image'] ?? '').toString(),
          progress: progress,
          budget: project['budget']?.toString(),
          projectId: projectId,
          focusPhaseId: focusPhaseId,
          focusSubtaskId: focusSubtaskId,
        ),
        transitionDuration: Duration.zero,
      ),
    );
  }

  void _maybeOpenInboxDeepLink() {
    if (!mounted) return;
    if (_inboxDeepLinkDetailOpened) return;
    final pid = widget.deepLinkProjectId;
    if (pid == null) return;
    final project = _projectById(pid);
    if (project == null) return;

    final hasFocus = widget.deepLinkPhaseId != null ||
        widget.deepLinkSubtaskId != null;
    if (hasFocus) {
      _inboxDeepLinkDetailOpened = true;
      _openProjectInfoPage(
        context,
        project,
        focusPhaseId: widget.deepLinkPhaseId,
        focusSubtaskId: widget.deepLinkSubtaskId,
      );
    }
  }

  void _selectProject(int projectId) {
    setState(() {
      _selectedProjectId = projectId;
    });
    widget.onProjectLoaded?.call(projectId);
  }

  void _goToCarouselPage(int page, int totalCount) {
    if (page < 0 || page >= totalCount) return;
    _carouselController.animateToPage(
      page,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
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
    final useCarousel =
        widget.carouselWhenMultiple && visibleProjects.length >= 2;
    final compact = widget.compactCards;

    final projectsContent = visibleProjects.isEmpty
        ? const Padding(
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
        : LayoutBuilder(
            builder: (context, constraints) {
              final columnCount = constraints.maxWidth >= 1200
                  ? 3
                  : constraints.maxWidth >= 760
                  ? 2
                  : 1;
              const spacing = 12.0;
              final cardWidth =
                  (constraints.maxWidth - ((columnCount - 1) * spacing)) /
                  columnCount;

              Widget buildProjectCard(
                Map<String, dynamic> project, {
                double? width,
              }) {
                final projectName =
                    project['project_name'] ?? 'Unknown Project';
                final projectIdRaw = project['project_id'];
                if (projectIdRaw == null) return const SizedBox.shrink();

                final int projectId = projectIdRaw is int
                    ? projectIdRaw
                  : int.tryParse(projectIdRaw.toString()) ?? -1;
                if (projectId <= 0) return const SizedBox.shrink();

                final location = _getLocation(project);
                final progress = _progressByProjectId[projectId] ?? 0.0;
                final progressPercentage = (progress * 100).round();
                final startDate = _formatDate(
                  project['start_date']?.toString(),
                );
                final endDate = _formatDate(project['end_date']?.toString());
                final label = _statusLabel(project);
                final bool isSelected =
                    widget.enableSelection && _selectedProjectId == projectId;

                final imageHeight = compact
                    ? (isMobile ? 148.0 : 168.0)
                    : 200.0;
                final contentPadding = compact ? 10.0 : 18.0;
                final titleSize = compact ? 13.0 : 18.0;
                final metaSize = compact ? 10.0 : 13.0;
                final chipFont = compact ? 9.5 : 12.0;
                final progressHeight = compact ? 4.0 : 8.0;

                return SizedBox(
                  width: width ?? cardWidth,
                  child: GestureDetector(
                    onTap: widget.enableSelection
                        ? () => _selectProject(projectId)
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(compact ? 10 : 18),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
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
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(compact ? 8 : 16),
                            ),
                            child: _buildProjectImage(
                              project,
                              height: imageHeight,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              contentPadding,
                              contentPadding + (compact ? 3 : 6),
                              contentPadding,
                              contentPadding,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: compact ? 6 : 10,
                                    vertical: compact ? 1.5 : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: chipFont,
                                      fontWeight: FontWeight.w600,
                                      color: progress >= 1
                                          ? const Color(0xFF10B981)
                                          : AppColors.accent,
                                    ),
                                  ),
                                ),
                                SizedBox(height: compact ? 5 : 12),
                                Text(
                                  projectName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0C1935),
                                  ),
                                ),
                                SizedBox(height: compact ? 2 : 6),
                                Text(
                                  location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: metaSize,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                                SizedBox(height: compact ? 6 : 14),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: compact ? 11 : 14,
                                      color: Color(0xFFA0AEC0),
                                    ),
                                    SizedBox(width: compact ? 3 : 5),
                                    Expanded(
                                      child: Text(
                                        '$startDate   •   $endDate',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: compact ? 9.5 : 12,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: compact ? 6 : 14),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: progressHeight,
                                    backgroundColor: const Color(0xFFF3F4F6),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      progress >= 1
                                          ? const Color(0xFF22C55E)
                                          : AppColors.accent,
                                    ),
                                  ),
                                ),
                                SizedBox(height: compact ? 4 : 8),
                                Row(
                                  mainAxisAlignment: widget.enableSelection
                                      ? MainAxisAlignment.spaceBetween
                                      : MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$progressPercentage%',
                                      style: TextStyle(
                                        fontSize: compact ? 10.5 : 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0C1935),
                                      ),
                                    ),
                                    if (widget.enableSelection)
                                      Text(
                                        isSelected
                                            ? 'Selected'
                                            : 'Tap to select',
                                        style: TextStyle(
                                          fontSize: compact ? 9.5 : 12,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? AppColors.accent
                                              : const Color(0xFF9CA3AF),
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: compact ? 6 : 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      _openProjectInfoPage(
                                        context,
                                        project,
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: progress >= 1
                                            ? const Color(0xFF22C55E)
                                            : AppColors.accent,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      visualDensity: compact
                                          ? VisualDensity.compact
                                          : VisualDensity.standard,
                                      tapTargetSize: compact
                                          ? MaterialTapTargetSize.shrinkWrap
                                          : MaterialTapTargetSize.padded,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: compact ? 6 : 12,
                                        vertical: compact ? 5 : 10,
                                      ),
                                    ),
                                    child: Text(
                                      'View more',
                                      style: TextStyle(
                                        color: progress >= 1
                                            ? const Color(0xFF22C55E)
                                            : AppColors.accent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: compact ? 10 : 13,
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
              }

              if (useCarousel) {
                final targetViewport =
                    widget.cardsViewportHeight ??
                    (compact
                        ? (isMobile ? 360.0 : 390.0)
                        : (isMobile ? 352.0 : 372.0));
                return SizedBox(
                  height: targetViewport,
                  child: LayoutBuilder(
                    builder: (context, viewportConstraints) {
                      final showDots = viewportConstraints.maxHeight >= 260;

                      return Column(
                        children: [
                          Expanded(
                            child: MouseRegion(
                              onEnter: (_) {
                                if (isMobile ||
                                    !_carouselController.hasClients) {
                                  return;
                                }
                                setState(() {
                                  _isCarouselHovered = true;
                                });
                              },
                              onExit: (_) {
                                if (!_isCarouselHovered) return;
                                setState(() {
                                  _isCarouselHovered = false;
                                });
                              },
                              child: Stack(
                                children: [
                                  PageView.builder(
                                    controller: _carouselController,
                                    padEnds: false,
                                    itemCount: visibleProjects.length,
                                    onPageChanged: (index) {
                                      setState(() {
                                        _carouselIndex = index;
                                      });

                                      final rawId =
                                          visibleProjects[index]['project_id'];
                                      final projectId = rawId is int
                                          ? rawId
                                          : int.tryParse(rawId.toString());
                                      if (projectId != null &&
                                          widget.enableSelection) {
                                        _selectProject(projectId);
                                      }
                                    },
                                    itemBuilder: (context, index) {
                                      return AnimatedBuilder(
                                        animation: _carouselController,
                                        child: buildProjectCard(
                                          visibleProjects[index],
                                          width: double.infinity,
                                        ),
                                        builder: (context, child) {
                                          double page = _carouselIndex
                                              .toDouble();
                                          if (_carouselController.hasClients) {
                                            page =
                                                _carouselController.page ??
                                                page;
                                          }

                                          final distance = (page - index)
                                              .abs()
                                              .clamp(0.0, 1.0);
                                          final scale = 1.0 - (distance * 0.12);
                                          final opacity =
                                              1.0 - (distance * 0.2);
                                          final verticalInset = distance * 2;

                                          return Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: compact ? 4 : 6,
                                              vertical: verticalInset,
                                            ),
                                            child: Align(
                                              alignment: Alignment.topCenter,
                                              child: Opacity(
                                                opacity: opacity,
                                                child: Transform.scale(
                                                  scale: scale,
                                                  alignment:
                                                      Alignment.topCenter,
                                                  child: child,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                  if (!isMobile)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        ignoring: !_isCarouselHovered,
                                        child: AnimatedOpacity(
                                          duration: const Duration(
                                            milliseconds: 160,
                                          ),
                                          opacity: _isCarouselHovered ? 1 : 0,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                _CarouselArrowButton(
                                                  icon: Icons
                                                      .chevron_left_rounded,
                                                  enabled: _carouselIndex > 0,
                                                  onPressed: () =>
                                                      _goToCarouselPage(
                                                        _carouselIndex - 1,
                                                        visibleProjects.length,
                                                      ),
                                                ),
                                                _CarouselArrowButton(
                                                  icon: Icons
                                                      .chevron_right_rounded,
                                                  enabled:
                                                      _carouselIndex <
                                                      visibleProjects.length -
                                                          1,
                                                  onPressed: () =>
                                                      _goToCarouselPage(
                                                        _carouselIndex + 1,
                                                        visibleProjects.length,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (showDots) const SizedBox(height: 8),
                          if (showDots)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(visibleProjects.length, (
                                index,
                              ) {
                                final isActive = index == _carouselIndex;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  width: isActive ? 16 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AppColors.accent
                                        : const Color(0xFFD1D5DB),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                );
                              }),
                            ),
                        ],
                      );
                    },
                  ),
                );
              }

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: visibleProjects
                    .map((project) => buildProjectCard(project))
                    .toList(),
              );
            },
          );

    final shouldScrollCards =
        widget.scrollOnlyCards && (widget.cardsViewportHeight ?? 0) > 0;

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
        if (shouldScrollCards)
          SizedBox(
            height: widget.cardsViewportHeight!,
            child: useCarousel
                ? projectsContent
                : Scrollbar(
                    controller: _cardsScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _cardsScrollController,
                      primary: false,
                      physics: const ClampingScrollPhysics(),
                      child: projectsContent,
                    ),
                  ),
          )
        else
          projectsContent,
        SizedBox(height: isMobile ? 8 : 12),
      ],
    );
  }
}

enum _ProjectSortOrder { oldestToNewest, newestToOldest }

class _CarouselArrowButton extends StatelessWidget {
  const _CarouselArrowButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xE60C1935) : const Color(0x809CA3AF),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: enabled ? onPressed : null,
          icon: Icon(icon, size: 20, color: Colors.white),
          splashRadius: 18,
          tooltip: icon == Icons.chevron_left_rounded
              ? 'Previous project'
              : 'Next project',
        ),
      ),
    );
  }
}

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
              color: AppColors.accent,
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
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(color: Color(0xFFFF7A18), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProjectArchiveSv()),
                      );
                    },
                    icon: const Icon(Icons.archive, size: 16, color: Color(0xFFFF7A18)),
                    label: const Text(
                      'Archived',
                      style: TextStyle(
                        color: Color(0xFFFF7A18),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                  color: AppColors.accent,
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
        SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              side: const BorderSide(color: Color(0xFFFF7A18), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProjectArchiveSv()),
              );
            },
            icon: const Icon(Icons.archive, size: 18, color: Color(0xFFFF7A18)),
            label: const Text(
              'Archived',
              style: TextStyle(
                color: Color(0xFFFF7A18),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
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
          color: Colors.white,
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
