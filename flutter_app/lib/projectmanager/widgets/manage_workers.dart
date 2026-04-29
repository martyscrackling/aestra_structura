import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../phase_subtask_models.dart';
import '../../services/app_config.dart';
import '../../services/subscription_helper.dart';
import '../../services/auth_service.dart';
import '../modals/add_fieldworker_modal.dart';

/// FK-style JSON may be a bare id or a nested object; avoid treating [Map] as 0.
int _idFromJsonField(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is String) {
    return int.tryParse(v) ?? 0;
  }
  if (v is Map) {
    for (final key in <String>['subtask_id', 'id', 'fieldworker_id']) {
      final inner = v[key];
      if (inner is int) return inner;
      if (inner is String) {
        final p = int.tryParse(inner);
        if (p != null) return p;
      }
    }
  }
  return 0;
}

TimeOfDay? _timeOfDayFromAssignmentField(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  final parts = s.split(':');
  if (parts.length < 2) return null;
  var h = int.tryParse(parts[0]) ?? 0;
  var m = int.tryParse(parts[1].split('.').first) ?? 0;
  if (h < 0) h = 0;
  if (h > 23) h = 23;
  if (m < 0) m = 0;
  if (m > 59) m = 59;
  return TimeOfDay(hour: h, minute: m);
}

class Worker {
  final int workerId;
  final String name;
  final String role;
  final String status;
  final bool isAssignedToOtherProject;
  final List<String> assignedProjectNames;
  final bool isAssignedToOtherSubtaskInThisPhase;
  /// Informational only: worker is already assigned to another subtask in this phase.
  final String? otherSubtaskTitle;
  /// Title of a completed subtask this worker was previously assigned to.
  final String? completedSubtaskTitle;
  final String? imageUrl;

  Worker({
    required this.workerId,
    required this.name,
    required this.role,
    required this.status,
    this.isAssignedToOtherProject = false,
    this.assignedProjectNames = const [],
    this.isAssignedToOtherSubtaskInThisPhase = false,
    this.otherSubtaskTitle,
    this.completedSubtaskTitle,
    this.imageUrl,
  });

  /// Not selectable: busy on another project or on a different subtask in this phase.
  bool get isSelectionBlocked =>
      isAssignedToOtherProject;
}

enum ShiftPreset { morning, afternoon, fullShift, custom }

class WorkerShiftSelection {
  ShiftPreset preset;
  TimeOfDay? start;
  TimeOfDay? end;

  WorkerShiftSelection({required this.preset, this.start, this.end});
}

class ManageWorkersModal extends StatefulWidget {
  final Subtask subtask;
  final Phase phase;

  const ManageWorkersModal({
    super.key,
    required this.subtask,
    required this.phase,
  });

  @override
  State<ManageWorkersModal> createState() => _ManageWorkersModalState();
}

class _ManageWorkersModalState extends State<ManageWorkersModal> {
  late List<Worker> _availableWorkers;
  late List<Worker> _filteredWorkers;
  late Set<int> _selectedWorkerIds;
  late Set<int> _appliedWorkerIds;
  bool _isLoading = true;
  String? _error;
  bool _isSavingAssignments = false;
  String _searchQuery = '';
  String _selectedRole = 'All';
  final Map<int, WorkerShiftSelection> _workerShiftSelections = {};
  ShiftPreset _bulkPreset = ShiftPreset.morning;
  TimeOfDay _bulkCustomStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _bulkCustomEnd = const TimeOfDay(hour: 16, minute: 0);

  final List<String> _roles = [
    'All',
    'Mason',
    'Painter',
    'Electrician',
    'Carpenter',
  ];

  @override
  void initState() {
    super.initState();
    _selectedWorkerIds = {};
    _appliedWorkerIds = {};
    _availableWorkers = [];
    _filteredWorkers = [];
    _fetchFieldWorkers();
  }

  Future<void> _fetchFieldWorkers() async {
    try {
      final currentUser = AuthService().currentUser;
      final currentUserType = (currentUser?['type'] ?? '').toString();
      final isRealUser =
          currentUserType.toLowerCase() == 'user' ||
          (currentUserType.isEmpty &&
              currentUser?['supervisor_id'] == null &&
              currentUser?['client_id'] == null);

      final dynamic rawUserId = currentUser?['user_id'];
      final int? parsedUserId = (isRealUser && rawUserId != null)
          ? (rawUserId is int ? rawUserId : int.tryParse(rawUserId.toString()))
          : null;
      final int projectId = widget.phase.projectId;

      // Fetch all field workers plus phase-wide subtask assignments so we can
      // mark workers who are already on a different subtask in this phase.
      // Unique `_cb` avoids browser caching stale phase lists after a removal (Flutter web).
      final cacheBust = DateTime.now().millisecondsSinceEpoch;
      final fieldWorkersUrl =
          'field-workers/?include_other_projects=true&project_id=$projectId&_cb=$cacheBust';
      final phaseAssignmentsUrl =
          'subtask-assignments/?phase_id=${widget.phase.phaseId}&_cb=$cacheBust';

      print('🔍 Fetching field workers from: $fieldWorkersUrl');
      print('🔍 Fetching phase assignments: $phaseAssignmentsUrl');

      final headers = <String, String>{
        if (parsedUserId != null && parsedUserId > 0)
          'X-User-Id': parsedUserId.toString(),
      };

      final responses = await Future.wait([
        http.get(AppConfig.apiUri(fieldWorkersUrl), headers: headers),
        http.get(AppConfig.apiUri(phaseAssignmentsUrl), headers: headers),
      ]);
      final response = responses[0];
      final assignResponse = responses[1];

      print('✅ Field workers status: ${response.statusCode}');
      print('✅ Phase assignments status: ${assignResponse.statusCode}');

      if (response.statusCode == 200) {
        final Map<int, String> otherSubtaskByWorker = {};
        final Map<int, String> completedSubtaskByWorker = {};
        final Set<int> preSelectedForThisSubtask = {};
        final Map<int, WorkerShiftSelection> existingShiftByWorker = {};
        if (assignResponse.statusCode == 200) {
          try {
            final decodedA = jsonDecode(assignResponse.body);
            final listA = decodedA is List
                ? decodedA
                : (decodedA is Map<String, dynamic> && decodedA['results'] is List
                      ? decodedA['results'] as List<dynamic>
                      : <dynamic>[]);
            final currentSubId = widget.subtask.subtaskId;
            final completedSubtaskIds = widget.phase.subtasks
                .where((s) => s.status.toLowerCase() == 'completed')
                .map((s) => s.subtaskId)
                .toSet();
            for (final row in listA) {
              if (row is! Map<String, dynamic>) continue;
              final stId = _idFromJsonField(row['subtask']);
              final fwId = _idFromJsonField(row['field_worker']);
              if (stId == 0) continue;

              if (stId == currentSubId) {
                if (fwId != 0) {
                  preSelectedForThisSubtask.add(fwId);
                  final a = _timeOfDayFromAssignmentField(row['shift_start']);
                  final b = _timeOfDayFromAssignmentField(row['shift_end']);
                  if (a != null && b != null) {
                    existingShiftByWorker[fwId] = WorkerShiftSelection(
                      preset: _inferShiftPreset(a, b),
                      start: a,
                      end: b,
                    );
                  }
                }
                continue;
              }
              // Workers assigned only to completed subtasks should remain available
              // for reassignment to active subtasks in this phase.
              if (completedSubtaskIds.contains(stId)) {
                if (!completedSubtaskByWorker.containsKey(fwId)) {
                  String completedTitle = 'Completed subtask';
                  for (final s in widget.phase.subtasks) {
                    if (s.subtaskId == stId) {
                      completedTitle = s.title;
                      break;
                    }
                  }
                  completedSubtaskByWorker[fwId] = completedTitle;
                }
                continue;
              }
              if (fwId == 0) continue;
              if (otherSubtaskByWorker.containsKey(fwId)) continue;
              String title = 'Another subtask';
              for (final s in widget.phase.subtasks) {
                if (s.subtaskId == stId) {
                  title = s.title;
                  break;
                }
              }
              otherSubtaskByWorker[fwId] = title;
            }
          } catch (e) {
            print('⚠️ Could not parse phase assignments: $e');
          }
        } else {
          print('⚠️ Phase assignments not loaded (${assignResponse.statusCode})');
        }

        final decoded = jsonDecode(response.body);
        final parsed = decoded is List
            ? decoded
            : (decoded is Map<String, dynamic> && decoded['results'] is List
                  ? decoded['results'] as List<dynamic>
                  : <dynamic>[]);

        print('📊 Field workers fetched: ${parsed.length}');

        setState(() {
          _selectedWorkerIds = <int>{};
          _appliedWorkerIds = Set<int>.from(preSelectedForThisSubtask);
          _workerShiftSelections
            ..clear()
            ..addAll(existingShiftByWorker);
          for (final workerId in _appliedWorkerIds) {
            _workerShiftSelections.putIfAbsent(
              workerId,
              () => _defaultShiftSelection(),
            );
          }
          _availableWorkers = parsed
              .map((json) {
                final rawId = json['fieldworker_id'] ?? json['id'];
                final workerId = rawId is int
                    ? rawId
                    : int.tryParse(rawId?.toString() ?? '') ?? 0;

                final assignedProjects = json['assigned_projects'];
                final List<String> assignedProjectNames = [];
                if (assignedProjects is List) {
                  for (final project in assignedProjects.cast<dynamic>()) {
                    if (project is! Map<String, dynamic>) continue;
                    final assignedProjectIdRaw = project['project_id'];
                    final assignedProjectId = assignedProjectIdRaw is int
                        ? assignedProjectIdRaw
                        : int.tryParse(assignedProjectIdRaw?.toString() ?? '');
                    if (assignedProjectId == projectId) continue;

                    final projectName = project['project_name']
                        ?.toString()
                        .trim();

                    if (projectName == null || projectName.isEmpty) continue;

                    if (!assignedProjectNames.contains(projectName)) {
                      assignedProjectNames.add(projectName);
                    }
                  }
                }

                final assignmentStatus =
                    (json['assignment_status'] ?? 'Available').toString();
                final isAssignedToOtherProject =
                    assignmentStatus.toLowerCase() == 'assigned';

                final onOtherSubtask = otherSubtaskByWorker[workerId];
                final onCompletedSubtask = completedSubtaskByWorker[workerId];

                return Worker(
                  workerId: workerId,
                  name: '${json['first_name']} ${json['last_name']}',
                  role: json['role'] ?? 'Field Worker',
                  status: assignmentStatus,
                  isAssignedToOtherProject: isAssignedToOtherProject,
                  assignedProjectNames: assignedProjectNames,
                  isAssignedToOtherSubtaskInThisPhase: onOtherSubtask != null,
                  otherSubtaskTitle: onOtherSubtask,
                  completedSubtaskTitle: onCompletedSubtask,
                );
              })
              .where((worker) => worker.workerId > 0)
              .toList();
          _filteredWorkers = _availableWorkers
              .where((w) => !_appliedWorkerIds.contains(w.workerId))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load field workers';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching field workers: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleWorker(Worker worker) {
    if (worker.isSelectionBlocked) {
      return;
    }
    setState(() {
      if (_selectedWorkerIds.contains(worker.workerId)) {
        _selectedWorkerIds.remove(worker.workerId);
        _workerShiftSelections.remove(worker.workerId);
      } else {
        _selectedWorkerIds.add(worker.workerId);
        _workerShiftSelections.putIfAbsent(
          worker.workerId,
          () => _defaultShiftSelection(),
        );
      }
    });
  }

  void _filterWorkers() {
    setState(() {
      _filteredWorkers = _availableWorkers.where((worker) {
        final matchesSearch =
            worker.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            worker.role.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesRole =
            _selectedRole == 'All' || worker.role == _selectedRole;
        final notApplied = !_appliedWorkerIds.contains(worker.workerId);
        return matchesSearch && matchesRole && notApplied;
      }).toList();
    });
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatTimeForApi(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  bool _isValidShift(TimeOfDay? start, TimeOfDay? end) {
    if (start == null || end == null) {
      return false;
    }
    final startMinutes = (start.hour * 60) + start.minute;
    final endMinutes = (end.hour * 60) + end.minute;
    // Allow overnight shifts (e.g., 8:00 PM -> 3:00 AM).
    // Only reject identical times, which are ambiguous for scheduling.
    return startMinutes != endMinutes;
  }

  bool _isOvernightShift(TimeOfDay? start, TimeOfDay? end) {
    if (start == null || end == null) return false;
    final startMinutes = (start.hour * 60) + start.minute;
    final endMinutes = (end.hour * 60) + end.minute;
    return endMinutes < startMinutes;
  }

  ShiftPreset _inferShiftPreset(TimeOfDay start, TimeOfDay end) {
    if (start.hour == 8 &&
        start.minute == 0 &&
        end.hour == 12 &&
        end.minute == 0) {
      return ShiftPreset.morning;
    }
    if (start.hour == 12 &&
        start.minute == 0 &&
        end.hour == 16 &&
        end.minute == 0) {
      return ShiftPreset.afternoon;
    }
    if (start.hour == 8 &&
        start.minute == 0 &&
        end.hour == 16 &&
        end.minute == 0) {
      return ShiftPreset.fullShift;
    }
    return ShiftPreset.custom;
  }

  WorkerShiftSelection _defaultShiftSelection() {
    return WorkerShiftSelection(
      preset: ShiftPreset.morning,
      start: const TimeOfDay(hour: 8, minute: 0),
      end: const TimeOfDay(hour: 12, minute: 0),
    );
  }

  String _presetLabel(ShiftPreset preset) {
    switch (preset) {
      case ShiftPreset.morning:
        return 'Morning (8:00 AM - 12:00 PM)';
      case ShiftPreset.afternoon:
        return 'Afternoon (12:00 PM - 4:00 PM)';
      case ShiftPreset.fullShift:
        return 'Full Shift (8:00 AM - 4:00 PM)';
      case ShiftPreset.custom:
        return 'Custom';
    }
  }

  void _setPresetForWorker(int workerId, ShiftPreset preset) {
    final current =
        _workerShiftSelections[workerId] ?? _defaultShiftSelection();
    switch (preset) {
      case ShiftPreset.morning:
        _workerShiftSelections[workerId] = WorkerShiftSelection(
          preset: preset,
          start: const TimeOfDay(hour: 8, minute: 0),
          end: const TimeOfDay(hour: 12, minute: 0),
        );
        break;
      case ShiftPreset.afternoon:
        _workerShiftSelections[workerId] = WorkerShiftSelection(
          preset: preset,
          start: const TimeOfDay(hour: 12, minute: 0),
          end: const TimeOfDay(hour: 16, minute: 0),
        );
        break;
      case ShiftPreset.fullShift:
        _workerShiftSelections[workerId] = WorkerShiftSelection(
          preset: preset,
          start: const TimeOfDay(hour: 8, minute: 0),
          end: const TimeOfDay(hour: 16, minute: 0),
        );
        break;
      case ShiftPreset.custom:
        _workerShiftSelections[workerId] = WorkerShiftSelection(
          preset: preset,
          start: current.start ?? const TimeOfDay(hour: 8, minute: 0),
          end: current.end ?? const TimeOfDay(hour: 16, minute: 0),
        );
        break;
    }
  }

  Future<void> _pickCustomShiftTime({
    required int workerId,
    required bool isStart,
  }) async {
    final current = _workerShiftSelections[workerId] ?? _defaultShiftSelection();
    final initialTime = isStart
        ? (current.start ?? const TimeOfDay(hour: 8, minute: 0))
        : (current.end ?? const TimeOfDay(hour: 16, minute: 0));
    final picked = await showTimePicker(context: context, initialTime: initialTime);
    if (picked == null || !mounted) return;
    setState(() {
      final next = _workerShiftSelections[workerId] ?? _defaultShiftSelection();
      _workerShiftSelections[workerId] = WorkerShiftSelection(
        preset: ShiftPreset.custom,
        start: isStart ? picked : next.start,
        end: isStart ? next.end : picked,
      );
    });
  }

  Future<void> _pickBulkCustomTime({required bool isStart}) async {
    final initialTime = isStart ? _bulkCustomStart : _bulkCustomEnd;
    final picked = await showTimePicker(context: context, initialTime: initialTime);
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _bulkCustomStart = picked;
      } else {
        _bulkCustomEnd = picked;
      }
    });
  }

  void _applyBulkShiftToSelected() {
    final selectedWorkers = _availableWorkers
        .where(
          (w) => _selectedWorkerIds.contains(w.workerId) && !w.isSelectionBlocked,
        )
        .toList();
    if (selectedWorkers.isEmpty) return;

    if (_bulkPreset == ShiftPreset.custom &&
        !_isValidShift(_bulkCustomStart, _bulkCustomEnd)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Custom shift is invalid (start and end are the same).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      for (final worker in selectedWorkers) {
        if (_bulkPreset == ShiftPreset.custom) {
          _workerShiftSelections[worker.workerId] = WorkerShiftSelection(
            preset: ShiftPreset.custom,
            start: _bulkCustomStart,
            end: _bulkCustomEnd,
          );
        } else {
          _setPresetForWorker(worker.workerId, _bulkPreset);
        }
        _appliedWorkerIds.add(worker.workerId);
      }
      _selectedWorkerIds.removeWhere(_appliedWorkerIds.contains);
    });
    _filterWorkers();
  }

  void _removeAppliedWorker(int workerId) {
    setState(() {
      _appliedWorkerIds.remove(workerId);
      _selectedWorkerIds.remove(workerId);
      _workerShiftSelections.remove(workerId);
    });
    _filterWorkers();
  }

  void _saveAssignments() async {
    if (_isSavingAssignments) return;

    final workerIdsToSave = <int>{..._appliedWorkerIds, ..._selectedWorkerIds};
    if (workerIdsToSave.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSavingAssignments = true);
    try {
      final userId = AuthService().currentUser?['user_id'];
      final userQ = userId != null ? 'user_id=$userId&' : '';

      // DRF list URLs do not support DELETE; we must use the `for-subtask` action
      // so old rows are removed before re-inserting (avoids unique 400s).
      final deleteResponse = await http.delete(
        AppConfig.apiUri(
          'subtask-assignments/for-subtask/?${userQ}subtask_id=${widget.subtask.subtaskId}',
        ),
      );

      if (!mounted) return;

      // Check for subscription expiry on delete
      if (SubscriptionHelper.handleResponse(context, deleteResponse)) {
        return;
      }

      if (deleteResponse.statusCode < 200 || deleteResponse.statusCode >= 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not clear previous workers (${deleteResponse.statusCode}).',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create assignments payload
      final assignments = workerIdsToSave.map((workerId) {
        final shift = _workerShiftSelections[workerId];
        if (shift == null || !_isValidShift(shift.start, shift.end)) {
          throw Exception('Please set a valid shift for every selected worker.');
        }
        return {
          'subtask': widget.subtask.subtaskId,
          'field_worker': workerId,
          'shift_start': _formatTimeForApi(shift.start!),
          'shift_end': _formatTimeForApi(shift.end!),
        };
      }).toList();

      print('📤 Saving assignments: $assignments');

      final postPath = userId != null
          ? 'subtask-assignments/?user_id=$userId'
          : 'subtask-assignments/';
      final response = await http.post(
        AppConfig.apiUri(postPath),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(assignments),
      );

      if (!mounted) return;

      // Check for subscription expiry on post
      if (SubscriptionHelper.handleResponse(context, response)) {
        return;
      }

      print('✅ Assignment response: ${response.statusCode}');
      print('✅ Assignment body: ${response.body}');

      final ok = response.statusCode >= 200 && response.statusCode < 300;
      if (ok) {
        final verify = await http.get(
          AppConfig.apiUri(
            'subtask-assignments/?subtask_id=${widget.subtask.subtaskId}&_cb=${DateTime.now().millisecondsSinceEpoch}',
          ),
        );
        if (!mounted) return;
        if (verify.statusCode == 200) {
          final decoded = jsonDecode(verify.body);
          final rows = decoded is List
              ? decoded
              : (decoded is Map<String, dynamic> && decoded['results'] is List
                    ? decoded['results'] as List<dynamic>
                    : <dynamic>[]);
          if (rows.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Assignment save did not persist. Please try again.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }

        Navigator.pop(context, workerIdsToSave.toList());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${workerIdsToSave.length} worker${workerIdsToSave.length > 1 ? 's' : ''} assigned successfully',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        var detail = response.body;
        if (detail.length > 180) {
          detail = '${detail.substring(0, 180)}…';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to assign workers (HTTP ${response.statusCode}) $detail',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error saving assignments: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingAssignments = false);
      }
    }
  }

  Widget _buildSelectedShiftAssignmentTable() {
    if (_appliedWorkerIds.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selected Worker Shift Assignment',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0C1935),
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2.3),
                1: FlexColumnWidth(2.1),
                2: FlexColumnWidth(2.6),
                3: FlexColumnWidth(1.2),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text(
                        'Worker',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text(
                        'Shift Type',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text(
                        'Time / Schedule',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text(
                        'Action',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
                ...(() {
                  final selectedWorkers = _availableWorkers
                      .where(
                        (w) =>
                            _appliedWorkerIds.contains(w.workerId) &&
                            !w.isSelectionBlocked,
                      )
                      .toList();

                  return selectedWorkers.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final worker = entry.value;
                    final shift = _workerShiftSelections[worker.workerId] ??
                        _defaultShiftSelection();
                    final isCustom = shift.preset == ShiftPreset.custom;
                    final isValid = _isValidShift(shift.start, shift.end);
                    final rowBg =
                        idx.isEven ? const Color(0xFFFFFFFF) : const Color(0xFFFCFDFE);

                    return TableRow(
                      decoration: BoxDecoration(color: rowBg),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Text(
                            worker.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            _presetLabel(shift.preset),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isOvernightShift(shift.start, shift.end)
                                    ? '${_formatTime(shift.start!)} - ${_formatTime(shift.end!)} (next day)'
                                    : '${_formatTime(shift.start!)} - ${_formatTime(shift.end!)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF475569),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (!isValid)
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Invalid start/end.',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _removeAppliedWorker(worker.workerId),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red[700],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.remove_circle_outline, size: 16),
                              label: const Text(
                                'Remove',
                                style: TextStyle(fontSize: 11.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  });
                })(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.phase.isWorkerAssignmentLocked) {
      return AlertDialog(
        title: const Text('Cannot assign workers'),
        content: const Text(
          'This phase is closed for new or changed subtask assignments (the phase is '
          'completed, or every subtask is already completed). Use the people icon to '
          'view who was assigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Assign Field Workers',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0C1935),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Subtask: ${widget.subtask.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        color: const Color(0xFF6B7280),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Worker list
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search bar
                    TextField(
                      onChanged: (value) {
                        _searchQuery = value;
                        _filterWorkers();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search workers by name or role...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFFF7A18),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Role filter chips
                    Row(
                      children: [
                        const Text(
                          'Filter by role:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ..._roles.map((role) {
                                final isSelected = _selectedRole == role;
                                return FilterChip(
                                  label: Text(role),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedRole = role;
                                      _filterWorkers();
                                    });
                                  },
                                  backgroundColor: Colors.white,
                                  selectedColor: const Color(0xFFFFF2E8),
                                  checkmarkColor: const Color(0xFFFF7A18),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? const Color(0xFFFF7A18)
                                        : const Color(0xFF6B7280),
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                  side: BorderSide(
                                    color: isSelected
                                        ? const Color(0xFFFF7A18)
                                        : const Color(0xFFE5E7EB),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                );
                              }),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 0),
                                child: ActionChip(
                                  onPressed: () async {
                                    final result = await showDialog(
                                      context: context,
                                      builder: (context) =>
                                          AddFieldWorkerModal(
                                            workerType: 'Field Worker',
                                            projectId: widget.phase.projectId,
                                          ),
                                    );
                                    if (result == true) {
                                      _fetchFieldWorkers();
                                    }
                                  },
                                  avatar: const Icon(
                                    Icons.add,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Create Worker',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  backgroundColor: const Color(0xFFFF7A18),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Available Field Workers',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_error != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Error: $_error',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.red[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_filteredWorkers.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty ||
                                        _selectedRole != 'All'
                                    ? 'No workers match your filters'
                                    : 'No workers available',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _filteredWorkers.map((worker) {
                          final selected = _selectedWorkerIds.contains(
                            worker.workerId,
                          );
                          return _WorkerChecklistItem(
                            worker: worker,
                            isSelected: selected,
                            onChanged: (value) {
                              _toggleWorker(worker);
                            },
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                    if (_selectedWorkerIds.isNotEmpty || _appliedWorkerIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                          border: const Border(
                            left: BorderSide(
                              color: Color(0xFF10B981),
                              width: 4,
                            ),
                          ),
                        ),
                        child: Text(
                          '${_appliedWorkerIds.length} applied • ${_selectedWorkerIds.length} selected',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (_selectedWorkerIds.isNotEmpty || _appliedWorkerIds.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bulk Shift Assignment',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<ShiftPreset>(
                                    value: _bulkPreset,
                                    isExpanded: true,
                                    isDense: true,
                                    decoration: InputDecoration(
                                      labelText: 'Shift Type',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 9,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    items: ShiftPreset.values
                                        .map(
                                          (preset) => DropdownMenuItem(
                                            value: preset,
                                            child: Text(
                                              _presetLabel(preset),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (preset) {
                                      if (preset == null) return;
                                      setState(() {
                                        _bulkPreset = preset;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _selectedWorkerIds.isNotEmpty
                                      ? _applyBulkShiftToSelected
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0EA5E9),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Apply to selected'),
                                ),
                              ],
                            ),
                            if (_bulkPreset == ShiftPreset.custom) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          _pickBulkCustomTime(isStart: true),
                                      child: Text(
                                        'Start: ${_formatTime(_bulkCustomStart)}',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          _pickBulkCustomTime(isStart: false),
                                      child: Text(
                                        'End: ${_formatTime(_bulkCustomEnd)}',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSelectedShiftAssignmentTable(),
                    ],
                  ],
                ),
              ),
            ),
            // Footer buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0C1935),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed:
                        (!_isSavingAssignments &&
                                (_selectedWorkerIds.isNotEmpty ||
                                    _appliedWorkerIds.isNotEmpty))
                        ? _saveAssignments
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A18),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: _isSavingAssignments
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Assign Workers'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerChecklistItem extends StatelessWidget {
  final Worker worker;
  final bool isSelected;
  final ValueChanged<bool?> onChanged;

  const _WorkerChecklistItem({
    required this.worker,
    required this.isSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final assignedProjectsText = worker.assignedProjectNames.join(' • ');
    final blockedOtherSubtask = worker.isAssignedToOtherSubtaskInThisPhase;
    final hasOtherProject = worker.isAssignedToOtherProject;
    final hasCompletedHistory = (worker.completedSubtaskTitle ?? '').isNotEmpty;
    final isBusy = worker.isSelectionBlocked;
    final String statusLabel;
    if (blockedOtherSubtask) {
      final t = worker.otherSubtaskTitle;
      statusLabel = t != null && t.isNotEmpty
          ? 'Also on subtask: $t'
          : 'Also on another subtask in this phase';
    } else if (hasOtherProject) {
      statusLabel = assignedProjectsText.isNotEmpty
          ? assignedProjectsText
          : 'Assigned to another project';
    } else {
      statusLabel = 'Available';
    }

    final statusBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isBusy
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFE5F8ED),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        statusLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isBusy
              ? const Color(0xFFDC2626)
              : const Color(0xFF10B981),
        ),
      ),
    );

    final completedHistoryBadge = hasCompletedHistory
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Previously assigned (completed): ${worker.completedSubtaskTitle}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D4ED8),
              ),
            ),
          )
        : null;

    return Opacity(
      opacity: isBusy && !isSelected ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFF2E8) : Colors.white,
        border: Border.all(
          color: isSelected ? const Color(0xFFFF7A18) : const Color(0xFFE5E7EB),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: isBusy ? null : onChanged,
              activeColor: const Color(0xFFFF7A18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worker.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0C1935),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    worker.role,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              fit: FlexFit.tight,
              child: Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: hasOtherProject
                      ? Tooltip(
                          message: assignedProjectsText,
                          child: statusBadge,
                        )
                      : blockedOtherSubtask
                      ? Tooltip(
                          message: statusLabel,
                          child: statusBadge,
                        )
                      : (completedHistoryBadge ?? statusBadge),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
