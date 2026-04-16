import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/app_config.dart';
import '../services/auth_service.dart';
import '../services/file_download/file_download.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/sidebar.dart';

class AllWorkforcePage extends StatefulWidget {
  final int projectId;
  final String projectTitle;

  const AllWorkforcePage({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<AllWorkforcePage> createState() => _AllWorkforcePageState();
}

class _WorkforceMember {
  _WorkforceMember({
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.workerId,
    required this.fieldWorkerId,
    required this.raw,
  });

  final String name;
  final String role;
  final String email;
  final String phone;
  final String photoUrl;
  final int? workerId;
  final int? fieldWorkerId;
  final Map<String, dynamic> raw;
  final Set<String> phaseNames = <String>{};
  int assignedSubtaskCount = 0;
}

class _AllWorkforcePageState extends State<AllWorkforcePage> {
  bool _isLoading = true;
  String? _error;
  List<_WorkforceMember> _workers = <_WorkforceMember>[];
  final Map<int, Map<String, dynamic>> _workerDetailsById =
      <int, Map<String, dynamic>>{};
  int? _projectOwnerUserId;

  @override
  void initState() {
    super.initState();
    _loadAssignedWorkers();
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return int.tryParse(value.toString());
  }

  String _textOrEmpty(dynamic value) {
    final s = (value ?? '').toString().trim();
    if (s == 'null') return '';
    return s;
  }

  String _text(dynamic value, {String fallback = 'N/A'}) {
    final s = (value ?? '').toString().trim();
    if (s.isEmpty || s == 'null') return fallback;
    return s;
  }

  String _pickText(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = 'N/A',
  }) {
    for (final key in keys) {
      if (!data.containsKey(key)) continue;
      final value = data[key];
      if (value is Map<String, dynamic>) {
        final nested = _textOrEmpty(
          value['name'] ?? value['label'] ?? value['id'],
        );
        if (nested.isNotEmpty) return nested;
        continue;
      }
      final txt = _textOrEmpty(value);
      if (txt.isNotEmpty) return txt;
    }
    return fallback;
  }

  String _resolveMediaUrl(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty || value == 'null') return '';

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

  Future<void> _loadAssignedWorkers() async {
    try {
      final authUser = AuthService().currentUser;
      final userId = _toInt(authUser?['user_id']);
      final typeOrRole = (authUser?['type'] ?? authUser?['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final supervisorId =
          _toInt(authUser?['supervisor_id']) ??
          ((typeOrRole == 'supervisor') ? userId : null);

      final candidatePhaseUrls = <String>[
        if (userId != null)
          'phases/?project_id=${widget.projectId}&user_id=$userId',
        'phases/?project_id=${widget.projectId}',
      ];

      http.Response? phasesResponse;
      for (final url in candidatePhaseUrls) {
        final response = await http.get(AppConfig.apiUri(url));
        if (response.statusCode == 200) {
          phasesResponse = response;
          break;
        }
      }

      if (phasesResponse == null) {
        setState(() {
          _error = 'Failed to load assigned workers.';
          _isLoading = false;
        });
        return;
      }

      final decoded = jsonDecode(phasesResponse.body);
      final phases = decoded is List<dynamic> ? decoded : <dynamic>[];

      final byKey = <String, _WorkforceMember>{};

      for (final phase in phases) {
        if (phase is! Map<String, dynamic>) continue;

        final phaseName = _text(phase['phase_name'], fallback: 'Unnamed Phase');
        final subtasks = phase['subtasks'] as List<dynamic>? ?? <dynamic>[];

        for (final subtask in subtasks) {
          if (subtask is! Map<String, dynamic>) continue;

          final assignedWorkers =
              subtask['assigned_workers'] as List<dynamic>? ?? <dynamic>[];

          for (final worker in assignedWorkers) {
            if (worker is! Map<String, dynamic>) continue;

            final workerId = _toInt(
              worker['worker_id'] ?? worker['id'] ?? worker['user_id'],
            );
            final fieldWorkerId = _toInt(
              worker['fieldworker_id'] ?? worker['worker_id'] ?? worker['id'],
            );
            final first = _text(worker['first_name'], fallback: '');
            final last = _text(worker['last_name'], fallback: '');
            final composedName = '$first $last'.trim();
            final role = _text(worker['role'], fallback: 'Worker');
            final name = composedName.isEmpty ? role : composedName;

            final key = fieldWorkerId != null
                ? 'fw:$fieldWorkerId'
                : (workerId != null
                      ? 'id:$workerId'
                      : 'name:${name.toLowerCase()}|${role.toLowerCase()}');

            final member = byKey.putIfAbsent(
              key,
              () => _WorkforceMember(
                name: name,
                role: role,
                email: _text(worker['email']),
                phone: _text(worker['phone_number']),
                photoUrl: _resolveMediaUrl(worker['photo']),
                workerId: workerId,
                fieldWorkerId: fieldWorkerId,
                raw: Map<String, dynamic>.from(worker),
              ),
            );

            if (_textOrEmpty(member.raw['email']).isEmpty &&
                _textOrEmpty(worker['email']).isNotEmpty) {
              member.raw['email'] = worker['email'];
            }
            if (_textOrEmpty(member.raw['phone_number']).isEmpty &&
                _textOrEmpty(worker['phone_number']).isNotEmpty) {
              member.raw['phone_number'] = worker['phone_number'];
            }

            member.phaseNames.add(phaseName);
            member.assignedSubtaskCount += 1;
          }
        }
      }

      final workers = byKey.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Preload full worker records so modal values don't fall back to partial
      // assigned_workers payload from phases.
      final fullWorkers = await _fetchProjectWorkersDirectory(
        userId: userId,
        supervisorId: supervisorId,
      );
      for (final item in fullWorkers) {
        final id = _toInt(
          item['fieldworker_id'] ?? item['worker_id'] ?? item['id'],
        );
        if (id != null) {
          _workerDetailsById[id] = Map<String, dynamic>.from(item);
        }
      }
      for (final member in workers) {
        final id =
            member.fieldWorkerId ??
            _toInt(
              member.raw['fieldworker_id'] ??
                  member.raw['worker_id'] ??
                  member.raw['id'],
            );
        if (id != null && _workerDetailsById.containsKey(id)) {
          member.raw.addAll(_workerDetailsById[id]!);
        }
      }

      if (!mounted) return;
      setState(() {
        _workers = workers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load workforce: $e';
        _isLoading = false;
      });
    }
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

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateString;
    }
  }

  String _formatPayrate(dynamic payrate) {
    if (payrate == null) return 'Not set';
    return 'P$payrate/hr';
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return 'Not set';
    final parsed = double.tryParse(value.toString());
    if (parsed == null) return 'Not set';
    return 'P${parsed.toStringAsFixed(2)}';
  }

  String _formatDeductionWithFallback(dynamic totalValue, dynamic minValue) {
    if (totalValue != null) return _formatCurrency(totalValue);
    if (minValue != null) return '${_formatCurrency(minValue)} (minimum)';
    return 'Not set';
  }

  String _buildWorkerQrPayload({required int fieldWorkerId}) {
    return 'structura-fw:$fieldWorkerId';
  }

  int? _parseFieldWorkerIdFromQr(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final strict = RegExp(
      r'(?:structura-fw:)?(\d+)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (strict != null) {
      return int.tryParse(strict.group(1) ?? '');
    }

    final fallback = RegExp(r'(\d+)').firstMatch(value);
    if (fallback != null) {
      return int.tryParse(fallback.group(1) ?? '');
    }

    return null;
  }

  String _timeOfDayToTimeString(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm:00';
  }

  int? _timeStringToMinutes(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.split('.').first;
    final parts = normalized.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return (hour * 60) + minute;
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

        for (final value in decoded.values) {
          if (value is List && value.isNotEmpty) {
            final first = value.first?.toString().trim();
            if (first != null && first.isNotEmpty) {
              return first;
            }
          }
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
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
    final dateStr =
        '${attendanceDate.year}-${attendanceDate.month.toString().padLeft(2, '0')}-${attendanceDate.day.toString().padLeft(2, '0')}';
    final response = await http.get(
      AppConfig.apiUri(
        'attendance/?project_id=${widget.projectId}&field_worker_id=$fieldWorkerId&attendance_date=$dateStr',
      ),
    );
    if (response.statusCode != 200) return null;

    final records = _recordsFromResponse(jsonDecode(response.body));
    if (records.isEmpty) return null;
    return records.first;
  }

  Future<void> _saveAttendance(
    Map<String, dynamic> attendanceData, {
    DateTime? attendanceDate,
  }) async {
    final effectiveDate = attendanceDate ?? DateTime.now();
    final dateStr =
        '${effectiveDate.year}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}';

    final payload = Map<String, dynamic>.from(attendanceData)
      ..['project'] = widget.projectId
      ..['attendance_date'] = dateStr;

    final existingResponse = await http.get(
      AppConfig.apiUri(
        'attendance/?project_id=${widget.projectId}&field_worker_id=${payload['field_worker']}&attendance_date=$dateStr',
      ),
    );
    if (existingResponse.statusCode != 200) {
      throw Exception('Failed to check existing attendance record.');
    }

    final existingRecords = _recordsFromResponse(
      jsonDecode(existingResponse.body),
    );
    if (existingRecords.isNotEmpty) {
      final attendanceId = _toInt(
        existingRecords.first['attendance_id'] ?? existingRecords.first['id'],
      );
      if (attendanceId == null) {
        throw Exception('Existing attendance record has no id.');
      }

      final updateResponse = await http.patch(
        AppConfig.apiUri('attendance/$attendanceId/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (updateResponse.statusCode < 200 || updateResponse.statusCode >= 300) {
        throw Exception(_extractApiErrorMessage(updateResponse));
      }
      return;
    }

    final createResponse = await http.post(
      AppConfig.apiUri('attendance/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (createResponse.statusCode < 200 || createResponse.statusCode >= 300) {
      throw Exception(_extractApiErrorMessage(createResponse));
    }
  }

  Future<String?> _pickAttendanceTime() async {
    final nowDate = DateTime.now();
    final now = TimeOfDay(hour: nowDate.hour, minute: nowDate.minute);
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
            ).colorScheme.copyWith(primary: const Color(0xFFFF6F00)),
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
    try {
      final attendanceData = <String, dynamic>{'field_worker': fieldWorkerId};
      final scanNow = DateTime.now();
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
            const SnackBar(
              content: Text('Time Out must be later than Time In.'),
            ),
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
          break;
      }

      await _saveAttendance(attendanceData, attendanceDate: scanDate);
      if (!mounted) return;
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
        SnackBar(content: Text('Failed to record attendance: $errorMessage')),
      );
    }
  }

  Color _attendanceActionColor(String action) {
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

  IconData _attendanceActionIcon(String action) {
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

  void _showAttendanceActionSelectionDialog() {
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
              colors: [Colors.orange.shade50, Colors.blue.shade50],
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
                      colors: [const Color(0xFFFF6F00), Colors.blue.shade700],
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
                              'Select Attendance Action',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Choose action before scanning worker QR',
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
                      _buildAttendanceActionButton(context, 'Time In'),
                      const SizedBox(height: 12),
                      _buildAttendanceActionButton(context, 'Time Out'),
                      const SizedBox(height: 12),
                      _buildAttendanceActionButton(context, 'Break In'),
                      const SizedBox(height: 12),
                      _buildAttendanceActionButton(context, 'Break Out'),
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
                        textAlign: TextAlign.center,
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
    );
  }

  Widget _buildAttendanceActionButton(BuildContext context, String action) {
    final color = _attendanceActionColor(action);
    final icon = _attendanceActionIcon(action);

    return InkWell(
      onTap: () async {
        final selectedTime = await _pickAttendanceTime();
        if (selectedTime == null) return;
        if (!context.mounted) return;
        Navigator.pop(context);
        _showAttendanceScannerDialog(action, selectedTime);
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

  void _showAttendanceScannerDialog(String action, String selectedTime) {
    final color = _attendanceActionColor(action);
    final controller = MobileScannerController();
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
                          _attendanceActionIcon(action),
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
                              style: const TextStyle(
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

                            final barcodes = capture.barcodes;
                            if (barcodes.isEmpty) return;

                            for (final barcode in barcodes) {
                              final code = barcode.rawValue;
                              if (code == null || code.trim().isEmpty) {
                                continue;
                              }

                              final fieldWorkerId = _parseFieldWorkerIdFromQr(
                                code,
                              );
                              if (fieldWorkerId == null) continue;

                              isHandlingScan = true;
                              unawaited(controller.stop());
                              Navigator.pop(context);
                              unawaited(
                                _recordAttendanceFromScan(
                                  action: action,
                                  fieldWorkerId: fieldWorkerId,
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
                                  Icons.info_outline,
                                  color: Colors.blue.shade700,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Only worker QR codes generated by this app are accepted.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.qr_code,
                                  color: Colors.blue.shade700,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Expected format: structura-fw:<worker_id>',
                                    style: TextStyle(fontSize: 12),
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
      controller.dispose();
    });

    // Delay camera start until after dialog appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(controller.start());
    });
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
              color: statusColor.withOpacity(0.12),
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

  Map<String, dynamic>? _firstRecordFromResponse(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('results') && decoded['results'] is List) {
        final results = decoded['results'] as List<dynamic>;
        if (results.isNotEmpty && results.first is Map) {
          return Map<String, dynamic>.from(results.first as Map);
        }
      }
      return Map<String, dynamic>.from(decoded);
    }

    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      return Map<String, dynamic>.from(decoded.first as Map);
    }

    return null;
  }

  List<Map<String, dynamic>> _recordsFromResponse(dynamic decoded) {
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

    return <Map<String, dynamic>>[];
  }

  Future<int?> _resolveProjectOwnerUserId() async {
    if (_projectOwnerUserId != null) return _projectOwnerUserId;

    final authUser = AuthService().currentUser;
    final authUserId = _toInt(authUser?['user_id']);
    final authProjectId = _toInt(authUser?['project_id']);

    final candidateProjectUrls = <String>[
      if (authUserId != null)
        'projects/${widget.projectId}/?user_id=$authUserId',
      if (authProjectId != null)
        'projects/${widget.projectId}/?project_id=$authProjectId',
      'projects/${widget.projectId}/',
    ];

    for (final url in candidateProjectUrls) {
      final response = await http.get(AppConfig.apiUri(url));
      if (response.statusCode != 200) continue;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) continue;

      final userRaw = decoded['user'];
      final resolved = _toInt(
        userRaw is Map<String, dynamic>
            ? (userRaw['user_id'] ?? userRaw['id'])
            : userRaw,
      );
      if (resolved != null) {
        _projectOwnerUserId = resolved;
        return resolved;
      }
    }

    return null;
  }

  bool _hasRichWorkerData(Map<String, dynamic> data) {
    return data['phone_number'] != null ||
        data['birthdate'] != null ||
        data['payrate'] != null ||
        data['weekly_salary'] != null ||
        data['sss_id'] != null;
  }

  Future<List<Map<String, dynamic>>> _fetchProjectWorkersDirectory({
    required int? userId,
    required int? supervisorId,
  }) async {
    final ownerUserId = await _resolveProjectOwnerUserId();
    final scopedUserId = ownerUserId ?? userId;

    final candidateUrls = <String>[
      'field-workers/?project_id=${widget.projectId}',
      if (scopedUserId != null)
        'field-workers/?project_id=${widget.projectId}&user_id=$scopedUserId',
      if (supervisorId != null)
        'field-workers/?project_id=${widget.projectId}&supervisor_id=$supervisorId',
      if (supervisorId != null) 'field-workers/?supervisor_id=$supervisorId',
    ];

    final mergedById = <int, Map<String, dynamic>>{};
    for (final url in candidateUrls) {
      final response = await http.get(AppConfig.apiUri(url));
      if (response.statusCode != 200) continue;

      final records = _recordsFromResponse(jsonDecode(response.body));
      for (final record in records) {
        final id = _toInt(
          record['fieldworker_id'] ?? record['worker_id'] ?? record['id'],
        );
        if (id != null) {
          mergedById[id] = Map<String, dynamic>.from(record);
        }
      }
    }

    return mergedById.values.toList();
  }

  Future<Map<String, dynamic>> _fetchWorkerDetails(
    _WorkforceMember worker,
  ) async {
    final authUser = AuthService().currentUser;
    final sessionUserId = _toInt(authUser?['user_id']);
    final projectId = widget.projectId;
    final ownerUserId = await _resolveProjectOwnerUserId();
    final scopedUserId = ownerUserId ?? sessionUserId;
    final typeOrRole = (authUser?['type'] ?? authUser?['role'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final supervisorId =
        _toInt(authUser?['supervisor_id']) ??
        ((typeOrRole == 'supervisor') ? sessionUserId : null);

    final fieldWorkerId =
        _toInt(worker.raw['fieldworker_id']) ??
        worker.fieldWorkerId ??
        worker.workerId;
    if (fieldWorkerId == null) {
      return Map<String, dynamic>.from(worker.raw);
    }

    if (_workerDetailsById.containsKey(fieldWorkerId) &&
        _hasRichWorkerData(_workerDetailsById[fieldWorkerId]!)) {
      final merged = Map<String, dynamic>.from(worker.raw)
        ..addAll(_workerDetailsById[fieldWorkerId]!);
      return merged;
    }

    // Fetch exact worker first; this should return the complete DB row.
    final strictDetailUrls = <String>[
      'field-workers/$fieldWorkerId/?project_id=${widget.projectId}',
      if (scopedUserId != null)
        'field-workers/$fieldWorkerId/?project_id=${widget.projectId}&user_id=$scopedUserId',
      if (supervisorId != null)
        'field-workers/$fieldWorkerId/?project_id=${widget.projectId}&supervisor_id=$supervisorId',
      'field-workers/$fieldWorkerId/',
    ];

    for (final url in strictDetailUrls) {
      final response = await http.get(AppConfig.apiUri(url));
      if (response.statusCode != 200) continue;
      final mapped = _firstRecordFromResponse(jsonDecode(response.body));
      if (mapped == null) continue;

      final id = _toInt(
        mapped['fieldworker_id'] ?? mapped['worker_id'] ?? mapped['id'],
      );
      if (id != null) {
        _workerDetailsById[id] = Map<String, dynamic>.from(mapped);
      }

      final merged = Map<String, dynamic>.from(worker.raw)..addAll(mapped);
      if (_hasRichWorkerData(merged)) {
        return merged;
      }
    }

    // Prefer list endpoints with scope first: they are typically less restrictive
    // than detail endpoints for supervisor sessions.
    final candidateListUrls = <String>[
      if (supervisorId != null) 'field-workers/?supervisor_id=$supervisorId',
      if (projectId != null) 'field-workers/?project_id=$projectId',
      if (scopedUserId != null) 'field-workers/?user_id=$scopedUserId',
      'field-workers/',
    ];

    for (final url in candidateListUrls) {
      final response = await http.get(AppConfig.apiUri(url));
      if (response.statusCode != 200) continue;

      final records = _recordsFromResponse(jsonDecode(response.body));
      for (final record in records) {
        final id = _toInt(
          record['fieldworker_id'] ?? record['worker_id'] ?? record['id'],
        );
        if (id == fieldWorkerId) {
          if (id != null) {
            _workerDetailsById[id] = Map<String, dynamic>.from(record);
          }
          final merged = Map<String, dynamic>.from(worker.raw)..addAll(record);
          return merged;
        }
      }
    }

    final candidateUrls = <String>[
      if (supervisorId != null)
        'field-workers/$fieldWorkerId/?supervisor_id=$supervisorId',
      if (projectId != null)
        'field-workers/$fieldWorkerId/?project_id=$projectId',
      if (scopedUserId != null)
        'field-workers/$fieldWorkerId/?user_id=$scopedUserId',
      'field-workers/$fieldWorkerId/',
    ];

    for (final url in candidateUrls) {
      final response = await http.get(AppConfig.apiUri(url));
      if (response.statusCode == 200) {
        final mapped = _firstRecordFromResponse(jsonDecode(response.body));
        if (mapped != null) {
          final id = _toInt(
            mapped['fieldworker_id'] ?? mapped['worker_id'] ?? mapped['id'],
          );
          if (id != null) {
            _workerDetailsById[id] = Map<String, dynamic>.from(mapped);
          }
          final merged = Map<String, dynamic>.from(worker.raw)..addAll(mapped);
          return merged;
        }
      }
    }

    if (projectId != null) {
      final listResponse = await http.get(
        AppConfig.apiUri('field-workers/?project_id=$projectId'),
      );
      if (listResponse.statusCode == 200) {
        final decoded = jsonDecode(listResponse.body);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map<String, dynamic>) continue;
            final id = _toInt(
              item['fieldworker_id'] ?? item['worker_id'] ?? item['id'],
            );
            if (id == fieldWorkerId) {
              if (id != null) {
                _workerDetailsById[id] = Map<String, dynamic>.from(item);
              }
              final merged = Map<String, dynamic>.from(worker.raw)
                ..addAll(item);
              return merged;
            }
          }
        }
      }
    }

    return Map<String, dynamic>.from(worker.raw);
  }

  Future<void> _showWorkerDetailModal(
    BuildContext context,
    _WorkforceMember worker,
  ) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, dynamic> details = Map<String, dynamic>.from(worker.raw);
    try {
      final fetched = await _fetchWorkerDetails(worker);
      details = Map<String, dynamic>.from(details)..addAll(fetched);
    } catch (_) {
      // Keep fallback data from phase payload.
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (!context.mounted) return;
    _showWorkerDetailModalWithData(context, worker, details);
  }

  void _showWorkerDetailModalWithData(
    BuildContext context,
    _WorkforceMember worker,
    Map<String, dynamic> raw,
  ) {
    final roleColor = _roleColor(worker.role);
    final workerName = worker.name;
    final phoneNumber = _pickText(raw, [
      'phone_number',
      'phone',
      'phoneNumber',
    ]);
    final birthdate = _formatDate(
      _pickText(raw, [
        'birthdate',
        'birth_date',
        'date_of_birth',
      ], fallback: ''),
    );
    final payrate = _formatPayrate(raw['payrate'] ?? raw['hourly_payrate']);
    final cashAdvanceBalance = _formatCurrency(
      raw['cash_advance_balance'] ?? raw['cashAdvanceBalance'],
    );
    final deductionPerSalary = _formatCurrency(
      raw['deduction_per_salary'] ?? raw['deductionPerSalary'],
    );
    final dateHired = _formatDate(
      _pickText(raw, ['created_at', 'date_hired', 'dateHired'], fallback: ''),
    );
    final region = _pickText(raw, ['region_name', 'region']);
    final province = _pickText(raw, ['province_name', 'province']);
    final city = _pickText(raw, ['city_name', 'city']);
    final barangay = _pickText(raw, ['barangay_name', 'barangay']);
    final sssDeduction = _formatDeductionWithFallback(
      raw['sss_weekly_total'],
      raw['sss_weekly_min'],
    );
    final philhealthDeduction = _formatDeductionWithFallback(
      raw['philhealth_weekly_total'],
      raw['philhealth_weekly_min'],
    );
    final pagibigDeduction = _formatDeductionWithFallback(
      raw['pagibig_weekly_total'],
      raw['pagibig_weekly_min'],
    );
    final weeklySalary = _formatCurrency(
      raw['weekly_salary'] ?? raw['weeklySalary'],
    );
    final sssWeeklyMin = _formatCurrency(raw['sss_weekly_min']);
    final philhealthWeeklyMin = _formatCurrency(raw['philhealth_weekly_min']);
    final pagibigWeeklyMin = _formatCurrency(raw['pagibig_weekly_min']);
    final sssTopup = _formatCurrency(raw['sss_weekly_topup']);
    final philhealthTopup = _formatCurrency(raw['philhealth_weekly_topup']);
    final pagibigTopup = _formatCurrency(raw['pagibig_weekly_topup']);
    final totalWeeklyDeduction = _formatCurrency(raw['total_weekly_deduction']);
    final netWeeklyPay = _formatCurrency(raw['net_weekly_pay']);
    final fieldWorkerId =
        _toInt(raw['fieldworker_id']) ??
        worker.fieldWorkerId ??
        worker.workerId;

    showDialog(
      context: context,
      builder: (context) {
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
                              'Worker Profile',
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
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: worker.photoUrl.isEmpty
                                ? Icon(Icons.person, size: 56, color: roleColor)
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.network(
                                      worker.photoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.person,
                                        size: 56,
                                        color: roleColor,
                                      ),
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
                              color: roleColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              worker.role,
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
                    const Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Phone', phoneNumber),
                    _buildDetailRow('Birthdate', birthdate),
                    _buildDetailRow('Region', region),
                    _buildDetailRow('Province', province),
                    _buildDetailRow('City', city),
                    _buildDetailRow('Barangay', barangay),
                    _buildDetailRow('SSS Deduction (Weekly)', sssDeduction),
                    _buildDetailRow(
                      'PhilHealth Deduction (Weekly)',
                      philhealthDeduction,
                    ),
                    _buildDetailRow(
                      'Pag-IBIG Deduction (Weekly)',
                      pagibigDeduction,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Work Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Project', widget.projectTitle),
                    _buildDetailRow('Date Hired', dateHired),
                    _buildDetailRow('Payrate (Hourly)', payrate),
                    _buildDetailRow('Cash Advance Balance', cashAdvanceBalance),
                    _buildDetailRow('Deduction per Salary', deductionPerSalary),
                    _buildDetailRow('Weekly Salary', weeklySalary),
                    _buildDetailRow('SSS Weekly Minimum', sssWeeklyMin),
                    _buildDetailRow(
                      'PhilHealth Weekly Minimum',
                      philhealthWeeklyMin,
                    ),
                    _buildDetailRow(
                      'Pag-IBIG Weekly Minimum',
                      pagibigWeeklyMin,
                    ),
                    _buildDetailRow('SSS Top-up', sssTopup),
                    _buildDetailRow('PhilHealth Top-up', philhealthTopup),
                    _buildDetailRow('Pag-IBIG Top-up', pagibigTopup),
                    _buildDetailRow(
                      'Total Weekly Deduction',
                      totalWeeklyDeduction,
                    ),
                    _buildDetailRow('Net Weekly Pay', netWeeklyPay),
                    _buildDetailRow(
                      'Assigned Subtasks',
                      '${worker.assignedSubtaskCount}',
                    ),
                    _buildDetailRowWithStatus('Status', 'Active', Colors.green),
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
                            label: const Text('Download QR'),
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
                          label: const Text('Close'),
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

  Widget _buildAvatar(_WorkforceMember worker) {
    if (worker.photoUrl.isEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade200,
        child: Icon(Icons.person_outline, color: Colors.grey.shade600),
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundImage: NetworkImage(worker.photoUrl),
      backgroundColor: Colors.grey.shade200,
      onBackgroundImageError: (_, __) {},
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildBody(bool isMobile) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: const TextStyle(color: Color(0xFFB91C1C)),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_workers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No workers are assigned to this project yet.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      itemCount: _workers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final worker = _workers[index];
        final roleColor = _roleColor(worker.role);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(worker),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      worker.role,
                      style: TextStyle(
                        fontSize: 13,
                        color: roleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Phone: ${worker.phone}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Phases: ${worker.phaseNames.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Assigned tasks: ${worker.assignedSubtaskCount}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  OutlinedButton(
                    onPressed: () => _showWorkerDetailModal(context, worker),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF6F00),
                      side: const BorderSide(color: Color(0xFFFF6F00)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      'View More',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 1024;
    final isMobile = width < 768;

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
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 12 : 20,
                    12,
                    isMobile ? 12 : 20,
                    8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'All Workforce',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0C1935),
                              ),
                            ),
                            Text(
                              widget.projectTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_isLoading && _error == null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            '${_workers.length} worker${_workers.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isMobile)
                          IconButton(
                            tooltip: 'Mark Attendance',
                            onPressed: _workers.isEmpty
                                ? null
                                : _showAttendanceActionSelectionDialog,
                            icon: const Icon(Icons.qr_code_scanner),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: _workers.isEmpty
                                ? null
                                : _showAttendanceActionSelectionDialog,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Mark Attendance'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6F00),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: _buildBody(isMobile)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
