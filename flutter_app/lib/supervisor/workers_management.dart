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
  late Future<List<Map<String, dynamic>>> _workersFuture;
  Map<int, String> _projectNamesById = {};

  @override
  void initState() {
    super.initState();
    _workersFuture = _fetchFieldWorkers();
  }

  Future<List<Map<String, dynamic>>> _fetchFieldWorkers() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser ?? <String, dynamic>{};
      final userId = _toInt(currentUser['user_id']);
      final projectId = _toInt(currentUser['project_id']);
      final typeOrRole = (currentUser['type'] ?? currentUser['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      // Some sessions only keep `user_id` for supervisors. Fall back to it.
      final supervisorId =
          _toInt(currentUser['supervisor_id']) ??
          ((typeOrRole == 'supervisor') ? userId : null);

      await _fetchProjects(supervisorId: supervisorId, userId: userId);

      print('=== Fetching Field Workers ===');
      print('Scope: all projects | filter: active workers');
      print('Current user payload: $currentUser');
      print(
        'Resolved supervisorId: $supervisorId, projectId: $projectId, userId: $userId',
      );

      final url = supervisorId != null
          ? AppConfig.apiUri('field-workers/?supervisor_id=$supervisorId')
          : (projectId != null
                ? AppConfig.apiUri('field-workers/?project_id=$projectId')
                : AppConfig.apiUri('field-workers/'));
      print('📡 API URL: $url');

      final response = await http.get(url);

      print('📊 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final workers = _extractWorkers(decoded);
        final activeWorkers = workers.where(_isWorkerActive).toList();
        print(
          '✅ Found ${workers.length} workers (${activeWorkers.length} active)',
        );

        // Some backends restrict supervisors to project-scoped data even when no
        // query param is provided. Fallback prevents empty table in that case.
        if (activeWorkers.isEmpty && projectId != null) {
          final fallbackUrl = AppConfig.apiUri(
            'field-workers/?project_id=$projectId',
          );
          print('↩️ Fallback API URL: $fallbackUrl');
          final fallbackResponse = await http.get(fallbackUrl);
          print('↩️ Fallback status: ${fallbackResponse.statusCode}');

          if (fallbackResponse.statusCode == 200) {
            final fallbackDecoded = jsonDecode(fallbackResponse.body);
            final fallbackWorkers = _extractWorkers(fallbackDecoded);
            final fallbackActive = fallbackWorkers
                .where(_isWorkerActive)
                .toList();
            print(
              '✅ Fallback workers: ${fallbackWorkers.length} (${fallbackActive.length} active)',
            );
            return fallbackActive;
          }
        }

        return activeWorkers;
      } else {
        print('❌ Failed to fetch field workers: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching field workers: $e');
      return [];
    }
  }

  Future<void> _fetchProjects({dynamic supervisorId, dynamic userId}) async {
    try {
      final Uri url;
      if (supervisorId != null) {
        url = AppConfig.apiUri('projects/?supervisor_id=$supervisorId');
      } else if (userId != null) {
        url = AppConfig.apiUri('projects/?user_id=$userId');
      } else {
        url = AppConfig.apiUri('projects/');
      }

      final response = await http.get(url);
      print('Projects API response status: ${response.statusCode}');

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
      print('Projects fetched successfully: ${mapped.length}');
    } catch (e) {
      print('Failed to fetch projects: $e');
    }
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
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
      case 'Tasks':
      case 'Task Progress':
        context.go('/supervisor/task-progress');
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
  String selectedProject = 'All Projects';
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

  List<String> _getProjectFilterOptions(List<Map<String, dynamic>> allWorkers) {
    final projects = <String>{'All Projects'};
    for (final worker in allWorkers) {
      final names = _getWorkerProjectNames(worker);
      for (final name in names) {
        if (name.trim().isNotEmpty) {
          projects.add(name);
        }
      }
    }

    final sorted = projects.toList()
      ..sort((a, b) {
        if (a == 'All Projects') return -1;
        if (b == 'All Projects') return 1;
        return a.compareTo(b);
      });
    return sorted;
  }

  List<Map<String, dynamic>> _filterAndSortWorkers(
    List<Map<String, dynamic>> allWorkers,
  ) {
    final filtered = allWorkers.where((worker) {
      final fullName = '${worker['first_name']} ${worker['last_name']}'
          .toLowerCase();
      final role = (worker['role'] ?? '').toString().toLowerCase();
      final projectNames = _getWorkerProjectNames(worker);
      final projectSearchText = projectNames.join(' ').toLowerCase();
      final query = searchQuery.toLowerCase();
      final matchesSearch =
          fullName.contains(query) ||
          role.contains(query) ||
          projectSearchText.contains(query);
      final matchesRole =
          selectedRole == 'All' || worker['role'] == selectedRole;
      final matchesProject =
          selectedProject == 'All Projects' ||
          projectNames.contains(selectedProject);
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
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check),
                          label: const Text("Close"),
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
                          final projectOptions = _getProjectFilterOptions(
                            allWorkers,
                          );
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
                                                  child: DropdownButton<String>(
                                                    value:
                                                        projectOptions.contains(
                                                          selectedProject,
                                                        )
                                                        ? selectedProject
                                                        : 'All Projects',
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
                                                          (
                                                            project,
                                                          ) => DropdownMenuItem(
                                                            value: project,
                                                            child: Text(
                                                              project,
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
                                                      () => selectedProject =
                                                          v ?? 'All Projects',
                                                    ),
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
                                                  child: DropdownButton<String>(
                                                    value:
                                                        projectOptions.contains(
                                                          selectedProject,
                                                        )
                                                        ? selectedProject
                                                        : 'All Projects',
                                                    underline: const SizedBox(),
                                                    hint: const Text(
                                                      'Filter by project',
                                                    ),
                                                    items: projectOptions
                                                        .map(
                                                          (project) =>
                                                              DropdownMenuItem(
                                                                value: project,
                                                                child: Text(
                                                                  project,
                                                                ),
                                                              ),
                                                        )
                                                        .toList(),
                                                    onChanged: (v) => setState(
                                                      () => selectedProject =
                                                          v ?? 'All Projects',
                                                    ),
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
              _buildMoreOption(Icons.show_chart, 'Task Progress', 'Tasks'),
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
                  // Action button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showWorkerDetailModal(context, worker),
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                      label: const Text('View Details'),
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
