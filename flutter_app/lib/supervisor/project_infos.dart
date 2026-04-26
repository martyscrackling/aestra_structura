import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/mobile_bottom_nav.dart';
import '../services/app_config.dart';
import '../services/auth_service.dart';
import '../services/app_time_service.dart';
import 'task_update.dart';
import 'all_workforce.dart';
import 'modals/record_usage_modal.dart';
import '../services/budget_service.dart';

class ProjectInfosPage extends StatefulWidget {
  final String projectTitle;
  final String projectLocation;
  final String projectImage;
  final double progress;
  final String? budget;
  final int projectId;
  final int? focusPhaseId;
  final int? focusSubtaskId;

  const ProjectInfosPage({
    super.key,
    required this.projectTitle,
    required this.projectLocation,
    required this.projectImage,
    required this.progress,
    this.budget,
    required this.projectId,
    this.focusPhaseId,
    this.focusSubtaskId,
  });

  @override
  State<ProjectInfosPage> createState() => _ProjectInfosPageState();
}

class _ProjectInfosPageState extends State<ProjectInfosPage> {
  Map<String, dynamic>? _clientInfo;
  Map<String, dynamic>? _projectInfo;
  List<dynamic>? _phases;
  List<dynamic> _backJobReviews = const [];
  bool _isLoading = true;
  String? _error;
  bool _showDaysLeftReminder = true;

  /// Per-phase planned-vs-actual material breakdown, keyed by phase id.
  /// Budget figures are intentionally NOT kept here — supervisors only
  /// see quantities (pcs, bags, etc.), never monetary amounts.
  final Map<int, List<Map<String, dynamic>>> _phaseMaterials = {};
  final Set<int> _loadingPhaseMaterials = <int>{};

  @override
  void initState() {
    super.initState();
    AppTimeService.overrideNotifier.addListener(_onTestTimeChanged);
    _fetchProjectDetails();
  }

  @override
  void dispose() {
    AppTimeService.overrideNotifier.removeListener(_onTestTimeChanged);
    super.dispose();
  }

  void _onTestTimeChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _navigateToPage(String page) {
    switch (page) {
      case 'Dashboard':
        context.go('/supervisor');
        break;
      case 'Projects':
        context.go('/supervisor/projects');
        break;
      case 'Workers':
      case 'Worker Management':
        context.go('/supervisor/workers');
        break;
      case 'Attendance':
        context.go('/supervisor/attendance');
        break;
      case 'Reports':
        context.go('/supervisor/reports');
        break;
      case 'Inventory':
        context.go('/supervisor/inventory');
        break;
      case 'Settings':
        context.go('/supervisor/settings');
        break;
      default:
        return;
    }
  }

  Widget _buildBottomNavBar() {
    return SupervisorMobileBottomNav(
      activeTab: SupervisorMobileTab.projects,
      onSelect: _navigateToPage,
    );
  }

  String? _asNonEmptyString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is Map) {
      final map = value.cast<String, dynamic>();
      return _toInt(map['id'] ?? map['client_id']);
    }
    return int.tryParse(value.toString());
  }

  Map<String, dynamic>? _firstRecordFromResponse(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('results') && decoded['results'] is List) {
        final results = decoded['results'] as List<dynamic>;
        if (results.isNotEmpty && results.first is Map) {
          return Map<String, dynamic>.from(results.first as Map);
        }
      }
      return decoded;
    }

    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      return Map<String, dynamic>.from(decoded.first as Map);
    }

    return null;
  }

  Map<String, dynamic>? _extractProjectPayload(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) return null;

    final projectNode = decoded['project'];
    if (projectNode is Map<String, dynamic>) {
      return Map<String, dynamic>.from(projectNode);
    }

    final dataNode = decoded['data'];
    if (dataNode is Map<String, dynamic>) {
      return Map<String, dynamic>.from(dataNode);
    }

    return decoded;
  }

  String? _resolveMediaUrl(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();
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

    if (value.startsWith('/')) return origin.resolve(value).toString();
    if (value.startsWith('media/')) return origin.resolve('/$value').toString();
    if (value.startsWith('client_images/')) {
      return origin.resolve('/media/$value').toString();
    }

    return origin.resolve('/media/$value').toString();
  }

  int? _calculateDaysLeft() {
    if (_projectInfo == null || _projectInfo!['end_date'] == null) return null;
    try {
      final endDateStr = _projectInfo!['end_date'] as String;
      if (endDateStr.isEmpty) return null;
      final endDate = DateTime.parse(endDateStr);
      final now = AppTimeService.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = endDate.difference(today).inDays;
      return diff >= 0 ? diff : 0;
    } catch (_) {
      return null;
    }
  }

  double _calculateProjectProgress() {
    if (_phases == null || _phases!.isEmpty) return 0.0;

    int totalSubtasks = 0;
    int completedSubtasks = 0;

    for (final phase in _phases!) {
      final phaseMap = phase as Map<String, dynamic>;
      final List<dynamic> subtasks = phaseMap['subtasks'] ?? [];
      totalSubtasks += subtasks.length;
      for (final subtask in subtasks) {
        final subtaskMap = subtask as Map<String, dynamic>;
        if (subtaskMap['status'] == 'completed') completedSubtasks++;
      }
    }

    if (totalSubtasks == 0) return 0.0;
    return completedSubtasks / totalSubtasks;
  }

  Future<void> _fetchProjectDetails() async {
    try {
      final authUser = AuthService().currentUser;
      final userId = authUser?['user_id'];
      final authProjectId = authUser?['project_id'];
      final scopeSuffix = (userId != null) ? '&user_id=$userId' : '';

      final candidateProjectUrls = <String>[
        if (userId != null) 'projects/${widget.projectId}/?user_id=$userId',
        if (authProjectId != null)
          'projects/${widget.projectId}/?project_id=$authProjectId',
        'projects/${widget.projectId}/',
      ];

      http.Response? projectResponse;
      for (final url in candidateProjectUrls) {
        final response = await http.get(AppConfig.apiUri(url));
        if (response.statusCode == 200) {
          projectResponse = response;
          break;
        }
      }

      if (projectResponse == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Failed to load project details';
          _isLoading = false;
        });
        return;
      }

      final decodedProject = jsonDecode(projectResponse.body);
      if (decodedProject is! Map<String, dynamic>) {
        if (!mounted) return;
        setState(() {
          _error = 'Unexpected project details response';
          _isLoading = false;
        });
        return;
      }

      final projectData = decodedProject;
      final clientId = _toInt(projectData['client']);
      final embeddedClient = projectData['client'];
      Map<String, dynamic>? fallbackClientInfo;
      if (embeddedClient is Map<String, dynamic>) {
        fallbackClientInfo = Map<String, dynamic>.from(embeddedClient);
      } else {
        final fallbackFirstName = _asNonEmptyString(
          projectData['client_first_name'],
        );
        final fallbackLastName = _asNonEmptyString(
          projectData['client_last_name'],
        );
        final fallbackEmail = _asNonEmptyString(projectData['client_email']);
        final fallbackPhone = _asNonEmptyString(
          projectData['client_phone_number'],
        );
        final fallbackPhoto = _asNonEmptyString(projectData['client_photo']);
        final hasFallbackClient =
            fallbackFirstName != null ||
            fallbackLastName != null ||
            fallbackEmail != null ||
            fallbackPhone != null ||
            fallbackPhoto != null;

        if (hasFallbackClient) {
          fallbackClientInfo = {
            'client_id': clientId,
            'first_name': fallbackFirstName ?? '',
            'last_name': fallbackLastName ?? '',
            'email': fallbackEmail ?? 'N/A',
            'phone_number': fallbackPhone ?? 'N/A',
            'photo': fallbackPhoto,
          };
        }
      }

      final futures = await Future.wait<dynamic>([
        _fetchClientInfo(
          userId: userId,
          clientId: clientId,
          scopeSuffix: scopeSuffix,
        ),
        _fetchPhases(userId: userId),
        _fetchBackJobReviews(),
      ]);

      final resolvedClient = futures[0] as Map<String, dynamic>?;
      final resolvedPhases =
          (futures[1] as List<dynamic>?) ?? const <dynamic>[];
      var reviewRows = (futures[2] as List<dynamic>?) ?? const <dynamic>[];
      reviewRows = List<dynamic>.from(reviewRows);
      reviewRows.sort((a, b) {
        DateTime? parseCreated(dynamic x) {
          if (x is! Map) return null;
          return DateTime.tryParse('${x['created_at'] ?? ''}');
        }

        final da = parseCreated(a);
        final db = parseCreated(b);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

      if (!mounted) return;
      setState(() {
        _projectInfo = projectData;
        _clientInfo = resolvedClient ?? fallbackClientInfo;
        // Sort phases by createdAt (oldest first)
        resolvedPhases.sort((a, b) {
          final aCreated = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
          final bCreated = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
          int cmp = aCreated.compareTo(bCreated);
          if (cmp == 0) {
            return (a['phase_id'] ?? 0).compareTo(b['phase_id'] ?? 0);
          }
          return cmp;
        });
        _phases = resolvedPhases;
        _backJobReviews = reviewRows;
        _isLoading = false;
      });
      for (final p in resolvedPhases) {
        final pid = p['phase_id'];
        if (pid is int) unawaited(_fetchPhaseMaterials(pid));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error loading project details: $e';
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchClientInfo({
    required dynamic userId,
    required int? clientId,
    required String scopeSuffix,
  }) async {
    if (clientId != null) {
      final candidateClientUrls = <String>[
        if (userId != null) 'clients/$clientId/?user_id=$userId',
        'clients/$clientId/?project_id=${widget.projectId}',
        'clients/$clientId/',
      ];

      for (final url in candidateClientUrls) {
        try {
          final response = await http.get(AppConfig.apiUri(url));
          if (response.statusCode == 200) {
            final mapped = _firstRecordFromResponse(jsonDecode(response.body));
            if (mapped != null) {
              return mapped;
            }
          }
        } catch (_) {
          // Keep trying remaining candidate endpoints.
        }
      }
    }

    try {
      final listResponse = await http.get(
        AppConfig.apiUri('clients/?project_id=${widget.projectId}$scopeSuffix'),
      );
      if (listResponse.statusCode == 200) {
        return _firstRecordFromResponse(jsonDecode(listResponse.body));
      }
    } catch (_) {
      // Fall back to null.
    }

    return null;
  }

  Future<List<dynamic>> _fetchBackJobReviews() async {
    try {
      final r = await http.get(
        AppConfig.apiUri('back-job-reviews/?project_id=${widget.projectId}'),
      );
      if (r.statusCode != 200) return const <dynamic>[];
      final decoded = jsonDecode(r.body);
      if (decoded is List<dynamic>) return decoded;
      if (decoded is Map<String, dynamic>) {
        final inner =
            decoded['results'] ?? decoded['data'] ?? decoded['items'];
        if (inner is List<dynamic>) return inner;
      }
    } catch (_) {
      // same as other fetches: fail soft
    }
    return const <dynamic>[];
  }

  Future<List<dynamic>> _fetchPhases({required dynamic userId}) async {
    final phasesUrl = userId != null
        ? 'phases/?project_id=${widget.projectId}&user_id=$userId'
        : 'phases/?project_id=${widget.projectId}';

    try {
      final phasesResponse = await http.get(AppConfig.apiUri(phasesUrl));
      if (phasesResponse.statusCode != 200) return const <dynamic>[];
      final decoded = jsonDecode(phasesResponse.body);
      if (decoded is List) return decoded;
      if (decoded is Map<String, dynamic>) {
        if (decoded['results'] is List) {
          return decoded['results'] as List<dynamic>;
        }
        if (decoded['data'] is List) {
          return decoded['data'] as List<dynamic>;
        }
      }
    } catch (_) {
      // Fall back to empty list.
    }

    return const <dynamic>[];
  }

  /// Loads the per-phase planned-vs-actual material breakdown for the
  /// supervisor. Only quantities are consumed here — any cost / budget
  /// figures returned by the backend are intentionally ignored so the
  /// supervisor never sees money.
  Future<void> _fetchPhaseMaterials(int phaseId) async {
    if (_loadingPhaseMaterials.contains(phaseId)) return;
    _loadingPhaseMaterials.add(phaseId);
    try {
      final data = await BudgetService.getPlannedVsActual(phaseId: phaseId);
      if (!mounted) return;
      final raw = (data['items'] as List?) ?? const [];
      final materials = raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      setState(() {
        _phaseMaterials[phaseId] = materials;
      });
    } catch (_) {
      // Silent — the phase panel just won't render materials.
    } finally {
      _loadingPhaseMaterials.remove(phaseId);
    }
  }

  static int _asInt(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  /// Renders a compact panel inside each phase's expansion tile listing
  /// every material assigned to that phase, with planned / used / left
  /// quantities. No peso / budget info.
  Widget _buildPhaseMaterialsPanel(int phaseId) {
    final isLoading = _loadingPhaseMaterials.contains(phaseId);
    final materials = _phaseMaterials[phaseId];

    if (materials == null) {
      if (isLoading) {
        return const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text(
                'Loading materials…',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    if (materials.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Text(
            'No materials assigned to this phase yet.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF0C1935)),
                SizedBox(width: 6),
                Text(
                  'Materials for this phase',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Color(0xFF0C1935),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...materials.map((m) {
              final name = (m['inventory_item_name'] ?? 'Item').toString();
              final unit = ((m['unit_of_measure'] ?? 'pcs').toString().trim().isEmpty)
                  ? 'pcs'
                  : (m['unit_of_measure']).toString().trim();
              final assigned = _asInt(m['planned_quantity']);
              final used = _asInt(m['actual_quantity']);
              final remaining = _asInt(m['remaining_quantity']);
              final hasAssignment = m['has_plan'] != false;
              final isClosed = (m['plan_status']?.toString() ?? '') == 'closed';
              final leftover = _asInt(m['leftover_quantity']);

              final isDepleted = hasAssignment && remaining <= 0 && assigned > 0;
              final isOverUsed = hasAssignment && used > assigned;

              final Color pillBg;
              final Color pillFg;
              if (isClosed) {
                pillBg = const Color(0xFFE5E7EB);
                pillFg = const Color(0xFF374151);
              } else if (isOverUsed) {
                pillBg = const Color(0xFFFEE2E2);
                pillFg = const Color(0xFF991B1B);
              } else if (isDepleted) {
                pillBg = const Color(0xFFFEF3C7);
                pillFg = const Color(0xFF92400E);
              } else {
                pillBg = const Color(0xFFE0F2FE);
                pillFg = const Color(0xFF0C4A6E);
              }

              final String pillLabel;
              if (isClosed) {
                pillLabel = leftover > 0
                    ? 'Closed • $leftover $unit returned'
                    : 'Closed';
              } else if (hasAssignment) {
                pillLabel = '$remaining $unit remaining';
              } else {
                pillLabel = 'Not assigned';
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasAssignment
                                ? 'Assigned $assigned $unit  •  Used $used $unit'
                                : 'Used $used $unit (not assigned to this phase)',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        pillLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: pillFg,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar({
    required double radius,
    required String? photoUrl,
  }) {
    final url = (photoUrl ?? '').trim();
    if (url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[200],
        child: Icon(
          Icons.person_outline,
          color: Colors.grey[500],
          size: radius,
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: Image.network(
          url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.person_outline, color: Colors.grey[500], size: radius),
        ),
      ),
    );
  }

  Widget _buildProjectImage(String imagePath) {
    try {
      if (imagePath.startsWith('assets/')) {
        return Image.asset(
          imagePath,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }

      final resolvedUrl = _resolveMediaUrl(imagePath);
      if (resolvedUrl != null) {
        return Image.network(
          resolvedUrl,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }

      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }

      return _buildPlaceholder();
    } catch (_) {
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

  String _formatBackJobDate(dynamic raw) {
    final dt = DateTime.tryParse('${raw ?? ''}');
    if (dt == null) return '';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  Widget _buildClientBackJobSection({required bool isMobile}) {
    if (_backJobReviews.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Client feedback',
          style: TextStyle(
            fontSize: isMobile ? 20 : 23,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Notes from the client, including feedback tied to a project phase when applicable.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 12),
        ..._backJobReviews.map((raw) {
          final m = raw is Map
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{};
          final name = (m['client_name'] ?? 'Client').toString();
          final text = (m['review_text'] ?? '').toString();
          if (text.isEmpty) return const SizedBox.shrink();
          final phaseName = m['phase_name'] as String?;
          final hasPhase = phaseName != null && phaseName.isNotEmpty;
          final isResolved = m['is_resolved'] == true;
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0C1935),
                        ),
                      ),
                    ),
                    Text(
                      _formatBackJobDate(m['created_at']),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (hasPhase)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEFF2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      phaseName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEFF2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Project-wide',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isResolved
                        ? const Color(0xFFE5F8ED)
                        : const Color(0xFFFFF2E8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isResolved ? 'Resolved' : 'Open',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isResolved
                          ? const Color(0xFF10B981)
                          : const Color(0xFFFF6F00),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _clientCard({required bool isMobile}) {
    if (_clientInfo == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(child: Text('No client assigned')),
      );
    }

    final client = _clientInfo!;
    final fullName =
        '${client['first_name'] ?? ''} ${client['last_name'] ?? ''}'.trim();

    return Container(
      width: isMobile ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Client:',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildProfileAvatar(
                radius: 26,
                photoUrl: _resolveMediaUrl(client['photo']),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? 'N/A' : fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (client['email'] ?? 'N/A').toString(),
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    Text(
                      (client['phone_number'] ?? 'N/A').toString(),
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatSubtaskStatus(dynamic rawStatus) {
    final status = (rawStatus ?? '').toString().toLowerCase();
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'in_progress':
        return 'In Progress';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'Completed':
        return const Color(0xFF757575);
      case 'In Progress':
        return const Color(0xFFFF6F00);
      default:
        return Colors.grey.shade700;
    }
  }

  Color _statusBackgroundColor(String status) {
    switch (status) {
      case 'Completed':
        return const Color(0xFF757575).withOpacity(0.12);
      case 'In Progress':
        return const Color(0xFFFF6F00).withOpacity(0.12);
      default:
        return Colors.grey.shade200;
    }
  }

  int _phaseProgressPercent(Map<String, dynamic> phaseMap) {
    final subtasks = (phaseMap['subtasks'] as List<dynamic>? ?? []);
    if (subtasks.isEmpty) return 0;
    final completed = subtasks.where((subtask) {
      final map = subtask as Map<String, dynamic>;
      return (map['status'] ?? '').toString().toLowerCase() == 'completed';
    }).length;
    return ((completed / subtasks.length) * 100).round();
  }

  String _assignedWorkersLabel(dynamic assignedWorkersRaw) {
    final assignedWorkers = assignedWorkersRaw as List<dynamic>? ?? [];
    if (assignedWorkers.isEmpty) return 'No workers assigned';

    final names = assignedWorkers.map((worker) {
      final workerMap = worker as Map<String, dynamic>;
      final first = (workerMap['first_name'] ?? '').toString().trim();
      final last = (workerMap['last_name'] ?? '').toString().trim();
      final fullName = '$first $last'.trim();
      if (fullName.isNotEmpty) return fullName;
      return (workerMap['role'] ?? 'Worker').toString();
    }).toList();

    return 'Workers: ${names.join(', ')}';
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: InteractiveViewer(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child:
                            Icon(Icons.broken_image, color: Colors.white, size: 50),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHistoryModal(BuildContext context, Map<String, dynamic> subtaskMap) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Update History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final updatePhotos =
                            (subtaskMap['update_photos'] as List<dynamic>? ??
                                []);
                        final Map<String, List<Map<String, dynamic>>>
                        groupedUpdates = {};

                        for (final photoItemRaw in updatePhotos) {
                          final photoItem = photoItemRaw as Map<String, dynamic>;
                          final rawDate = photoItem['created_at'] as String?;
                          DateTime? dt;
                          if (rawDate != null) dt = DateTime.tryParse(rawDate);

                          String dateStr = '';
                          String timeStr = '';
                          if (dt != null) {
                            final localDt = dt.toLocal();
                            dateStr =
                                '${localDt.day}/${localDt.month}/${localDt.year}';
                            String hour = localDt.hour > 12
                                ? '${localDt.hour - 12}'
                                : '${localDt.hour}';
                            if (hour == '0') hour = '12';
                            final minute =
                                localDt.minute.toString().padLeft(2, '0');
                            final ampm = localDt.hour >= 12 ? 'PM' : 'AM';
                            timeStr = '$hour:$minute $ampm';
                          }

                          final key = dateStr.isNotEmpty
                              ? '$dateStr at $timeStr'
                              : 'Unknown Date';
                          groupedUpdates
                              .putIfAbsent(key, () => [])
                              .add(photoItem);
                        }

                        final updatedAtStr =
                            subtaskMap['updated_at'] as String?;
                        final updatedAt = updatedAtStr != null
                            ? DateTime.tryParse(updatedAtStr)
                            : null;

                        if (updatedAt != null) {
                          final localDt = updatedAt.toLocal();
                          final dateStr =
                              '${localDt.day}/${localDt.month}/${localDt.year}';
                          String hour = localDt.hour > 12
                              ? '${localDt.hour - 12}'
                              : '${localDt.hour}';
                          if (hour == '0') hour = '12';
                          final minute =
                              localDt.minute.toString().padLeft(2, '0');
                          final ampm = localDt.hour >= 12 ? 'PM' : 'AM';
                          final timeStr = '$hour:$minute $ampm';
                          final key = '$dateStr at $timeStr';

                          if (!groupedUpdates.containsKey(key)) {
                            final newMap = <String,
                                List<Map<String, dynamic>>>{};
                            newMap[key] = [];
                            newMap.addAll(groupedUpdates);
                            groupedUpdates.clear();
                            groupedUpdates.addAll(newMap);
                          }
                        }

                        if (groupedUpdates.isEmpty) {
                          return const Center(
                            child: Text(
                              'No history available.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        // Convert to list to sort by key (newest first)
                        final sortedKeys = groupedUpdates.keys.toList();
                        // Assuming keys are like "D/M/Y at H:M AM/PM", simple string sort might not work.
                        // But usually the backend returns them in a decent order or we can parse them.
                        // For now, let's keep the order they were added.

                        return ListView.separated(
                          itemCount: sortedKeys.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final key = sortedKeys[index];
                            final photos = groupedUpdates[key]!;

                            String? notes;
                            for (final p in photos) {
                              if (p['progress_notes'] != null &&
                                  p['progress_notes'].toString().isNotEmpty) {
                                notes = p['progress_notes'].toString();
                                break;
                              }
                            }

                            // Fallback for the very latest update notes if not in photo metadata
                            if (notes == null &&
                                index == 0 &&
                                (subtaskMap['progress_notes'] ?? '')
                                    .toString()
                                    .isNotEmpty) {
                              notes = subtaskMap['progress_notes'].toString();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                ),
                                if (notes != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Notes: $notes',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                                if (photos.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: photos.map((photoItem) {
                                      final photoPath =
                                          photoItem['photo'] as String?;
                                      if (photoPath == null)
                                        return const SizedBox.shrink();
                                      final photoUrl =
                                          _resolveMediaUrl(photoPath) ?? '';

                                      return GestureDetector(
                                        onTap: () =>
                                            _showFullImage(context, photoUrl),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(7),
                                            child: Image.network(
                                              photoUrl,
                                              height: 80,
                                              width: 80,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                height: 80,
                                                width: 80,
                                                color: Colors.grey[200],
                                                child: const Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int? _resolvedFocusPhaseId() {
    if (_phases == null) return null;
    if (widget.focusSubtaskId != null) {
      for (final p in _phases!) {
        final pm = p as Map<String, dynamic>;
        for (final s in (pm['subtasks'] as List<dynamic>? ?? const [])) {
          final sm = s as Map<String, dynamic>;
          final sid = sm['subtask_id'];
          int? si;
          if (sid is int) {
            si = sid;
          } else if (sid is num) {
            si = sid.toInt();
          } else {
            si = int.tryParse(sid?.toString() ?? '');
          }
          if (si == widget.focusSubtaskId) {
            final phid = pm['phase_id'];
            if (phid is int) return phid;
            if (phid is num) return phid.toInt();
            return int.tryParse(phid?.toString() ?? '');
          }
        }
      }
    }
    return widget.focusPhaseId;
  }

  int? _asIntId(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  Widget _buildTasksToDoSection() {
    if (_phases == null || _phases!.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Text(
          'No tasks available yet for this project.',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
      );
    }

    final focusForExpand = _resolvedFocusPhaseId();

    return Column(
      children: _phases!.map((phase) {
        final phaseMap = phase as Map<String, dynamic>;
        final phaseName = (phaseMap['phase_name'] ?? 'Untitled Phase')
            .toString();
        final subtasks = (phaseMap['subtasks'] as List<dynamic>? ?? []);
        final progress = _phaseProgressPercent(phaseMap);
        final phaseId = _asIntId(phaseMap['phase_id']);
        final expandPhase =
            focusForExpand != null && phaseId != null && focusForExpand == phaseId;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Card(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 2,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              initiallyExpanded: expandPhase,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          phaseName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: progress / 100,
                          color: const Color(0xFFFF6F00),
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '$progress%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: subtasks.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Text(
                            'No subtasks yet in this phase.',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                        )
                      : Column(
                          children: subtasks.map((subtask) {
                            final subtaskMap = subtask as Map<String, dynamic>;
                            final title =
                                (subtaskMap['title'] ?? 'Untitled Subtask')
                                    .toString();
                            final status = _formatSubtaskStatus(
                              subtaskMap['status'],
                            );
                            final stId = _asIntId(subtaskMap['subtask_id']);
                            final highlightInbox = widget.focusSubtaskId != null &&
                                stId == widget.focusSubtaskId;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Card(
                                color: Colors.white,
                                surfaceTintColor: Colors.transparent,
                                margin: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: highlightInbox
                                      ? const BorderSide(
                                          color: Color(0xFFFF6F00),
                                          width: 2,
                                        )
                                      : BorderSide.none,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _statusBackgroundColor(
                                                status,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                color: _statusTextColor(status),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey[200]!,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.person_outline,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _assignedWorkersLabel(
                                                  subtaskMap['assigned_workers'],
                                                ),
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if ((subtaskMap['progress_notes'] ?? '')
                                          .toString()
                                          .trim()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Notes: ${(subtaskMap['progress_notes']).toString().trim()}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                      Builder(
                                        builder: (context) {
                                          final updatePhotos = (subtaskMap['update_photos']
                                                  as List<dynamic>? ??
                                              []);
                                          final updatedAtStr =
                                              subtaskMap['updated_at'] as String?;
                                          final updatedAt = updatedAtStr != null
                                              ? DateTime.tryParse(updatedAtStr)
                                              : null;

                                          List<Map<String, dynamic>>
                                          latestUpdatePhotos = [];
                                          if (updatePhotos.isNotEmpty &&
                                              updatedAt != null) {
                                            final firstPhotoRaw =
                                                updatePhotos.first['created_at']
                                                    as String?;
                                            final firstPhotoDt = firstPhotoRaw !=
                                                    null
                                                ? DateTime.tryParse(firstPhotoRaw)
                                                : null;

                                            if (firstPhotoDt != null) {
                                              final diff = updatedAt
                                                  .difference(firstPhotoDt)
                                                  .inMinutes
                                                  .abs();
                                              // Increased threshold slightly for batch updates
                                              if (diff < 5) {
                                                String? getGroupKey(DateTime? dt) {
                                                  if (dt == null) return null;
                                                  final localDt = dt.toLocal();
                                                  final dateStr =
                                                      '${localDt.day}/${localDt.month}/${localDt.year}';
                                                  String hour = localDt.hour > 12
                                                      ? '${localDt.hour - 12}'
                                                      : '${localDt.hour}';
                                                  if (hour == '0') hour = '12';
                                                  final minute = localDt.minute
                                                      .toString()
                                                      .padLeft(2, '0');
                                                  final ampm = localDt.hour >= 12
                                                      ? 'PM'
                                                      : 'AM';
                                                  return '$dateStr at $hour:$minute $ampm';
                                                }

                                                final firstKey =
                                                    getGroupKey(firstPhotoDt);
                                                latestUpdatePhotos = updatePhotos
                                                    .where((p) {
                                                  final pRaw =
                                                      p['created_at'] as String?;
                                                  final pDt = pRaw != null
                                                      ? DateTime.tryParse(pRaw)
                                                      : null;
                                                  return getGroupKey(pDt) ==
                                                      firstKey;
                                                })
                                                    .map((e) => Map<String, dynamic>.from(e))
                                                    .toList();
                                              }
                                            }
                                          }

                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (latestUpdatePhotos.isNotEmpty) ...[
                                                const SizedBox(height: 12),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: latestUpdatePhotos
                                                      .map((photoItem) {
                                                    final photoPath =
                                                        photoItem['photo']
                                                            as String?;
                                                    if (photoPath == null)
                                                      return const SizedBox
                                                          .shrink();
                                                    final photoUrl =
                                                        _resolveMediaUrl(
                                                                photoPath) ??
                                                            '';

                                                    return GestureDetector(
                                                      onTap: () => _showFullImage(
                                                          context, photoUrl),
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          border: Border.all(
                                                              color: Colors
                                                                  .grey[300]!),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  8),
                                                        ),
                                                        child: ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  7),
                                                          child: Image.network(
                                                            photoUrl,
                                                            height: 100,
                                                            width: 100,
                                                            fit: BoxFit.cover,
                                                            errorBuilder:
                                                                (_, __, ___) =>
                                                                    Container(
                                                              height: 100,
                                                              width: 100,
                                                              color:
                                                                  Colors.grey[200],
                                                              child: const Icon(
                                                                  Icons
                                                                      .broken_image,
                                                                  color: Colors
                                                                      .grey),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                              const SizedBox(height: 8),
                                              Align(
                                                alignment: Alignment.centerRight,
                                                child: TextButton.icon(
                                                  onPressed: () =>
                                                      _showHistoryModal(
                                                          context, subtaskMap),
                                                  icon: const Icon(Icons.history,
                                                      size: 16,
                                                      color: Color(0xFFFF7A18)),
                                                  label: const Text(
                                                    'History',
                                                    style: TextStyle(
                                                        color: Color(0xFFFF7A18),
                                                        fontSize: 13),
                                                  ),
                                                  style: TextButton.styleFrom(
                                                    padding: EdgeInsets.zero,
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
                if (phaseMap['phase_id'] is int)
                  _buildPhaseMaterialsPanel(phaseMap['phase_id'] as int),
                _buildRecordUsageAction(phaseMap),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecordUsageAction(Map<String, dynamic> phaseMap) {
    final phaseId = phaseMap['phase_id'] as int?;
    if (phaseId == null) return const SizedBox.shrink();

    final supervisorId = AuthService().currentUser?['user_id'] as int?;
    final phaseStatus = (phaseMap['status'] ?? '').toString().toLowerCase();
    final isCompleted = phaseStatus == 'completed';

    if (isCompleted) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: Color(0xFF374151)),
                  SizedBox(width: 6),
                  Text(
                    'Phase completed — usage locked',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: supervisorId == null
                ? null
                : () async {
                    final recorded = await showDialog<bool>(
                      context: context,
                      builder: (_) => RecordUsageModal(
                        phaseId: phaseId,
                        phaseName:
                            (phaseMap['phase_name'] ?? '') as String,
                        supervisorId: supervisorId,
                      ),
                    );
                    if (recorded == true && mounted) {
                      await _fetchPhaseMaterials(phaseId);
                      if (mounted) setState(() {});
                    }
                  },
            icon: const Icon(Icons.inventory_2_outlined, size: 16),
            label: const Text('Record material usage'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isMobile = screenWidth < 768;

    final daysLeft = _calculateDaysLeft();
    final projectDescription =
        _asNonEmptyString(_projectInfo?['description']) ??
        _asNonEmptyString(_projectInfo?['project_description']) ??
        _asNonEmptyString(_projectInfo?['details']);
    final projectBannerImage =
        _asNonEmptyString(_projectInfo?['project_image']) ??
        widget.projectImage;

    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text('Error: $_error'))
        : SingleChildScrollView(
            padding: EdgeInsets.only(
              left: isMobile ? 16 : 24,
              right: isMobile ? 16 : 24,
              top: isMobile ? 16 : 24,
              bottom: isMobile ? 100 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (daysLeft != null && _showDaysLeftReminder)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 18,
                    ),
                    decoration: BoxDecoration(
                      color: daysLeft <= 3
                          ? const Color(0xFFFFE0B2)
                          : const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.hourglass_bottom,
                          color: daysLeft <= 3
                              ? const Color(0xFFFF9800)
                              : const Color(0xFF2196F3),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            daysLeft == 0
                                ? 'Today is the expected end date for this project'
                                : daysLeft == 1
                                ? '1 day left before the expected end date.'
                                : '$daysLeft days left before the expected end date.',
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showDaysLeftReminder = false;
                            });
                          },
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      color: const Color(0xFF0C1935),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildProjectImage(projectBannerImage),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.projectTitle,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.projectLocation,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                if (projectDescription != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    projectDescription,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
                const SizedBox(height: 25),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(_calculateProjectProgress() * 100).round()}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[400],
                    ),
                  ),
                ),
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
                if (isMobile)
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _projectDetailCard(
                              icon: Icons.calendar_today,
                              title: 'Duration',
                              value: _projectInfo != null
                                  ? '${_projectInfo!['duration_days'] ?? 'N/A'} days'
                                  : 'N/A',
                              color: const Color(0xFF2196F3),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _projectDetailCard(
                              icon: Icons.hourglass_bottom,
                              title: 'Days Left',
                              value: _calculateDaysLeft() != null
                                  ? '${_calculateDaysLeft()} days'
                                  : 'N/A',
                              color: const Color(0xFFFF9800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _projectDetailCard(
                              icon: Icons.event_available,
                              title: 'Expected Date to End',
                              value: (_projectInfo?['end_date'] ?? 'N/A').toString(),
                              color: const Color(0xFFF44336),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _projectDetailCard(
                              icon: Icons.attach_money,
                              title: 'Budget',
                              value: widget.budget ?? 'N/A',
                              color: const Color(0xFF9C27B0),
                            ),
                          ),
                        ],
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
                              : 'N/A',
                          color: const Color(0xFF2196F3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _projectDetailCard(
                          icon: Icons.hourglass_bottom,
                          title: 'Days Left',
                          value: _calculateDaysLeft() != null
                              ? '${_calculateDaysLeft()} days'
                              : 'N/A',
                          color: const Color(0xFFFF9800),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _projectDetailCard(
                          icon: Icons.event,
                          title: 'Start Date',
                          value: (_projectInfo?['start_date'] ?? 'N/A')
                              .toString(),
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _projectDetailCard(
                          icon: Icons.event_available,
                          title: 'Expected Date to End',
                          value: (_projectInfo?['end_date'] ?? 'N/A')
                              .toString(),
                          color: const Color(0xFFF44336),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _projectDetailCard(
                          icon: Icons.attach_money,
                          title: 'Budget',
                          value: widget.budget ?? 'N/A',
                          color: const Color(0xFF9C27B0),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AllWorkforcePage(
                            projectId: widget.projectId,
                            projectTitle: widget.projectTitle,
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF6F00),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'View Workforce',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _clientCard(isMobile: isMobile),
                const SizedBox(height: 20),
                _buildClientBackJobSection(isMobile: isMobile),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tasks to Do',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6F00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TaskProgressPage(
                              initialSidebarVisible: false,
                              projectId: widget.projectId,
                            ),
                          ),
                        );
                      },
                      child: const Text('Manage'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTasksToDoSection(),
                const SizedBox(height: 32),
              ],
            ),
          );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          if (isDesktop)
            const Sidebar(activePage: 'Projects', keepVisible: true),
          Expanded(
            child: Column(
              children: [
                DashboardHeader(onMenuPressed: () {}, title: 'Projects'),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildBottomNavBar() : null,
    );
  }
}
