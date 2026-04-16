import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/app_config.dart';
import '../services/app_time_service.dart';
import '../services/app_theme_tokens.dart';
import '../services/subscription_helper.dart';
import 'widgets/sidebar.dart';
import 'widgets/mobile_bottom_nav.dart';
import 'widgets/dashboard_header.dart';

class AttendancePage extends StatefulWidget {
  final bool initialSidebarVisible;

  const AttendancePage({super.key, this.initialSidebarVisible = false});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final Color primary = AppColors.accent;
  final Color primaryLight = const Color(0xFFFFF3E0);
  final Color neutral = AppColors.surface;

  late Future<List<Map<String, dynamic>>> _fieldWorkersFuture;
  late Future<List<Map<String, dynamic>>> _attendanceRecordsFuture;

  DateTime selectedDate = AppTimeService.now();
  String searchQuery = '';
  String statusFilter = 'All';
  String roleFilter = 'All';

  @override
  void initState() {
    super.initState();
    _fieldWorkersFuture = _fetchFieldWorkers();
    _attendanceRecordsFuture = _fetchAttendanceRecords();
  }

  Future<List<Map<String, dynamic>>> _fetchFieldWorkers() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final projectId = authService.currentUser?['project_id'];

      if (projectId == null) return [];

      final response = await http.get(
        AppConfig.apiUri('field-workers/?project_id=$projectId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching field workers: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAttendanceRecords() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final projectId = authService.currentUser?['project_id'];

      if (projectId == null) return [];

      final dateStr =
          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
      final response = await http.get(
        AppConfig.apiUri(
          'attendance/?project_id=$projectId&attendance_date=$dateStr',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching attendance: $e');
      return [];
    }
  }

  Future<bool> _saveAttendance(
    Map<String, dynamic> attendanceData, {
    DateTime? attendanceDate,
  }) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final projectId = authService.currentUser?['project_id'];
    if (projectId == null) {
      throw Exception('No project assigned to supervisor');
    }

    final effectiveDate = attendanceDate ?? selectedDate;
    final dateStr =
        '${effectiveDate.year}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}';

    final payload = Map<String, dynamic>.from(attendanceData)
      ..['project'] = projectId
      ..['attendance_date'] = dateStr;

    // Scope lookup to current project to avoid cross-project record rewrites.
    final existingRecords = await http.get(
      AppConfig.apiUri(
        'attendance/?project_id=$projectId&field_worker_id=${payload['field_worker']}&attendance_date=$dateStr',
      ),
    );

    if (existingRecords.statusCode != 200) {
      throw Exception(
        'Failed to query attendance (${existingRecords.statusCode}).',
      );
    }

    final List<dynamic> data = jsonDecode(existingRecords.body);
    if (data.isNotEmpty) {
      final attendanceId = data[0]['attendance_id'];
      final updateResponse = await http.patch(
        AppConfig.apiUri('attendance/$attendanceId/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (!mounted) return false;

      if (SubscriptionHelper.handleResponse(context, updateResponse)) {
        return false;
      }

      if (updateResponse.statusCode < 200 || updateResponse.statusCode >= 300) {
        throw Exception(_extractApiErrorMessage(updateResponse));
      }
    } else {
      final createResponse = await http.post(
        AppConfig.apiUri('attendance/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (!mounted) return false;

      if (SubscriptionHelper.handleResponse(context, createResponse)) {
        return false;
      }

      if (createResponse.statusCode < 200 || createResponse.statusCode >= 300) {
        throw Exception(_extractApiErrorMessage(createResponse));
      }
    }

    setState(() {
      _attendanceRecordsFuture = _fetchAttendanceRecords();
    });
    return true;
  }

  int? _parseFieldWorkerIdFromQr(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    // Supported formats:
    // - structura-fw:123
    // - 123
    // - any string containing a number as the last segment
    final match = RegExp(
      r'(?:structura-fw:)?(\d+)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }

    // Fallback: pick first number found.
    final any = RegExp(r'(\d+)').firstMatch(value);
    if (any != null) {
      return int.tryParse(any.group(1) ?? '');
    }
    return null;
  }

  String _timeOfDayToTimeString(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm:00';
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  Map<String, dynamic> _resolveWorkerFromRecord(
    Map<String, dynamic> record,
    List<Map<String, dynamic>> fieldWorkers,
  ) {
    final recordWorkerRaw = record['field_worker_id'] ?? record['field_worker'];
    final recordWorkerId = recordWorkerRaw is Map<String, dynamic>
        ? _asInt(recordWorkerRaw['fieldworker_id'] ?? recordWorkerRaw['id'])
        : _asInt(recordWorkerRaw);

    if (recordWorkerId != null) {
      for (final worker in fieldWorkers) {
        final workerId = _asInt(
          worker['fieldworker_id'] ?? worker['field_worker'] ?? worker['id'],
        );
        if (workerId == recordWorkerId) {
          return worker;
        }
      }
    }

    if (recordWorkerRaw is Map<String, dynamic>) {
      return {
        'first_name': recordWorkerRaw['first_name'] ?? 'Unknown',
        'last_name': recordWorkerRaw['last_name'] ?? '',
        'role': recordWorkerRaw['role'] ?? 'N/A',
      };
    }

    final rawName = (record['field_worker_name'] ?? '').toString().trim();
    if (rawName.isNotEmpty) {
      final parts = rawName.split(RegExp(r'\s+'));
      final first = parts.isNotEmpty ? parts.first : 'Unknown';
      final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      return {
        'first_name': first,
        'last_name': last,
        'role': record['role'] ?? 'N/A',
      };
    }

    return {'first_name': 'Unknown', 'last_name': '', 'role': 'N/A'};
  }

  int? _timeStringToMinutes(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final text = raw.trim();
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AaPp][Mm])?$',
    ).firstMatch(text);
    if (match == null) return null;

    var hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null) return null;

    final meridiem = (match.group(4) ?? '').toLowerCase();
    if (meridiem == 'am') {
      if (hour == 12) hour = 0;
    } else if (meridiem == 'pm') {
      if (hour < 12) hour += 12;
    }

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  String _extractApiErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }

        final nonFieldErrors = decoded['non_field_errors'];
        if (nonFieldErrors is List && nonFieldErrors.isNotEmpty) {
          final first = nonFieldErrors.first?.toString().trim();
          if (first != null && first.isNotEmpty) {
            return first;
          }
        }
      }
    } catch (_) {
      // Fall back to generic message below.
    }
    return 'Request failed (${response.statusCode}).';
  }

  Future<void> _showAttendanceConflictModal(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Worker Already Timed In'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchExistingAttendanceRecord({
    required int fieldWorkerId,
    required DateTime attendanceDate,
  }) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final projectId = authService.currentUser?['project_id'];
    if (projectId == null) return null;

    final dateStr =
        '${attendanceDate.year}-${attendanceDate.month.toString().padLeft(2, '0')}-${attendanceDate.day.toString().padLeft(2, '0')}';
    final existingRecords = await http.get(
      AppConfig.apiUri(
        'attendance/?project_id=$projectId&field_worker_id=$fieldWorkerId&attendance_date=$dateStr',
      ),
    );

    if (existingRecords.statusCode != 200) return null;
    final List<dynamic> data = jsonDecode(existingRecords.body);
    if (data.isEmpty) return null;
    return data.first is Map<String, dynamic>
        ? data.first as Map<String, dynamic>
        : null;
  }

  Future<String?> _pickScanTime() async {
    final seededNow = AppTimeService.now();
    final now = TimeOfDay(hour: seededNow.hour, minute: seededNow.minute);
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
      helpText: 'Set attendance time',
      confirmText: 'Use time',
      cancelText: 'Cancel',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: primary),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return null;
    return _timeOfDayToTimeString(picked);
  }

  Future<void> _recordAttendanceFromScan({
    required String action,
    required int fieldWorkerId,
    required String time,
  }) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final projectId = authService.currentUser?['project_id'];

    if (projectId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No project assigned to supervisor')),
      );
      return;
    }

    final attendanceData = <String, dynamic>{'field_worker': fieldWorkerId};
    final scanNow = AppTimeService.now();
    final scanDate = DateTime(scanNow.year, scanNow.month, scanNow.day);

    if (action == 'Time Out') {
      final existing = await _fetchExistingAttendanceRecord(
        fieldWorkerId: fieldWorkerId,
        attendanceDate: scanDate,
      );
      final inMinutes = _timeStringToMinutes(
        (existing?['check_in_time'] ?? '').toString(),
      );
      final outMinutes = _timeStringToMinutes(time);

      if (inMinutes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot time out before time in is recorded.'),
          ),
        );
        return;
      }

      if (outMinutes == null || outMinutes <= inMinutes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time Out must be later than Time In.')),
        );
        return;
      }
    }

    switch (action) {
      case 'Time In':
        attendanceData['check_in_time'] = time;
        attendanceData['status'] = 'on_site';
        break;
      case 'Time Out':
        attendanceData['check_out_time'] = time;
        attendanceData['status'] = 'absent';
        break;
      case 'Break In':
        attendanceData['break_in_time'] = time;
        attendanceData['status'] = 'on_break';
        break;
      case 'Break Out':
        attendanceData['break_out_time'] = time;
        attendanceData['status'] = 'on_site';
        break;
      default:
        // Unknown action; do nothing.
        break;
    }

    if (mounted) {
      setState(() {
        // Keep attendance view aligned with the actual scan day.
        selectedDate = scanDate;
      });
    }

    try {
      final saved = await _saveAttendance(
        attendanceData,
        attendanceDate: scanDate,
      );
      if (!mounted || !saved) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ $action recorded for worker #$fieldWorkerId'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString().replaceFirst('Exception: ', '').trim();
      final isCrossProjectTimeInConflict =
          action == 'Time In' &&
          errorMessage.toLowerCase().contains('currently timed in on');

      if (isCrossProjectTimeInConflict) {
        await _showAttendanceConflictModal(errorMessage);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save attendance: $errorMessage')),
      );
    }
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
        return; // Already on attendance page
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

  final List<String> roles = [
    'All',
    'Mason',
    'Painter',
    'Electrician',
    'Carpenter',
  ];

  bool hasNotifications = true;

  List<Map<String, dynamic>> _filterAttendance(
    List<Map<String, dynamic>> allAttendance,
    List<Map<String, dynamic>> allWorkers,
  ) {
    final filtered = allAttendance.where((record) {
      final worker = allWorkers.firstWhere(
        (w) => w['fieldworker_id'] == record['field_worker'],
        orElse: () => {},
      );

      final fullName =
          '${worker['first_name'] ?? ''} ${worker['last_name'] ?? ''}'
              .toLowerCase();
      final matchesSearch =
          searchQuery.isEmpty || fullName.contains(searchQuery.toLowerCase());
      final matchesStatus =
          statusFilter == 'All' ||
          _statusLabelForRecord(record) == statusFilter;
      final matchesRole = roleFilter == 'All' || worker['role'] == roleFilter;

      return matchesSearch && matchesStatus && matchesRole;
    }).toList();

    return filtered;
  }

  String _statusKeyForRecord(Map<String, dynamic> record) {
    final checkOut = (record['check_out_time'] ?? '').toString().trim();
    if (checkOut.isNotEmpty) return 'checked_out';
    return (record['status'] ?? 'absent').toString().trim().toLowerCase();
  }

  String _statusLabelForRecord(Map<String, dynamic> record) {
    switch (_statusKeyForRecord(record)) {
      case 'checked_out':
        return 'Checked Out';
      case 'on_site':
        return 'On Site';
      case 'on_break':
        return 'On Break';
      case 'absent':
        return 'Absent';
      default:
        return 'Unknown';
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'checked_out':
        return const Color(0xFF2563EB);
      case 'on_site':
        return const Color(0xFF757575);
      case 'on_break':
        return const Color(0xFFFF8F00);
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return 'No date';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '--';
    return time;
  }

  // ----------------------
  // UI BUILD
  // ----------------------
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isMobile =
        screenWidth <= 1024; // Treat tablet like mobile for compact layout

    return Scaffold(
      backgroundColor: neutral,
      body: Stack(
        children: [
          Row(
            children: [
              if (isDesktop)
                Sidebar(activePage: "Attendance", keepVisible: true),
              Expanded(
                child: Column(
                  children: [
                    const DashboardHeader(title: 'Attendance'),

                    SizedBox(height: isMobile ? 4 : 8),

                    // Search, filters and actions - Responsive
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 20,
                      ),
                      child: Material(
                        elevation: 3,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 6 : 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: isMobile
                              ? Column(
                                  children: [
                                    // Search field on mobile
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            decoration: InputDecoration(
                                              hintText: 'Search...',
                                              hintStyle: const TextStyle(
                                                fontSize: 11,
                                              ),
                                              prefixIcon: const Icon(
                                                Icons.search,
                                                size: 16,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide.none,
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey[50],
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
                                            onChanged: (v) =>
                                                setState(() => searchQuery = v),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        // Date picker icon
                                        GestureDetector(
                                          onTap: () async {
                                            final DateTime? picked =
                                                await showDatePicker(
                                                  context: context,
                                                  initialDate: selectedDate,
                                                  firstDate: DateTime(2000),
                                                  lastDate: DateTime(2100),
                                                );
                                            if (picked != null)
                                              setState(
                                                () => selectedDate = picked,
                                              );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[50],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.calendar_today,
                                              color: primary,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        // Status filter dropdown
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[50],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: DropdownButton<String>(
                                            value: statusFilter,
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
                                            items:
                                                [
                                                      'All',
                                                      'On Site',
                                                      'On Break',
                                                      'Checked Out',
                                                      'Absent',
                                                    ]
                                                    .map(
                                                      (s) => DropdownMenuItem(
                                                        value: s,
                                                        child: Text(
                                                          s,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 11,
                                                              ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                            onChanged: (v) => setState(
                                              () => statusFilter = v ?? 'All',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // Action buttons on mobile (compact row)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: _showActionSelectionDialog,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF1396E9,
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: const [
                                                  Icon(
                                                    Icons.qr_code_scanner,
                                                    color: Color(0xFF1396E9),
                                                    size: 16,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'QR',
                                                    style: TextStyle(
                                                      color: Color(0xFF1396E9),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: InkWell(
                                            onTap: _showManualAttendanceDialog,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF16A085,
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: const [
                                                  Icon(
                                                    Icons.edit_calendar,
                                                    color: Color(0xFF16A085),
                                                    size: 16,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Manual',
                                                    style: TextStyle(
                                                      color: Color(0xFF16A085),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    // Search box on desktop/tablet
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.search,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              decoration: const InputDecoration(
                                                hintText:
                                                    'Search by name or role',
                                                border: InputBorder.none,
                                              ),
                                              onChanged: (v) => setState(
                                                () => searchQuery = v,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          VerticalDivider(
                                            color: Colors.grey.shade200,
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () async {
                                              final DateTime? picked =
                                                  await showDatePicker(
                                                    context: context,
                                                    initialDate: selectedDate,
                                                    firstDate: DateTime(2000),
                                                    lastDate: DateTime(2100),
                                                  );
                                              if (picked != null)
                                                setState(
                                                  () => selectedDate = picked,
                                                );
                                            },
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today,
                                                  color: primary,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                                                  style: TextStyle(
                                                    color: Colors.grey[800],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Status filter chips on desktop/tablet
                                    Expanded(
                                      flex: 2,
                                      child: Wrap(
                                        spacing: 8,
                                        children:
                                            [
                                              'All',
                                              'On Site',
                                              'On Break',
                                              'Checked Out',
                                              'Absent',
                                            ].map((s) {
                                              final sel = statusFilter == s;
                                              return ChoiceChip(
                                                label: Text(
                                                  s,
                                                  style: TextStyle(
                                                    color: sel
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                                ),
                                                selected: sel,
                                                selectedColor: primary,
                                                backgroundColor:
                                                    Colors.grey[100],
                                                onSelected: (_) => setState(
                                                  () => statusFilter = s,
                                                ),
                                              );
                                            }).toList(),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Actions on desktop/tablet
                                    Row(
                                      children: [
                                        Tooltip(
                                          message: 'Scan QR',
                                          child: InkWell(
                                            onTap: _showActionSelectionDialog,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black12,
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.qr_code_scanner,
                                                color: Color(0xFF1396E9),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Tooltip(
                                          message: 'Manual Entry',
                                          child: InkWell(
                                            onTap: _showManualAttendanceDialog,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black12,
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.edit_calendar,
                                                color: Color(0xFF16A085),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                primary,
                                                primary.withOpacity(0.85),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 8,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              onTap: () =>
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Export (demo)',
                                                      ),
                                                    ),
                                                  ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10,
                                                    ),
                                                child: Row(
                                                  children: const [
                                                    Icon(
                                                      Icons.download,
                                                      color: Colors.white,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Export',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w700,
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
                                  ],
                                ),
                        ),
                      ),
                    ),

                    SizedBox(height: isMobile ? 8 : 16),

                    // Attendance list - Responsive
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 20,
                        ),
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: _attendanceRecordsFuture,
                          builder: (context, attendanceSnapshot) {
                            return FutureBuilder<List<Map<String, dynamic>>>(
                              future: _fieldWorkersFuture,
                              builder: (context, workersSnapshot) {
                                if (attendanceSnapshot.connectionState ==
                                        ConnectionState.waiting ||
                                    workersSnapshot.connectionState ==
                                        ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                final attendanceRecords =
                                    attendanceSnapshot.data ?? [];
                                final fieldWorkers = workersSnapshot.data ?? [];
                                final filteredRecords = _filterAttendance(
                                  attendanceRecords,
                                  fieldWorkers,
                                );

                                if (filteredRecords.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'No records',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  );
                                }

                                return screenWidth <= 600
                                    ? _buildMobileAttendanceList(
                                        filteredRecords,
                                        fieldWorkers,
                                      )
                                    : _buildDesktopAttendanceTable(
                                        filteredRecords,
                                        fieldWorkers,
                                      );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 8 : 12),
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

  Widget _buildDesktopAttendanceTable(
    List<Map<String, dynamic>> filteredRecords,
    List<Map<String, dynamic>> fieldWorkers,
  ) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _buildHeaderCell('Worker', flex: 3),
                _buildHeaderCell('Date', flex: 2),
                _buildHeaderCell('Check In', flex: 2),
                _buildHeaderCell('Check Out', flex: 2),
                _buildHeaderCell('Status', flex: 2),
                _buildHeaderCell('Actions', flex: 1),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: filteredRecords.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final record = filteredRecords[index];
                final worker = _resolveWorkerFromRecord(record, fieldWorkers);
                final workerName =
                    '${worker['first_name']} ${worker['last_name']}';
                final statusKey = _statusKeyForRecord(record);
                final statusColor = _statusColor(statusKey);
                final statusLabel = _statusLabelForRecord(record);

                return InkWell(
                  onTap: () => _showEditAttendanceDialog(record, worker),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            workerName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(record['attendance_date'] ?? '—'),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(record['check_in_time'] ?? '—'),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(record['check_out_time'] ?? '—'),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: PopupMenuButton<String>(
                            color: Colors.white,
                            onSelected: (v) {
                              if (v == 'edit') {
                                _showEditAttendanceDialog(record, worker);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 16),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                            ],
                            icon: const Icon(Icons.more_vert, size: 18),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return SupervisorMobileBottomNav(
      activeTab: SupervisorMobileTab.more,
<<<<<<< HEAD
      activeMorePage: 'Attendance',
=======
>>>>>>> parent of df03275 (Revert "push ko na par")
      onSelect: _navigateToPage,
      activeMorePage: 'Attendance',
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

  // Mobile card-based list
  Widget _buildMobileAttendanceList(
    List<Map<String, dynamic>> filteredRecords,
    List<Map<String, dynamic>> fieldWorkers,
  ) {
    return ListView.builder(
      itemCount: filteredRecords.length,
      itemBuilder: (context, index) {
        final record = filteredRecords[index];
        final worker = _resolveWorkerFromRecord(record, fieldWorkers);
        final workerName = '${worker['first_name']} ${worker['last_name']}';
        final initials = workerName
            .split(' ')
            .map((s) => s.isNotEmpty ? s[0] : '')
            .take(2)
            .join();
        final statusKey = _statusKeyForRecord(record);
        final statusColor = _statusColor(statusKey);
        final statusLabel = _statusLabelForRecord(record);

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showEditAttendanceDialog(record, worker),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white,
                        child: Text(
                          initials,
                          style: TextStyle(
                            color: primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              workerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              worker['role'] ?? 'N/A',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
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
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // Details rows
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(record['attendance_date'] as String?),
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      ),
                      const Spacer(),
                      Icon(Icons.login, size: 14, color: Colors.green[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(record['check_in_time'] as String?),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.logout, size: 14, color: Colors.red[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(record['check_out_time'] as String?),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Action button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showEditAttendanceDialog(record, worker),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Attendance'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
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

  // small stat card
  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- DIALOGS (kept from previous implementation, unchanged) ----------

  Color _getActionColor(String action) {
    switch (action) {
      case 'Time In':
        return const Color(0xFFFF6F00);
      case 'Time Out':
        return const Color(0xFF757575);
      case 'Break In':
        return const Color(0xFFFF8F00);
      case 'Break Out':
        return const Color(0xFFBDBDBD);
      default:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'Time In':
        return Icons.login;
      case 'Time Out':
        return Icons.logout;
      case 'Break In':
        return Icons.play_arrow;
      case 'Break Out':
        return Icons.pause;
      default:
        return Icons.access_time;
    }
  }

  void _showActionSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(0),
        content: Container(
          width: 380,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade50, Colors.indigo.shade50],
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primary, Colors.blue.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Action',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Choose attendance action to scan',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildActionButton(context, 'Time In'),
                      const SizedBox(height: 12),
                      _buildActionButton(context, 'Time Out'),
                      const SizedBox(height: 12),
                      _buildActionButton(context, 'Break In'),
                      const SizedBox(height: 12),
                      _buildActionButton(context, 'Break Out'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const SizedBox(
                      width: double.infinity,
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String action) {
    final color = _getActionColor(action);
    final icon = _getActionIcon(action);

    return InkWell(
      onTap: () async {
        final selectedTime = await _pickScanTime();
        if (selectedTime == null) {
          return;
        }
        Navigator.pop(context);
        _showQRScannerDialog(action, selectedTime);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                action,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  void _showQRScannerDialog(String action, String selectedTime) {
    final color = _getActionColor(action);
    final MobileScannerController controller = MobileScannerController();
    bool isHandlingScan = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(0),
        backgroundColor: Colors.transparent,
        content: Container(
          width: 400,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getActionIcon(action),
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              action,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Scan worker QR code • Time: $selectedTime',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Camera Scanner
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color, width: 3),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: MobileScanner(
                          controller: controller,
                          onDetect: (capture) {
                            if (isHandlingScan) return;

                            final List<Barcode> barcodes = capture.barcodes;
                            if (barcodes.isEmpty) {
                              // Nothing decoded yet; keep scanning.
                              return;
                            }

                            for (final barcode in barcodes) {
                              final String? code = barcode.rawValue;
                              if (code == null || code.trim().isEmpty) {
                                continue;
                              }

                              final id = _parseFieldWorkerIdFromQr(code);
                              if (id == null) {
                                // Not a Structura worker QR; keep scanning.
                                continue;
                              }

                              isHandlingScan = true;
                              unawaited(controller.stop());
                              Navigator.pop(context);
                              unawaited(
                                _recordAttendanceFromScan(
                                  action: action,
                                  fieldWorkerId: id,
                                  time: selectedTime,
                                ),
                              );
                              break;
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info,
                                  color: Colors.blue.shade600,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Position the QR code within the frame',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.blue.shade600,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Camera will scan automatically',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Cancel button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        unawaited(controller.stop());
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      // Ensure controller is disposed when dialog closes
      controller.dispose();
    });

    // Ensure the camera starts once the dialog is on-screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(controller.start());
    });
  }

  void _showManualAttendanceDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          String? selectedWorkerId;
          String checkInTime = '';
          String checkOutTime = '';
          String selectedStatus = 'on_site';

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text('Add Attendance'),
            content: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchFieldWorkers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.isEmpty)
                  return const Text('No workers found');

                final workers = snapshot.data!;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Worker',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: selectedWorkerId,
                        hint: const Text('Select worker'),
                        underline: const SizedBox(),
                        isExpanded: true,
                        items: (() {
                          final sortedWorkers = List<Map<String, dynamic>>.from(
                            workers,
                          );
                          sortedWorkers.sort((a, b) {
                            final nameA = '${a['first_name']} ${a['last_name']}'
                                .toLowerCase();
                            final nameB = '${b['first_name']} ${b['last_name']}'
                                .toLowerCase();
                            return nameA.compareTo(nameB);
                          });
                          return sortedWorkers
                              .map(
                                (w) => DropdownMenuItem<String>(
                                  value: w['field_worker_id'].toString(),
                                  child: Text(
                                    '${w['first_name']} ${w['last_name']} - ${w['role']}',
                                  ),
                                ),
                              )
                              .toList();
                        })(),
                        onChanged: (val) =>
                            setState(() => selectedWorkerId = val),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: selectedStatus,
                        underline: const SizedBox(),
                        isExpanded: true,
                        items: ['on_site', 'on_break', 'absent']
                            .map(
                              (status) => DropdownMenuItem<String>(
                                value: status,
                                child: Text(status.replaceAll('_', ' ')),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => selectedStatus = val!),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Check In',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: '07:30',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (v) => checkInTime = v,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Check Out',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: '17:00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (v) => checkOutTime = v,
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedWorkerId != null
                    ? () {
                        final attendanceData = {
                          'field_worker': int.parse(selectedWorkerId!),
                          'status': selectedStatus,
                          'check_in_time': checkInTime.isNotEmpty
                              ? checkInTime
                              : null,
                          'check_out_time': checkOutTime.isNotEmpty
                              ? checkOutTime
                              : null,
                        };
                        _saveAttendance(attendanceData);
                        Navigator.pop(context);
                      }
                    : null,
                style: ElevatedButton.styleFrom(backgroundColor: primary),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditAttendanceDialog(
    Map<String, dynamic> record,
    Map<String, dynamic> worker,
  ) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) {
          String selectedStatus = record["status"] ?? 'absent';
          String checkIn = record['check_in_time'] ?? '';
          String checkOut = record['check_out_time'] ?? '';

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text('Edit Attendance'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Worker: ${worker['first_name']} ${worker['last_name']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: selectedStatus,
                    underline: const SizedBox(),
                    isExpanded: true,
                    items: ['on_site', 'on_break', 'absent']
                        .map(
                          (status) => DropdownMenuItem<String>(
                            value: status,
                            child: Text(status.replaceAll('_', ' ')),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        dialogSetState(() => selectedStatus = val!),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Check In',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    hintText: '07:30',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (v) => checkIn = v,
                  controller: TextEditingController(text: checkIn),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Check Out',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    hintText: '17:00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (v) => checkOut = v,
                  controller: TextEditingController(text: checkOut),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final attendanceData = {
                    'field_worker': record['field_worker'],
                    'status': selectedStatus,
                    'check_in_time': checkIn.isNotEmpty ? checkIn : null,
                    'check_out_time': checkOut.isNotEmpty ? checkOut : null,
                  };
                  _saveAttendance(attendanceData);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: primary),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
