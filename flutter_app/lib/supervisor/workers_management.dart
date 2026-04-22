import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:qr_flutter/qr_flutter.dart';
import '../services/auth_service.dart';
import '../services/app_config.dart';
import '../services/file_download/file_download.dart';
import '../services/app_theme_tokens.dart';
import '../services/inventory_service.dart';
import 'widgets/sidebar.dart';
import 'widgets/mobile_bottom_nav.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/supervisor_user_badge.dart';

class WorkerManagementPage extends StatefulWidget {
  final bool initialSidebarVisible;

  const WorkerManagementPage({super.key, this.initialSidebarVisible = false});

  @override
  State<WorkerManagementPage> createState() => _WorkerManagementPageState();
}

class _WorkerManagementPageState extends State<WorkerManagementPage> {
  static const Duration _projectNamesCacheTtl = Duration(minutes: 3);

  late Future<List<Map<String, dynamic>>> _workersFuture;
  Map<int, String> _projectNamesById = {};
  int? _projectNamesSupervisorId;
  DateTime? _projectNamesCachedAt;
  Future<void>? _projectNamesInFlight;

  @override
  void initState() {
    super.initState();
    _workersFuture = _fetchFieldWorkers();
  }

  Future<List<Map<String, dynamic>>> _fetchFieldWorkers({int? projectId}) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser ?? <String, dynamic>{};
      final userId = _toInt(currentUser['user_id']);
      final userProjectId = _toInt(currentUser['project_id']);
      final typeOrRole = (currentUser['type'] ?? currentUser['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      // Some sessions only keep `user_id` for supervisors. Fall back to it.
      final supervisorId =
          _toInt(currentUser['supervisor_id']) ??
          ((typeOrRole == 'supervisor') ? userId : null);

      // Keep worker loading responsive: project name map can refresh in background.
      unawaited(_ensureProjectNamesLoaded(supervisorId: supervisorId));

        // In supervisor worker management, null means "All Projects".
        // Only fall back to user project for non-supervisor contexts.
        final effectiveProjectId =
          supervisorId != null ? projectId : (projectId ?? userProjectId);
      final url = supervisorId != null
          ? (effectiveProjectId != null
                ? AppConfig.apiUri(
                    'field-workers/?supervisor_id=$supervisorId&project_id=$effectiveProjectId',
                  )
                : AppConfig.apiUri('field-workers/?supervisor_id=$supervisorId'))
          : (effectiveProjectId != null
                ? AppConfig.apiUri('field-workers/?project_id=$effectiveProjectId')
                : AppConfig.apiUri('field-workers/'));

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final workers = _extractWorkers(decoded);

        // Some backends restrict supervisors to project-scoped data even when no
        // query param is provided. Fallback prevents empty table in that case.
        if (workers.isEmpty && effectiveProjectId != null) {
          final fallbackUrl = AppConfig.apiUri(
            'field-workers/?project_id=$effectiveProjectId',
          );
          final fallbackResponse = await http.get(fallbackUrl);

          if (fallbackResponse.statusCode == 200) {
            final fallbackDecoded = jsonDecode(fallbackResponse.body);
            final fallbackWorkers = _extractWorkers(fallbackDecoded);
            return fallbackWorkers;
          }
        }

        return workers;
      } else {
        return [];
      }
    } catch (_) {
      return [];
    }
  }

    /// Detail routes must pass the same `supervisor_id` / `project_id` (or
  /// `user_id` for PM) as the list call; otherwise [FieldWorkerViewSet]
  /// returns an empty queryset and PATCH responds 404.
  Uri _fieldWorkerDetailUri(int fieldWorkerId) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser ?? <String, dynamic>{};
    final userId = _toInt(currentUser['user_id']);
    final userProjectId = _toInt(currentUser['project_id']);
    final typeOrRole = (currentUser['type'] ?? currentUser['role'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final supervisorId =
        _toInt(currentUser['supervisor_id']) ??
        ((typeOrRole == 'supervisor') ? userId : null);

    final effectiveProjectId = supervisorId != null
        ? selectedProjectId
        : (selectedProjectId ?? userProjectId);

    if (supervisorId != null) {
      if (effectiveProjectId != null) {
        return AppConfig.apiUri(
          'field-workers/$fieldWorkerId/?supervisor_id=$supervisorId&project_id=$effectiveProjectId',
        );
      }
      return AppConfig.apiUri(
        'field-workers/$fieldWorkerId/?supervisor_id=$supervisorId',
      );
    }
    if (effectiveProjectId != null) {
      return AppConfig.apiUri(
        'field-workers/$fieldWorkerId/?project_id=$effectiveProjectId',
      );
    }
    if (userId != null) {
      return AppConfig.apiUri('field-workers/$fieldWorkerId/?user_id=$userId');
    }
    return AppConfig.apiUri('field-workers/$fieldWorkerId/');
  }

  Future<void> _ensureProjectNamesLoaded({dynamic supervisorId}) async {
    final resolvedSupervisorId = _toInt(supervisorId);

    if (resolvedSupervisorId == null) {
      if (!mounted) return;
      if (_projectNamesById.isEmpty) return;
      setState(() {
        _projectNamesById = {};
      });
      _projectNamesSupervisorId = null;
      _projectNamesCachedAt = DateTime.now();
      return;
    }

    final now = DateTime.now();
    final hasFreshCache =
        _projectNamesSupervisorId == resolvedSupervisorId &&
        _projectNamesCachedAt != null &&
        now.difference(_projectNamesCachedAt!) <= _projectNamesCacheTtl;
    if (hasFreshCache) {
      return;
    }

    if (_projectNamesInFlight != null &&
        _projectNamesSupervisorId == resolvedSupervisorId) {
      await _projectNamesInFlight;
      return;
    }

    _projectNamesSupervisorId = resolvedSupervisorId;
    final future = _fetchProjects(supervisorId: resolvedSupervisorId);
    _projectNamesInFlight = future;
    try {
      await future;
      _projectNamesCachedAt = DateTime.now();
    } finally {
      if (identical(_projectNamesInFlight, future)) {
        _projectNamesInFlight = null;
      }
    }
  }

  Future<void> _fetchProjects({dynamic supervisorId}) async {
    try {
      if (supervisorId == null) {
        if (!mounted) return;
        setState(() {
          _projectNamesById = {};
        });
        return;
      }

      final Uri url = AppConfig.apiUri('projects/?supervisor_id=$supervisorId');

      final response = await http.get(url);

      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      final projects = _extractWorkers(decoded);
      final mapped = <int, String>{};

      for (final project in projects) {
        final id = _toInt(project['project_id']);
        final name = (project['project_name'] ?? '').toString().trim();
        if (id != null && name.isNotEmpty) {
          mapped[id] = name;
        }
      }

      if (!mounted) return;
      setState(() {
        _projectNamesById = mapped;
      });
    } catch (_) {
      // Keep existing fallback behavior.
    }
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// The backend serializer returns the deduction under
  /// `damages_deduction_per_salary`. The UI sometimes mirrors it to
  /// `damages_deduction` after a save. Read both so the summary is accurate
  /// whether the worker came from the API or from a fresh save.
  String _damageDeductionDisplay(Map<String, dynamic> worker) {
    final raw = worker['damages_deduction_per_salary'] ??
        worker['damages_deduction'];
    if (raw == null) return '';
    final s = raw.toString().trim();
    return s;
  }

  /// Only treat a worker as having a saved damage report when there is at
  /// least a damaged item recorded AND either a price or a deduction.
  /// This avoids showing the "View Existing Damage Summary" button when the
  /// backend returns partial / empty strings.
  bool _hasSavedDamageReport(Map<String, dynamic> worker) {
    final item = (worker['damages_item'] ?? '').toString().trim();
    if (item.isEmpty) return false;

    final priceStr = (worker['damages_price'] ?? '').toString().trim();
    final price = double.tryParse(priceStr) ?? 0.0;

    final deductionStr = _damageDeductionDisplay(worker);
    final deduction = double.tryParse(deductionStr) ?? 0.0;

    return price > 0 || deduction > 0;
  }

  List<Map<String, dynamic>> _extractWorkers(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (decoded is Map<String, dynamic>) {
      final results = decoded['results'];
      if (results is List) {
        return results
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    return [];
  }

  bool _isWorkerActive(Map<String, dynamic> worker) {
    final status = (worker['status'] ?? '').toString().trim().toLowerCase();
    final isActiveFlag = worker['is_active'];

    if (isActiveFlag is bool) {
      return isActiveFlag;
    }

    if (isActiveFlag is num) {
      return isActiveFlag != 0;
    }

    if (isActiveFlag is String) {
      final normalized = isActiveFlag.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }

    if (status.isNotEmpty) {
      const inactiveValues = {'inactive', 'disabled', 'terminated', 'archived'};
      return !inactiveValues.contains(status);
    }

    // Backward compatibility: if API does not expose status yet, treat as active.
    return true;
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
        return; // Already on workers page
      case 'Attendance':
        context.go('/supervisor/attendance');
        break;
      case 'Reports':
        context.go('/supervisor/reports');
        break;
      case 'Inventory':
        context.go('/supervisor/inventory');
        break;
      default:
        return;
    }
  }

  String searchQuery = '';
  int? selectedProjectId;
  String selectedRole = 'All';
  String sortBy = 'Name A-Z';

  final List<String> roles = [
    'All',
    'Mason',
    'Painter',
    'Electrician',
    'Carpenter',
  ];
  final List<String> sortOptions = ['Name A-Z', 'Name Z-A', 'Recently Hired'];

  List<MapEntry<int?, String>> _getProjectFilterOptions() {
    final entries = _projectNamesById.entries.toList()
      ..sort(
        (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
      );

    return [
      const MapEntry<int?, String>(null, 'All Projects'),
      ...entries.map((entry) => MapEntry<int?, String>(entry.key, entry.value)),
    ];
  }

  List<Map<String, dynamic>> _filterAndSortWorkers(
    List<Map<String, dynamic>> allWorkers,
  ) {
    final filtered = allWorkers.where((worker) {
      final fullName = '${worker['first_name']} ${worker['last_name']}'
          .toLowerCase();
      final role = (worker['role'] ?? '').toString().toLowerCase();
      final projectNames = _getWorkerProjectNames(worker);
      final projectIds = _getWorkerProjectIds(worker);
      final projectSearchText = projectNames.join(' ').toLowerCase();
      final query = searchQuery.toLowerCase();
      final matchesSearch =
          fullName.contains(query) ||
          role.contains(query) ||
          projectSearchText.contains(query);
      final matchesRole =
          selectedRole == 'All' || worker['role'] == selectedRole;
      final matchesProject =
          selectedProjectId == null || projectIds.contains(selectedProjectId);
      return matchesSearch && matchesRole && matchesProject;
    }).toList();

    if (sortBy == 'Name A-Z') {
      filtered.sort((a, b) {
        final nameA = '${a['first_name']} ${a['last_name']}';
        final nameB = '${b['first_name']} ${b['last_name']}';
        return nameA.compareTo(nameB);
      });
    } else if (sortBy == 'Name Z-A') {
      filtered.sort((a, b) {
        final nameA = '${a['first_name']} ${a['last_name']}';
        final nameB = '${b['first_name']} ${b['last_name']}';
        return nameB.compareTo(nameA);
      });
    } else if (sortBy == 'Recently Hired') {
      filtered.sort((a, b) {
        final dateA = a['created_at'] ?? '';
        final dateB = b['created_at'] ?? '';
        return dateB.compareTo(dateA);
      });
    }
    return filtered;
  }

  Set<int> _getWorkerProjectIds(Map<String, dynamic> worker) {
    final ids = <int>{};

    final directProjectId = _toInt(worker['project_id']);
    if (directProjectId != null) ids.add(directProjectId);

    final project = worker['project'];
    if (project is Map<String, dynamic>) {
      final nestedId = _toInt(project['project_id'] ?? project['id']);
      if (nestedId != null) ids.add(nestedId);
    }

    final assignedProjects = worker['assigned_projects'];
    if (assignedProjects is List) {
      for (final item in assignedProjects) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final id = _toInt(map['project_id'] ?? map['id']);
          if (id != null) ids.add(id);
        }
      }
    }

    return ids;
  }

  void _onProjectFilterChanged(int? projectId) {
    setState(() {
      selectedProjectId = projectId;
      _workersFuture = _fetchFieldWorkers(projectId: projectId);
    });
  }

  Color getStatusColor(String status) {
    // Field workers don't have status in DB, default to Active
    return Colors.green;
  }

  String _getWorkerName(Map<String, dynamic> worker) {
    final firstName = worker['first_name'] ?? '';
    final lastName = worker['last_name'] ?? '';
    return '$firstName $lastName'.trim();
  }

  String _getWorkerInitial(Map<String, dynamic> worker) {
    final name = _getWorkerName(worker);
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  String? _resolveWorkerPhotoUrl(Map<String, dynamic> worker) {
    final photo = worker['photo'];
    if (photo == null) return null;

    final raw = photo.toString().trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    final api = Uri.parse(AppConfig.apiBaseUrl);
    final hostBase = '${api.scheme}://${api.authority}';

    if (raw.startsWith('/')) {
      return '$hostBase$raw';
    }

    if (raw.startsWith('media/')) {
      return '$hostBase/$raw';
    }

    if (raw.startsWith('fieldworker_images/')) {
      return '$hostBase/media/$raw';
    }

    return '$hostBase/media/$raw';
  }

  Widget _buildWorkerAvatar(
    Map<String, dynamic> worker, {
    required double radius,
    required Color roleColor,
    required double fontSize,
  }) {
    final photoUrl = _resolveWorkerPhotoUrl(worker);

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      foregroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
      child: Text(
        _getWorkerInitial(worker),
        style: TextStyle(
          color: roleColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatPayrate(dynamic payrate) {
    if (payrate == null) return 'Not set';
    return '₱${payrate}/hr';
  }

  String _formatShiftSchedule(dynamic shiftSchedule) {
    if (shiftSchedule == null) return 'Not set';
    final schedule = shiftSchedule.toString().trim();
    if (schedule.isEmpty) return 'Not set';
    return schedule;
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return 'Not set';
    final parsed = double.tryParse(value.toString());
    if (parsed == null) return 'Not set';
    return '₱${parsed.toStringAsFixed(2)}';
  }

  String _formatDeductionWithFallback(dynamic totalValue, dynamic minValue) {
    if (totalValue != null) return _formatCurrency(totalValue);
    if (minValue != null) return '${_formatCurrency(minValue)} (minimum)';
    return 'Not set';
  }

  List<String> _getWorkerProjectNames(Map<String, dynamic> worker) {
    final names = <String>{};

    final assignedProjects = worker['assigned_projects'];
    if (assignedProjects is List) {
      for (final project in assignedProjects) {
        if (project is Map) {
          final map = Map<String, dynamic>.from(project);
          final name = (map['project_name'] ?? map['name'] ?? '')
              .toString()
              .trim();
          if (name.isNotEmpty) {
            names.add(name);
          }
          final id = _toInt(map['project_id'] ?? map['id']);
          if (id != null && _projectNamesById.containsKey(id)) {
            names.add(_projectNamesById[id]!);
          }
        }
      }
    }

    final directProjectName = worker['project_name'];
    if (directProjectName != null &&
        directProjectName.toString().trim().isNotEmpty) {
      names.add(directProjectName.toString().trim());
    }

    final directProjectId = _toInt(worker['project_id']);
    if (directProjectId != null &&
        _projectNamesById.containsKey(directProjectId)) {
      names.add(_projectNamesById[directProjectId]!);
    }

    final project = worker['project'];
    if (project is Map<String, dynamic>) {
      final nestedId = _toInt(project['project_id'] ?? project['id']);
      if (nestedId != null && _projectNamesById.containsKey(nestedId)) {
        names.add(_projectNamesById[nestedId]!);
      }

      final nestedName = project['name'] ?? project['project_name'];
      if (nestedName != null && nestedName.toString().trim().isNotEmpty) {
        names.add(nestedName.toString().trim());
      }
    }

    if (names.isEmpty) {
      return const ['Unassigned'];
    }
    final sorted = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  String _getProjectName(Map<String, dynamic> worker) {
    final names = _getWorkerProjectNames(worker);
    if (names.isEmpty) return 'Unassigned';
    return names.join(', ');
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Painter':
        return const Color(0xFFFF6F00);
      case 'Electrician':
        return const Color(0xFF9E9E9E);
      case 'Plumber':
        return const Color(0xFF757575);
      case 'Carpenter':
        return const Color(0xFFFF8F00);
      default:
        return Colors.blueGrey;
    }
  }

  // ---------------------------
  // Worker detail modal (keeps previous functionality)
  // ---------------------------
  void _showWorkerDetailModal(
    BuildContext context,
    Map<String, dynamic> worker,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final roleColor = _roleColor(worker["role"]);
        final workerName = _getWorkerName(worker);
        final workerPhotoUrl = _resolveWorkerPhotoUrl(worker);
        final phoneNumber = worker['phone_number'] ?? 'N/A';
        final birthdate = _formatDate(worker['birthdate']);
        final payrate = _formatPayrate(worker['payrate']);
        final shiftSchedule = _formatShiftSchedule(worker['shift_schedule']);
        final dateHired = _formatDate(worker['created_at']);
        final sssDeduction = _formatDeductionWithFallback(
          worker['sss_weekly_total'],
          worker['sss_weekly_min'],
        );
        final philhealthDeduction = _formatDeductionWithFallback(
          worker['philhealth_weekly_total'],
          worker['philhealth_weekly_min'],
        );
        final pagibigDeduction = _formatDeductionWithFallback(
          worker['pagibig_weekly_total'],
          worker['pagibig_weekly_min'],
        );
        final weeklySalary = _formatCurrency(worker['weekly_salary']);
        final totalWeeklyDeduction = _formatCurrency(
          worker['total_weekly_deduction'],
        );
        final netWeeklyPay = _formatCurrency(worker['net_weekly_pay']);
        final fieldWorkerId = (worker['fieldworker_id'] as num?)?.toInt();

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with role accent
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 48,
                              decoration: BoxDecoration(
                                color: roleColor.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              "Worker Profile",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Profile
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: workerPhotoUrl == null
                                ? Icon(Icons.person, size: 56, color: roleColor)
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.network(
                                      workerPhotoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Icon(
                                              Icons.person,
                                              size: 56,
                                              color: roleColor,
                                            );
                                          },
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            workerName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              worker["role"] ?? 'Worker',
                              style: TextStyle(
                                color: roleColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Details
                    const Text(
                      "Personal Information",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow("Phone", phoneNumber),
                    _buildDetailRow("Birthdate", birthdate),
                    _buildDetailRow("SSS Deduction (Weekly)", sssDeduction),
                    _buildDetailRow(
                      "PhilHealth Deduction (Weekly)",
                      philhealthDeduction,
                    ),
                    _buildDetailRow(
                      "Pag-IBIG Deduction (Weekly)",
                      pagibigDeduction,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Work Details",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow("Date Hired", dateHired),
                    _buildDetailRow("Payrate (Hourly)", payrate),
                    _buildDetailRow("Shift Schedule", shiftSchedule),
                    _buildDetailRow("Weekly Salary", weeklySalary),
                    _buildDetailRow(
                      "Total Weekly Deduction",
                      totalWeeklyDeduction,
                    ),
                    _buildDetailRow("Net Weekly Pay", netWeeklyPay),
                    _buildDetailRowWithStatus(
                      "Status",
                      "Active",
                      getStatusColor("Active"),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: fieldWorkerId == null
                                ? null
                                : () => _showWorkerQrDialog(
                                    context,
                                    workerName: workerName,
                                    fieldWorkerId: fieldWorkerId,
                                  ),
                            icon: const Icon(Icons.qr_code),
                            label: const Text("Download QR"),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFF1396E9)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Close"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1396E9),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showWorkerDamagesModal(
    BuildContext context,
    Map<String, dynamic> worker,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    List<Map<String, dynamic>> tools = [];
    List<Map<String, dynamic>> machinery = [];
    try {
      final userId = AuthService().currentUser?['user_id'];
      if (userId != null) {
        final items = await InventoryService.getInventoryItemsForSupervisor(supervisorId: userId);
        tools = items.where((i) => i['category'] == 'Tools').toList();
        machinery = items.where((i) => i['category'] == 'Machines' || i['category'] == 'Machinery').toList();
      }
    } catch (e) {
      debugPrint('Failed to load inventory: $e');
    }

    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss loading indicator

    const accent = Color(0xFFFF7A18);
    const accentDark = Color(0xFFD85F00);
    const accentSoftBg = Color(0xFFFFF5EC);
    const accentSoftBorder = Color(0xFFFFD9BF);
    const accentDeep = Color(0xFF7A3E00);
    const fieldBg = Color(0xFFF7F9FC);
    const fieldBorder = Color(0xFFE3E8EF);

    showDialog(
      context: context,
      builder: (context) {
        final workerName = _getWorkerName(worker);

        String selectedCategory = 'Tools';
        String selectedItem = '';
        String price = '';
        const paymentEverySalary = 'Payment every Salary';
        String deductionAmount = '';
        final TextEditingController priceController = TextEditingController();
        final TextEditingController itemSearchController = TextEditingController();
        final TextEditingController deductionController = TextEditingController();

        InputDecoration decoratedInput({
          String? hintText,
          Widget? prefix,
          bool disabled = false,
        }) {
          return InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            prefixIcon: prefix,
            filled: true,
            fillColor: disabled ? const Color(0xFFF1F3F7) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: fieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: accent, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: fieldBorder),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          );
        }

        Widget buildFieldLabel(String text, {IconData? icon}) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: accent),
                  const SizedBox(width: 6),
                ],
                Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            final isCustom = selectedCategory == 'Custom';

            final priceVal = double.tryParse(price) ?? 0.0;
            final deductionVal = double.tryParse(deductionAmount) ?? 0.0;
            final hasEstimate = priceVal > 0 && deductionVal > 0;
            final estimatedPeriods =
                hasEstimate ? (priceVal / deductionVal).ceil() : 0;

            return Dialog(
              backgroundColor: Colors.white,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.fromLTRB(20, 20, 12, 20),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFF9141), Color(0xFFFF7A18)],
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.report_gmailerrorred,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Report Damage',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  workerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFFFE5CF),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 20),
                            splashRadius: 18,
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),

                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_hasSavedDamageReport(worker))
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  _showDamagesSummaryModal(
                                    context,
                                    workerName: workerName,
                                    category: worker['damages_category']
                                            ?.toString() ??
                                        '',
                                    item:
                                        worker['damages_item']?.toString() ??
                                            '',
                                    price:
                                        worker['damages_price']?.toString() ??
                                            '',
                                    deduction:
                                        _damageDeductionDisplay(worker),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: accentSoftBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: accentSoftBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: accent.withOpacity(0.14),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.receipt_long,
                                          color: accent,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Existing damage on record',
                                              style: TextStyle(
                                                color: accentDeep,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Tap to view the saved summary',
                                              style: TextStyle(
                                                color: Color(0xFF9A6438),
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right,
                                          color: accentDark, size: 20),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFBBEBC9)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline,
                                        color: Color(0xFF12956A), size: 20),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'No damages reported for this worker.',
                                        style: TextStyle(
                                          color: Color(0xFF0F6D4E),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 20),

                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Record New Damage',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            buildFieldLabel('Damage Category',
                                icon: Icons.category_outlined),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return DropdownMenu<String>(
                                  initialSelection: selectedCategory,
                                  width: constraints.maxWidth,
                                  enableFilter: false,
                                  enableSearch: false,
                                  requestFocusOnTap: false,
                                  menuStyle: MenuStyle(
                                    backgroundColor:
                                        WidgetStateProperty.all(Colors.white),
                                    surfaceTintColor:
                                        WidgetStateProperty.all(Colors.white),
                                  ),
                                  inputDecorationTheme: InputDecorationTheme(
                                    filled: true,
                                    fillColor: Colors.white,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: fieldBorder),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: accent, width: 1.5),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: fieldBorder),
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 12),
                                  ),
                                  dropdownMenuEntries:
                                      ['Tools', 'Machinery', 'Custom']
                                          .map(
                                            (c) => DropdownMenuEntry(
                                              value: c,
                                              label: c,
                                            ),
                                          )
                                          .toList(),
                                  onSelected: (val) {
                                    if (val != null) {
                                      setModalState(() {
                                        selectedCategory = val;
                                        itemSearchController.clear();
                                        selectedItem = '';
                                        if (val != 'Custom') {
                                          priceController.clear();
                                          price = '';
                                        }
                                      });
                                    }
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            if (!isCustom) ...[
                              buildFieldLabel('Search Item',
                                  icon: Icons.search),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return DropdownMenu<String>(
                                    controller: itemSearchController,
                                    width: constraints.maxWidth,
                                    hintText: 'Search or select...',
                                    enableFilter: true,
                                    menuStyle: MenuStyle(
                                      backgroundColor:
                                          WidgetStateProperty.all(Colors.white),
                                      surfaceTintColor:
                                          WidgetStateProperty.all(Colors.white),
                                    ),
                                    inputDecorationTheme:
                                        InputDecorationTheme(
                                      filled: true,
                                      fillColor: Colors.white,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: fieldBorder),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: accent, width: 1.5),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: fieldBorder),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 12),
                                    ),
                                    dropdownMenuEntries:
                                        (selectedCategory == 'Tools'
                                                ? tools
                                                : machinery)
                                            .map((item) {
                                      final name = item['name']?.toString() ??
                                          'Unknown';
                                      return DropdownMenuEntry<String>(
                                        value: name,
                                        label: name,
                                      );
                                    }).toList(),
                                    onSelected: (String? selection) {
                                      if (selection != null) {
                                        setModalState(() {
                                          selectedItem = selection;
                                          final activeList =
                                              selectedCategory == 'Tools'
                                                  ? tools
                                                  : machinery;
                                          final matched =
                                              activeList.firstWhere(
                                            (i) => i['name'] == selection,
                                            orElse: () => <String, dynamic>{},
                                          );
                                          if (matched['price'] != null) {
                                            priceController.text =
                                                matched['price'].toString();
                                            price = priceController.text;
                                          } else {
                                            priceController.text = '0.00';
                                            price = '0.00';
                                          }
                                        });
                                      }
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            buildFieldLabel('Price of Damaged Item',
                                icon: Icons.payments_outlined),
                            TextField(
                              controller: priceController,
                              enabled: isCustom,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              onChanged: (val) =>
                                  setModalState(() => price = val),
                              decoration: decoratedInput(
                                hintText: isCustom
                                    ? '0.00'
                                    : 'Auto-fetched from inventory',
                                disabled: !isCustom,
                                prefix: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    '\u20B1',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: fieldBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: fieldBorder),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.event_repeat,
                                      color: accent,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Payment every Salary',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            buildFieldLabel(
                                'How much will be deducted every salary?',
                                icon: Icons.trending_down),
                            TextField(
                              controller: deductionController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              onChanged: (val) =>
                                  setModalState(() => deductionAmount = val),
                              decoration: decoratedInput(
                                hintText: '0.00',
                                prefix: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    '\u20B1',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (hasEstimate)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline,
                                        size: 14, color: accentDark),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'About $estimatedPeriods '
                                        '${estimatedPeriods == 1 ? 'salary period' : 'salary periods'} '
                                        'to fully repay \u20B1${priceVal.toStringAsFixed(2)}.',
                                        style: const TextStyle(
                                          color: accentDark,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
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

                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: fieldBorder),
                        ),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4B5563),
                                side: const BorderSide(color: fieldBorder),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final fieldWorkerId =
                                    _toInt(worker['fieldworker_id']) ??
                                        _toInt(worker['id']);
                                if (fieldWorkerId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Missing worker id; cannot save damage report.'),
                                    ),
                                  );
                                  return;
                                }

                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => const Center(
                                      child: CircularProgressIndicator()),
                                );

                                final url =
                                    _fieldWorkerDetailUri(fieldWorkerId);
                                try {
                                  final headers = {
                                    'Content-Type': 'application/json',
                                  };
                                  final response = await http.patch(
                                    url,
                                    headers: headers,
                                    body: jsonEncode({
                                      'damages_category': selectedCategory,
                                      'damages_item': isCustom
                                          ? 'Custom Item'
                                          : selectedItem,
                                      'damages_price': price.isEmpty
                                          ? null
                                          : (double.tryParse(price) ?? 0.0),
                                      'damages_schedule': paymentEverySalary,
                                      'damages_deduction_per_salary':
                                          deductionAmount.isEmpty
                                              ? null
                                              : (double.tryParse(
                                                      deductionAmount) ??
                                                  0.0),
                                    }),
                                  );

                                  if (!context.mounted) return;
                                  Navigator.pop(context);

                                  if (response.statusCode == 200 ||
                                      response.statusCode == 201) {
                                    worker['damages_category'] =
                                        selectedCategory;
                                    worker['damages_item'] = isCustom
                                        ? 'Custom Item'
                                        : selectedItem;
                                    worker['damages_price'] = price;
                                    worker['damages_schedule'] =
                                        paymentEverySalary;
                                    worker['damages_deduction'] =
                                        deductionAmount;
                                    worker['damages_deduction_per_salary'] =
                                        deductionAmount;
                                    setState(() {});

                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Successfully recorded damage for $workerName.'),
                                      ),
                                    );

                                    Navigator.pop(context);
                                    _showDamagesSummaryModal(
                                      context,
                                      workerName: workerName,
                                      category: selectedCategory,
                                      item: isCustom
                                          ? 'Custom Item'
                                          : selectedItem,
                                      price: price,
                                      deduction: deductionAmount,
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Failed to save damage report. ${response.body}'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.save_outlined, size: 18),
                              label: const Text(
                                'Save Report',
                                style:
                                    TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
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
            );
          },
        );
      },
    );
  }

  void _showDamagesSummaryModal(
    BuildContext context, {
    required String workerName,
    required String category,
    required String item,
    required String price,
    required String deduction,
  }) {
    const accent = Color(0xFFFF7A18);
    const accentDark = Color(0xFFD85F00);
    const accentNavy = Color(0xFF7A3E00);

    final priceValue = double.tryParse(price) ?? 0.0;
    final deductionValue = double.tryParse(deduction) ?? 0.0;
    final remainingPeriods = (deductionValue > 0 && priceValue > 0)
        ? (priceValue / deductionValue).ceil()
        : 0;

    final priceDisplay = priceValue > 0
        ? priceValue.toStringAsFixed(2)
        : (price.isEmpty ? '0.00' : price);
    final deductionDisplay = deductionValue > 0
        ? deductionValue.toStringAsFixed(2)
        : (deduction.isEmpty ? '0.00' : deduction);

    final resolvedItem = item.isEmpty ? 'Not specified' : item;
    final resolvedCategory = category.isEmpty ? 'Uncategorized' : category;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF9141), Color(0xFFFF7A18)],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Damage Report',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Summary of recorded damage',
                                style: TextStyle(
                                  color: Color(0xFFFFE5CF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          splashRadius: 18,
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5EC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFD9BF)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Total Damage',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '\u20B1$priceDisplay',
                                  style: const TextStyle(
                                    color: accentNavy,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE3E8EF)),
                      ),
                      child: Column(
                        children: [
                          _buildDamageSummaryRow(
                            icon: Icons.person_outline,
                            iconColor: accent,
                            label: 'Worker',
                            value: workerName,
                          ),
                          const Divider(height: 1, color: Color(0xFFE3E8EF)),
                          _buildDamageSummaryRow(
                            icon: Icons.category_outlined,
                            iconColor: accent,
                            label: 'Category',
                            value: resolvedCategory,
                          ),
                          const Divider(height: 1, color: Color(0xFFE3E8EF)),
                          _buildDamageSummaryRow(
                            icon: Icons.build_outlined,
                            iconColor: accent,
                            label: 'Damaged Item',
                            value: resolvedItem,
                          ),
                          const Divider(height: 1, color: Color(0xFFE3E8EF)),
                          _buildDamageSummaryRow(
                            icon: Icons.payments_outlined,
                            iconColor: accent,
                            label: 'Per-salary Deduction',
                            value: '\u20B1$deductionDisplay',
                            valueColor: accentDark,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (remainingPeriods > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Row(
                        children: [
                          Icon(Icons.event_repeat,
                              size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Estimated $remainingPeriods '
                              '${remainingPeriods == 1 ? 'salary period' : 'salary periods'} '
                              'to fully repay',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text(
                          'Done',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
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

  Widget _buildDamageSummaryRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: valueColor ?? const Color(0xFF1F2937),
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildWorkerQrPayload({required int fieldWorkerId}) {
    // Keep the payload simple and stable so scanning is easy.
    return 'structura-fw:$fieldWorkerId';
  }

  Future<void> _showWorkerQrDialog(
    BuildContext context, {
    required String workerName,
    required int fieldWorkerId,
  }) async {
    final repaintKey = GlobalKey();
    final payload = _buildWorkerQrPayload(fieldWorkerId: fieldWorkerId);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'QR Code - $workerName',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: RepaintBoundary(
                      key: repaintKey,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: 220,
                          height: 220,
                          child: QrImageView(
                            data: payload,
                            version: QrVersions.auto,
                            gapless: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Worker ID: $fieldWorkerId',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final boundary =
                                  repaintKey.currentContext?.findRenderObject()
                                      as RenderRepaintBoundary?;
                              if (boundary == null) {
                                throw Exception('QR render boundary not ready');
                              }

                              final ui.Image image = await boundary.toImage(
                                pixelRatio: 3.0,
                              );
                              final byteData = await image.toByteData(
                                format: ui.ImageByteFormat.png,
                              );
                              final Uint8List bytes = byteData!.buffer
                                  .asUint8List(
                                    byteData.offsetInBytes,
                                    byteData.lengthInBytes,
                                  );

                              final safeName = workerName.trim().isEmpty
                                  ? 'worker'
                                  : workerName.trim().replaceAll(
                                      RegExp(r'[^a-zA-Z0-9_-]+'),
                                      '_',
                                    );
                              final filename =
                                  'qr_${safeName}_$fieldWorkerId.png';

                              await downloadBytes(
                                bytes: bytes,
                                filename: filename,
                                mimeType: 'image/png',
                              );

                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'QR code downloaded: $filename',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              final msg = kIsWeb
                                  ? 'Failed to download QR: $e'
                                  : 'QR download is supported on web only';
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(msg)));
                            }
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('Download'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1396E9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithStatus(
    String label,
    String value,
    Color statusColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool hasNotifications = true;

  Widget _buildHeaderCell(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: Color(0xFF0C1935),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isTablet = screenWidth > 600 && screenWidth <= 1024;
    final isMobile = screenWidth <= 600;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Row(
            children: [
              if (isDesktop)
                Sidebar(activePage: "Worker Management", keepVisible: true),
              Expanded(
                child: Column(
                  children: [
                    const DashboardHeader(title: 'Workers'),

                    // Scrollable content area
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _workersFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final allWorkers = snapshot.data ?? [];
                          final projectOptions = _getProjectFilterOptions();
                          final filteredWorkers = _filterAndSortWorkers(
                            allWorkers,
                          );

                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                SizedBox(height: isMobile ? 4 : 8),

                                // Search & filter creative card - Responsive
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 12 : 20,
                                  ),
                                  child: Material(
                                    elevation: 4,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: EdgeInsets.all(
                                        isMobile ? 6 : 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: isMobile
                                          ? Row(
                                              children: [
                                                // Search on mobile (takes most space)
                                                Expanded(
                                                  child: TextField(
                                                    decoration: InputDecoration(
                                                      hintText: 'Search...',
                                                      hintStyle:
                                                          const TextStyle(
                                                            fontSize: 11,
                                                          ),
                                                      prefixIcon: const Icon(
                                                        Icons.search,
                                                        size: 16,
                                                      ),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        borderSide:
                                                            BorderSide.none,
                                                      ),
                                                      filled: true,
                                                      fillColor:
                                                          Colors.grey[50],
                                                      contentPadding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 6,
                                                            horizontal: 8,
                                                          ),
                                                      isDense: true,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                    onChanged: (v) => setState(
                                                      () => searchQuery = v,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                // Project filter dropdown (compact)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: DropdownButton<int?>(
                                                    value: projectOptions.any(
                                                          (option) =>
                                                              option.key ==
                                                              selectedProjectId,
                                                        )
                                                        ? selectedProjectId
                                                        : null,
                                                    underline: const SizedBox(),
                                                    isDense: true,
                                                    icon: const Icon(
                                                      Icons.apartment,
                                                      size: 16,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.black87,
                                                    ),
                                                    items: projectOptions
                                                        .map(
                                                          (option) =>
                                                              DropdownMenuItem<
                                                                int?
                                                              >(
                                                            value: option.key,
                                                            child: Text(
                                                              option.value,
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                  ),
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                    onChanged:
                                                        _onProjectFilterChanged,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                // Role filter dropdown (compact)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: DropdownButton<String>(
                                                    value: selectedRole,
                                                    underline: const SizedBox(),
                                                    isDense: true,
                                                    icon: const Icon(
                                                      Icons.filter_list,
                                                      size: 16,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.black87,
                                                    ),
                                                    items: roles
                                                        .map(
                                                          (
                                                            r,
                                                          ) => DropdownMenuItem(
                                                            value: r,
                                                            child: Text(
                                                              r,
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                  ),
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                    onChanged: (v) => setState(
                                                      () => selectedRole =
                                                          v ?? 'All',
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                // Sort dropdown (compact)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: DropdownButton<String>(
                                                    value: sortBy,
                                                    underline: const SizedBox(),
                                                    isDense: true,
                                                    icon: const Icon(
                                                      Icons.sort,
                                                      size: 16,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.black87,
                                                    ),
                                                    items: sortOptions
                                                        .map(
                                                          (
                                                            s,
                                                          ) => DropdownMenuItem(
                                                            value: s,
                                                            child: Text(
                                                              s,
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                  ),
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                    onChanged: (v) => setState(
                                                      () =>
                                                          sortBy = v ?? sortBy,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              children: [
                                                // Search on tablet/desktop
                                                Expanded(
                                                  flex: isTablet ? 4 : 3,
                                                  child: TextField(
                                                    decoration: InputDecoration(
                                                      hintText:
                                                          'Search workers by name, role or project',
                                                      prefixIcon: const Icon(
                                                        Icons.search,
                                                      ),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        borderSide:
                                                            BorderSide.none,
                                                      ),
                                                      filled: true,
                                                      fillColor:
                                                          Colors.grey[50],
                                                      contentPadding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 12,
                                                          ),
                                                    ),
                                                    onChanged: (v) => setState(
                                                      () => searchQuery = v,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                // Project filter dropdown on tablet/desktop
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: DropdownButton<int?>(
                                                    value: projectOptions.any(
                                                          (option) =>
                                                              option.key ==
                                                              selectedProjectId,
                                                        )
                                                        ? selectedProjectId
                                                        : null,
                                                    underline: const SizedBox(),
                                                    hint: const Text(
                                                      'Filter by project',
                                                    ),
                                                    items: projectOptions
                                                        .map(
                                                          (option) =>
                                                              DropdownMenuItem<
                                                                int?
                                                              >(
                                                                value:
                                                                    option.key,
                                                                child: Text(
                                                                  option.value,
                                                                ),
                                                              ),
                                                        )
                                                        .toList(),
                                                    onChanged:
                                                        _onProjectFilterChanged,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                // Role filter dropdown on tablet/desktop
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: DropdownButton<String>(
                                                    value: selectedRole,
                                                    underline: const SizedBox(),
                                                    hint: const Text(
                                                      'Filter by role',
                                                    ),
                                                    items: roles
                                                        .map(
                                                          (r) =>
                                                              DropdownMenuItem(
                                                                value: r,
                                                                child: Text(r),
                                                              ),
                                                        )
                                                        .toList(),
                                                    onChanged: (v) => setState(
                                                      () => selectedRole =
                                                          v ?? 'All',
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                // sort dropdown
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: DropdownButton<String>(
                                                    value: sortBy,
                                                    underline: const SizedBox(),
                                                    items: sortOptions
                                                        .map(
                                                          (s) =>
                                                              DropdownMenuItem(
                                                                value: s,
                                                                child: Text(s),
                                                              ),
                                                        )
                                                        .toList(),
                                                    onChanged: (v) => setState(
                                                      () =>
                                                          sortBy = v ?? sortBy,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: isMobile ? 8 : 12),

                                // Workers list - Responsive: Cards on mobile, table on desktop
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 12 : 20,
                                  ),
                                  child: filteredWorkers.isEmpty
                                      ? SizedBox(
                                          height: 200,
                                          child: Center(
                                            child: Text(
                                              'No workers found',
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ),
                                        )
                                      : isMobile
                                      ? _buildMobileWorkersList(filteredWorkers)
                                      : _buildDesktopWorkersTable(
                                          isTablet,
                                          filteredWorkers,
                                        ),
                                ),
                                SizedBox(height: isMobile ? 8 : 12),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      // Bottom navigation bar for mobile only
      bottomNavigationBar: isMobile ? _buildBottomNavBar() : null,
    );
  }

  Widget _buildBottomNavBar() {
    return SupervisorMobileBottomNav(
      activeTab: SupervisorMobileTab.workers,
      onSelect: _navigateToPage,
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    final color = isActive ? AppColors.accent : Colors.white70;

    return InkWell(
      onTap: () {
        if (label == 'More') {
          _showMoreOptions();
        } else {
          _navigateToPage(label);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accent.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.mobileNavLabel(color, isActive: isActive),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.navSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _buildMoreOption(Icons.file_copy, 'Reports', 'Reports'),
              _buildMoreOption(Icons.inventory, 'Inventory', 'Inventory'),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOption(IconData icon, String title, String page) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        _navigateToPage(page);
      },
    );
  }

  // Mobile card-based list view
  Widget _buildMobileWorkersList(List<Map<String, dynamic>> filteredWorkers) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredWorkers.length,
      itemBuilder: (context, index) {
        final worker = filteredWorkers[index];
        final roleColor = _roleColor(worker['role']);
        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showWorkerDetailModal(context, worker),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Avatar + Name + Status
                  Row(
                    children: [
                      _buildWorkerAvatar(
                        worker,
                        radius: 24,
                        roleColor: roleColor,
                        fontSize: 16,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getWorkerName(worker),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                worker['role'] ?? 'Worker',
                                style: TextStyle(
                                  color: roleColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: getStatusColor('Active'),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Active',
                              style: TextStyle(
                                color: getStatusColor('Active'),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // Details rows
                  _buildMobileDetailRow(
                    Icons.phone,
                    worker['phone_number'] ?? 'N/A',
                  ),
                  const SizedBox(height: 6),
                  _buildMobileDetailRow(
                    Icons.calendar_today,
                    _formatDate(worker['created_at']),
                  ),
                  const SizedBox(height: 6),
                  _buildMobileDetailRow(
                    Icons.apartment,
                    _getProjectName(worker),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showWorkerDamagesModal(context, worker),
                          icon: const Icon(Icons.broken_image_outlined, size: 16),
                          label: const Text('Damages'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showWorkerDetailModal(context, worker),
                          icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                          label: const Text('Details'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileDetailRow(IconData icon, String text, {int maxLines = 1}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
            overflow: TextOverflow.ellipsis,
            maxLines: maxLines,
          ),
        ),
      ],
    );
  }

  // Desktop/Tablet table view
  Widget _buildDesktopWorkersTable(
    bool isTablet,
    List<Map<String, dynamic>> filteredWorkers,
  ) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Table header
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 12 : 16,
              vertical: isTablet ? 12 : 14,
            ),
            child: Row(
              children: [
                _buildHeaderCell('Name', flex: 3),
                _buildHeaderCell('Role', flex: 2),
                _buildHeaderCell('Project', flex: isTablet ? 3 : 4),
                _buildHeaderCell('Status', flex: 2),
                _buildHeaderCell('Damages', flex: 2),
                _buildHeaderCell('Actions', flex: 1),
              ],
            ),
          ),
          const Divider(height: 1),
          // Table body
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredWorkers.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final worker = filteredWorkers[index];
              final roleColor = _roleColor(worker['role']);
              return InkWell(
                onTap: () => _showWorkerDetailModal(context, worker),
                hoverColor: const Color(0xFFFF6F00).withOpacity(0.03),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 12 : 16,
                    vertical: isTablet ? 10 : 12,
                  ),
                  child: Row(
                    children: [
                      // Name column
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            _buildWorkerAvatar(
                              worker,
                              radius: isTablet ? 16 : 20,
                              roleColor: roleColor,
                              fontSize: isTablet ? 12 : 14,
                            ),
                            SizedBox(width: isTablet ? 8 : 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getWorkerName(worker),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: isTablet ? 13 : 14,
                                    ),
                                  ),
                                  if (!isTablet)
                                    Text(
                                      worker['role'] ?? 'Worker',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Role column
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 8 : 10,
                            vertical: isTablet ? 4 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            worker['role'] ?? 'Worker',
                            style: TextStyle(
                              color: roleColor,
                              fontWeight: FontWeight.w600,
                              fontSize: isTablet ? 11 : 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      // Project column
                      Expanded(
                        flex: isTablet ? 3 : 4,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _getWorkerProjectNames(worker).map((
                            projectName,
                          ) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 6 : 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F8FC),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFDCE7F3),
                                ),
                              ),
                              child: Text(
                                projectName,
                                style: TextStyle(
                                  color: const Color(0xFF334155),
                                  fontSize: isTablet ? 10 : 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // Status column
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 8 : 10,
                            vertical: isTablet ? 4 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: isTablet ? 6 : 8,
                                height: isTablet ? 6 : 8,
                                decoration: BoxDecoration(
                                  color: getStatusColor('Active'),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: isTablet ? 4 : 6),
                              Flexible(
                                child: Text(
                                  'Active',
                                  style: TextStyle(
                                    color: getStatusColor('Active'),
                                    fontWeight: FontWeight.w700,
                                    fontSize: isTablet ? 11 : 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Damages column
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () => _showWorkerDamagesModal(context, worker),
                            icon: const Icon(Icons.broken_image_outlined, size: 16),
                            label: const Text('View', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: const Size(0, 32),
                            ),
                          ),
                        ),
                      ),
                      // Actions column
                      Expanded(
                        flex: 1,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.remove_red_eye_outlined,
                                size: isTablet ? 18 : 20,
                              ),
                              color: const Color(0xFF1396E9),
                              onPressed: () =>
                                  _showWorkerDetailModal(context, worker),
                              tooltip: 'View Details',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            if (!isTablet) const SizedBox(width: 8),
                            if (!isTablet)
                              PopupMenuButton<String>(
                                color: Colors.white,
                                onSelected: (v) {
                                  if (v == 'toggle') {
                                    setState(() {
                                      worker['status'] =
                                          worker['status'] == 'Active'
                                          ? 'Inactive'
                                          : 'Active';
                                    });
                                  } else if (v == 'view_damage_summary') {
                                    _showDamagesSummaryModal(
                                      context,
                                      workerName: _getWorkerName(worker),
                                      category: worker['damages_category']?.toString() ?? '',
                                      item: worker['damages_item']?.toString() ?? '',
                                      price: worker['damages_price']?.toString() ?? '',
                                      deduction: _damageDeductionDisplay(worker),
                                    );
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Text(
                                      worker['status'] == 'Active'
                                          ? 'Set Inactive'
                                          : 'Set Active',
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Remove (demo)'),
                                  ),
                                  if (_hasSavedDamageReport(worker))
                                    const PopupMenuItem(
                                      value: 'view_damage_summary',
                                      child: Text('Damage Summary'),
                                    ),
                                ],
                                icon: const Icon(Icons.more_vert, size: 20),
                                padding: EdgeInsets.zero,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------
// Header
// ---------------------------
class WorkersHeader extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  final bool isMobile;
  const WorkersHeader({super.key, this.onMenuPressed, this.isMobile = false});

  @override
  State<WorkersHeader> createState() => _WorkersHeaderState();
}

class _WorkersHeaderState extends State<WorkersHeader> {
  bool hasNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // keep header white
      padding: EdgeInsets.symmetric(
        horizontal: widget.isMobile ? 12 : 24,
        vertical: widget.isMobile ? 12 : 16,
      ),
      child: Row(
        children: [
          // slim blue line in the left corner
          Container(
            width: widget.isMobile ? 3 : 4,
            height: widget.isMobile ? 40 : 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6F00),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          SizedBox(width: widget.isMobile ? 8 : 12),
          // Title + subtitle (no Super Highway text)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Workers",
                  style: TextStyle(
                    color: const Color(0xFF0C1935),
                    fontSize: widget.isMobile ? 16 : 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!widget.isMobile) const SizedBox(height: 4),
                if (!widget.isMobile)
                  const Text(
                    "Manage your workforce",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
          ),
          // Right side - Notifications & AESTRA (simplified on mobile)
          if (!widget.isMobile)
            Row(
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => hasNotifications = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notifications opened (demo)'),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Color(0xFF0C1935),
                            size: 24,
                          ),
                        ),
                        if (hasNotifications)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B6B),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                PopupMenuButton<String>(
                  color: Colors.white,
                  onSelected: (value) async {
                    if (value == 'switch') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Switch Account (demo)')),
                      );
                      return;
                    }

                    if (value == 'logout') {
                      await AuthService().logout();
                      if (!context.mounted) return;
                      context.go('/login');
                    }
                  },
                  offset: const Offset(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'switch',
                          height: 48,
                          child: Row(
                            children: [
                              Icon(
                                Icons.swap_horiz,
                                size: 18,
                                color: Color(0xFF0C1935),
                              ),
                              SizedBox(width: 12),
                              Text('Switch Account'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(height: 1),
                        const PopupMenuItem<String>(
                          value: 'logout',
                          height: 48,
                          child: Row(
                            children: [
                              Icon(
                                Icons.logout,
                                size: 18,
                                color: Color(0xFFFF6B6B),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Logout',
                                style: TextStyle(color: Color(0xFFFF6B6B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const SupervisorUserBadge(
                        showName: false,
                        avatarSize: 34,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            // Mobile: Just show notification icon
            IconButton(
              icon: Stack(
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xFF0C1935),
                    size: 22,
                  ),
                  if (hasNotifications)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                setState(() => hasNotifications = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications opened (demo)')),
                );
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
