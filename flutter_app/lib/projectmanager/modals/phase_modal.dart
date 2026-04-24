import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/app_config.dart';
import '../../services/budget_service.dart';
import '../../services/subscription_helper.dart';
import '../../services/auth_service.dart';
import 'add_fieldworker_modal.dart';

class PhaseModal extends StatefulWidget {
  final String projectTitle;
  final int projectId;

  const PhaseModal({
    super.key,
    required this.projectTitle,
    required this.projectId,
  });

  @override
  State<PhaseModal> createState() => _PhaseModalState();
}

class _PhaseModalState extends State<PhaseModal> {
  final _formKey = GlobalKey<FormState>();

  final _descriptionController = TextEditingController();
  final _daysDurationController = TextEditingController();
  final _allocatedBudgetController = TextEditingController();
  final _customPhaseController = TextEditingController();

  String? _selectedPhase;
  final List<TextEditingController> _subtaskControllers = [];
  final List<_SubtaskWorkerDraft> _subtaskWorkerDrafts = [];
  List<String> _existingPhases = []; // Phase names already in database

  int? _projectDurationDays;
  int _existingPhasesDurationDays = 0;
  String? _durationWarning;
  bool _showSubtaskError = false;
  bool _showWorkerRequiredError = false;
  bool _useCustomPhase = false;
  bool _isLoadingExistingPhases = true;
  bool _isLoadingBudget = true;
  /// From `/projects/{id}/budget-summary/` (project total and sum of existing phases).
  double? _projectTotalBudget;
  double _otherPhasesAllocated = 0;
  String? _budgetWarning;

  final List<String> _phases = [
    'PHASE 1 - Pre-Construction Phase',
    'PHASE 2 - Design Phase',
    'PHASE 3 - Procurement Phase',
    'PHASE 4 - Construction Phase',
    'PHASE 5 - Testing & Commissioning Phase',
    'PHASE 6 - Turnover / Close-Out Phase',
    'PHASE 7 - Post-Construction / Operation Phase',
  ];

  @override
  void initState() {
    super.initState();
    _subtaskControllers.add(TextEditingController());
    _subtaskWorkerDrafts.add(_SubtaskWorkerDraft.empty());
    _fetchProjectDuration();
    _fetchExistingPhases();
    _fetchBudgetForAllocation();
  }

  Future<void> _fetchProjectDuration() async {
    try {
      final response = await http.get(
        AppConfig.apiUri('projects/${widget.projectId}/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final raw = data['duration_days'];
        final parsed = (raw as num?)?.toInt();
        if (!mounted) return;
        setState(() {
          _projectDurationDays = parsed;
        });
        _recomputeDurationWarning();
      }
    } catch (e) {
      // Silently fail; modal can still work without duration validation.
      // ignore: avoid_print
      print('Error fetching project duration: $e');
    }
  }

  Future<void> _fetchBudgetForAllocation() async {
    try {
      final summary = await BudgetService.getBudgetSummary(
        projectId: widget.projectId,
      );
      if (!mounted) return;
      setState(() {
        _projectTotalBudget = (summary['total_budget'] as num?)?.toDouble();
        _otherPhasesAllocated =
            (summary['total_allocated'] as num?)?.toDouble() ?? 0.0;
        _isLoadingBudget = false;
      });
      _recomputeBudgetWarning();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBudget = false;
        });
      }
      // ignore: avoid_print
      print('Error fetching budget summary: $e');
    }
  }

  /// Room left in the project budget for *this* new phase (others already counted).
  double? get _roomLeftForNewPhase {
    final t = _projectTotalBudget;
    if (t == null) return null;
    return (t - _otherPhasesAllocated).clamp(0.0, double.infinity);
  }

  /// Null when the field is empty or not a number (use after validation).
  double? _parseAllocAmount() {
    final raw = _allocatedBudgetController.text.trim().replaceAll(',', '');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  void _recomputeBudgetWarning() {
    setState(() {
      _budgetWarning = _computeBudgetWarningSync();
    });
  }

  String? _computeBudgetWarningSync() {
    final max = _roomLeftForNewPhase;
    if (max == null) return null;
    final v = _parseAllocAmount();
    if (v == null) return null;
    if (v > max) {
      return 'Exceeds available budget for a new phase. You can assign up to ₱${max.toStringAsFixed(2)}.';
    }
    return null;
  }

  Future<void> _fetchExistingPhases() async {
    try {
      final response = await http.get(
        AppConfig.apiUri('phases/?project_id=${widget.projectId}'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        int usedDays = 0;
        for (final item in data) {
          final phase = item as Map<String, dynamic>;
          final d = phase['days_duration'];
          usedDays += (d as num?)?.toInt() ?? 0;
        }
        setState(() {
          _existingPhases = data
              .map((phase) => phase['phase_name'] as String)
              .toList();
          _existingPhasesDurationDays = usedDays;
          _isLoadingExistingPhases = false;
        });

        _recomputeDurationWarning();
      }
    } catch (e) {
      // Silently fail - user can still add phases
      setState(() {
        _isLoadingExistingPhases = false;
      });
      // ignore: avoid_print
      print('Error fetching existing phases: $e');
    }
  }

  static const String _kScheduleExhaustedMessage =
      'All project days are already allocated. Increase the project duration or adjust an existing phase before adding a new phase.';

  /// True when the sum of existing phase days has used the full project duration
  /// (or more). In that case no new phase may be added.
  bool get _isScheduleExhausted {
    final p = _projectDurationDays;
    if (p == null) return false;
    return p - _existingPhasesDurationDays <= 0;
  }

  String? _computeDurationWarningSync() {
    final projectDays = _projectDurationDays;
    if (projectDays == null) {
      return null;
    }

    final remainingBeforeNew = projectDays - _existingPhasesDurationDays;
    if (remainingBeforeNew <= 0) {
      return _kScheduleExhaustedMessage;
    }

    final enteredDays = int.tryParse(_daysDurationController.text.trim());
    if (enteredDays == null) {
      return null;
    }
    if (enteredDays <= 0) {
      return 'Days duration must be greater than 0.';
    }

    final total = _existingPhasesDurationDays + enteredDays;
    if (total > projectDays) {
      return 'Not valid: phase duration exceeds project duration. Remaining: $remainingBeforeNew days.';
    }
    return null;
  }

  void _recomputeDurationWarning() {
    setState(() {
      _durationWarning = _computeDurationWarningSync();
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _daysDurationController.dispose();
    _allocatedBudgetController.dispose();
    _customPhaseController.dispose();
    for (var controller in _subtaskControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addSubtask() {
    setState(() {
      _subtaskControllers.add(TextEditingController());
      _subtaskWorkerDrafts.add(_SubtaskWorkerDraft.empty());
    });
  }

  void _removeSubtask(int index) {
    setState(() {
      _subtaskControllers[index].dispose();
      _subtaskControllers.removeAt(index);
      _subtaskWorkerDrafts.removeAt(index);
    });
  }

  void _reorderSubtasks(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final controller = _subtaskControllers.removeAt(oldIndex);
      _subtaskControllers.insert(newIndex, controller);
      final draft = _subtaskWorkerDrafts.removeAt(oldIndex);
      _subtaskWorkerDrafts.insert(newIndex, draft);
    });
  }

  Future<void> _openAssignWorkersForSubtask(int index) async {
    final title = _subtaskControllers[index].text.trim();
    final currentDraft = _subtaskWorkerDrafts[index];
    final blockedByOtherSubtasks = <int>{};
    for (int i = 0; i < _subtaskWorkerDrafts.length; i++) {
      if (i == index) continue;
      blockedByOtherSubtasks.addAll(_subtaskWorkerDrafts[i].workerIds);
    }

    final result = await showDialog<_SubtaskWorkerDraft>(
      context: context,
      builder: (_) => _AssignWorkersForDraftSubtaskModal(
        projectId: widget.projectId,
        subtaskTitle: title.isEmpty ? 'Subtask ${index + 1}' : title,
        initialDraft: currentDraft,
        blockedWorkerIds: blockedByOtherSubtasks,
      ),
    );
    if (result == null) return;
    setState(() {
      _subtaskWorkerDrafts[index] = result;
    });
  }

  Future<void> _saveNewSubtaskAssignments(Map<String, dynamic> phaseJson) async {
    final createdSubtasksRaw = (phaseJson['subtasks'] as List?) ?? const [];
    final createdByTitle = <String, List<int>>{};
    for (final raw in createdSubtasksRaw) {
      if (raw is! Map) continue;
      final map = raw.cast<String, dynamic>();
      final id = map['subtask_id'];
      final title = (map['title'] ?? '').toString().trim();
      if (id is! int || title.isEmpty) continue;
      createdByTitle.putIfAbsent(title, () => <int>[]).add(id);
    }

    final payload = <Map<String, dynamic>>[];
    for (int i = 0; i < _subtaskControllers.length; i++) {
      final title = _subtaskControllers[i].text.trim();
      final draft = _subtaskWorkerDrafts[i];
      if (title.isEmpty || draft.workerIds.isEmpty) continue;
      final queue = createdByTitle[title];
      if (queue == null || queue.isEmpty) continue;
      final subtaskId = queue.removeAt(0);
      for (final workerId in draft.workerIds) {
        payload.add({
          'subtask': subtaskId,
          'field_worker': workerId,
          'shift_start': draft.shiftStartApi,
          'shift_end': draft.shiftEndApi,
        });
      }
    }

    if (payload.isEmpty) return;

    final dynamic rawUserId = AuthService().currentUser?['user_id'];
    final int? userId = rawUserId is int
        ? rawUserId
        : int.tryParse(rawUserId?.toString() ?? '');
    final postPath = (userId != null && userId > 0)
        ? 'subtask-assignments/?user_id=$userId'
        : 'subtask-assignments/';

    final assignResponse = await http.post(
      AppConfig.apiUri(postPath),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (!mounted) return;
    if (SubscriptionHelper.handleResponse(context, assignResponse)) {
      return;
    }
    // Bulk create may return 201; some proxies or older handlers may return 200.
    final assignOk = assignResponse.statusCode >= 200 &&
        assignResponse.statusCode < 300;
    if (!assignOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Phase saved, but some worker assignments were not saved '
            '(HTTP ${assignResponse.statusCode}).',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  String _formatMoney(double v) {
    return v.toStringAsFixed(2);
  }

  bool _isLoading = false;

  Future<void> _submitPhase() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate custom phase if being used
    if (_useCustomPhase) {
      final customPhase = _customPhaseController.text.trim();
      if (customPhase.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a custom phase name'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Validate that at least one subtask is provided
    bool hasSubtask = _subtaskControllers.any((controller) => controller.text.trim().isNotEmpty);
    if (!hasSubtask) {
      setState(() {
        _showSubtaskError = true;
        _showWorkerRequiredError = false;
      });
      return;
    }

    bool hasMissingWorkerAssignment = false;
    for (int i = 0; i < _subtaskControllers.length; i++) {
      final title = _subtaskControllers[i].text.trim();
      if (title.isEmpty) continue;
      if (_subtaskWorkerDrafts[i].workerIds.isEmpty) {
        hasMissingWorkerAssignment = true;
        break;
      }
    }
    if (hasMissingWorkerAssignment) {
      setState(() {
        _showSubtaskError = false;
        _showWorkerRequiredError = true;
      });
      return;
    }

    setState(() {
      _showSubtaskError = false;
      _showWorkerRequiredError = false;
    });

    final durationWarning = _computeDurationWarningSync();
    if (durationWarning != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(durationWarning),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final budgetErr = _computeBudgetWarningSync();
    if (budgetErr != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(budgetErr),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare subtasks data
      List<Map<String, dynamic>> subtasks = [];
      for (int i = 0; i < _subtaskControllers.length; i++) {
        if (_subtaskControllers[i].text.isNotEmpty) {
          subtasks.add({
            'title': _subtaskControllers[i].text,
            'status': 'pending',
          });
        }
      }

      // Get the phase name
      final phaseName = _useCustomPhase ? _customPhaseController.text.trim() : _selectedPhase;

      final alloc = _parseAllocAmount();
      if (alloc == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Allocated budget is required'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Prepare phase data
      final phaseData = {
        'project': widget.projectId,
        'phase_name': phaseName,
        'description': _descriptionController.text,
        'days_duration': _daysDurationController.text.isNotEmpty
            ? int.tryParse(_daysDurationController.text)
            : null,
        'status': 'not_started',
        'allocated_budget': alloc,
        'subtasks': subtasks,
      };

      final response = await http.post(
        AppConfig.apiUri('phases/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(phaseData),
      );

      if (!mounted) return;

      // Check for subscription expiry first
      if (SubscriptionHelper.handleResponse(context, response)) {
        return;
      }

      if (response.statusCode == 201) {
        final created = jsonDecode(response.body) as Map<String, dynamic>;
        await _saveNewSubtaskAssignments(created);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Phase added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to add phase: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final modalWidth = isMobile ? screenWidth * 0.95 : 520.0;
    final maxHeight = isMobile ? screenWidth * 1.2 : 600.0;

    final projectDays = _projectDurationDays;
    final remainingDays = (projectDays == null)
        ? null
        : (projectDays - _existingPhasesDurationDays);
    final roomLeft = _roomLeftForNewPhase;
    final projectBudgetStr = _projectTotalBudget == null
        ? '—'
        : '₱${_formatMoney(_projectTotalBudget!)}';
    final allocatedStr = '₱${_formatMoney(_otherPhasesAllocated)}';
    final roomStr = roomLeft == null ? '—' : '₱${_formatMoney(roomLeft)}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 40,
        vertical: isMobile ? 24 : 40,
      ),
      child: Container(
        width: modalWidth,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 12,
                        vertical: isMobile ? 4 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.projectTitle,
                        style: TextStyle(fontSize: isMobile ? 11 : 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: Colors.grey[600],
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Phase dropdown
                      _isLoadingExistingPhases
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFFF7A18),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Loading available phases...',
                                    style: TextStyle(
                                      fontSize: isMobile ? 13 : 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              key: ValueKey(_selectedPhase),
                              initialValue: _selectedPhase,
                              isExpanded: true,
                              decoration: InputDecoration(
                                hintText: 'Select Phase',
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
                                    color: Color(0xFF0C1935),
                                    width: 2,
                                  ),
                                ),
                              ),
                              items: [
                                ..._phases
                                    .where((phase) => !_existingPhases.contains(phase))
                                    .map((phase) {
                                  return DropdownMenuItem<String>(
                                    value: phase,
                                    child: Text(
                                      phase,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: isMobile ? 13 : 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  );
                                }).toList(),
                                DropdownMenuItem<String>(
                                  value: 'CUSTOM_PHASE',
                                  child: Text(
                                    'Custom Phase',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: isMobile ? 13 : 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  if (value == 'CUSTOM_PHASE') {
                                    _useCustomPhase = true;
                                    _selectedPhase = null;
                                  } else {
                                    _useCustomPhase = false;
                                    _selectedPhase = value;
                                    _customPhaseController.clear();
                                  }
                                });
                              },
                              validator: (value) {
                                if (!_useCustomPhase && (value == null || value.isEmpty)) {
                                  return 'Please select a phase';
                                }
                                return null;
                              },
                            ),

                      if (_useCustomPhase) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customPhaseController,
                          decoration: InputDecoration(
                            labelText: 'CUSTOM PHASE NAME',
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            hintText: 'Enter custom phase name',
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
                                color: Color(0xFF0C1935),
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (_useCustomPhase && (value == null || value.trim().isEmpty)) {
                              return 'Please enter a custom phase name';
                            }
                            return null;
                          },
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Days Duration
                      const Text(
                        'Duration',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (projectDays != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Project duration: $projectDays days • Used by phases: $_existingPhasesDurationDays days • Remaining: ${remainingDays ?? 0} days',
                          style: TextStyle(
                            fontSize: 12,
                            color: (_existingPhasesDurationDays > projectDays)
                                ? Colors.red
                                : Colors.grey,
                          ),
                        ),
                        if (remainingDays != null && remainingDays <= 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            'No days are left in the project schedule. You cannot add another phase until you increase the project duration or free days on an existing phase.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _daysDurationController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _recomputeDurationWarning(),
                        validator: (value) {
                          final pd = _projectDurationDays;
                          if (pd != null) {
                            final rem = pd - _existingPhasesDurationDays;
                            if (rem <= 0) {
                              return 'No days left in the schedule. Adjust project or phase durations first.';
                            }
                          }

                          final trimmed = (value ?? '').trim();
                          if (trimmed.isEmpty) return null;

                          final days = int.tryParse(trimmed);
                          if (days == null) {
                            return 'Please enter a valid number of days';
                          }
                          if (days <= 0) {
                            return '0 days is not allowed';
                          }

                          if (pd == null) return null;

                          final total = _existingPhasesDurationDays + days;
                          if (total > pd) {
                            final remaining = pd - _existingPhasesDurationDays;
                            return 'Not valid: you exceed the project duration (remaining: $remaining days)';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'DAYS DURATION',
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          hintText: 'Enter number of days',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          suffixIcon: const Icon(
                            Icons.timer_outlined,
                            size: 18,
                          ),
                          helperText: _durationWarning,
                          helperStyle: TextStyle(
                            color: _durationWarning != null
                                ? Colors.red
                                : Colors.grey.shade600,
                          ),
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
                              color: Color(0xFF0C1935),
                              width: 2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      // Phase budget (new phase share of project budget)
                      const Text(
                        'Phase budget',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      if (_isLoadingBudget)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Loading project budget…',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        )
                      else ...[
                        Text(
                          'Project budget: $projectBudgetStr · '
                          'Already allocated: $allocatedStr · '
                          'You can assign up to: $roomStr',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _allocatedBudgetController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          onChanged: (_) => _recomputeBudgetWarning(),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            final max = _roomLeftForNewPhase;
                            final raw = (value ?? '')
                                .trim()
                                .replaceAll(',', '');
                            if (raw.isEmpty) {
                              return 'Allocated budget is required';
                            }
                            final am = double.tryParse(raw);
                            if (am == null) {
                              return 'Enter a valid amount';
                            }
                            if (am < 0) return 'Cannot be negative';
                            if (max != null && am > max) {
                              return 'Cannot exceed available ₱${_formatMoney(max)}';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'ALLOCATED BUDGET FOR THIS PHASE (PHP) *',
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            hintText: '0.00',
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            prefixText: '₱ ',
                            helperText: _budgetWarning,
                            helperStyle: TextStyle(
                              color: _budgetWarning != null
                                  ? Colors.red
                                  : Colors.grey.shade600,
                            ),
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
                                color: Color(0xFF0C1935),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 1.5,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Description
                      const Text(
                        'Description',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Add more details to this task...',
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
                              color: Color(0xFF0C1935),
                              width: 2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Subtask
                      Row(
                        children: [
                          const Text(
                            'Subtasks',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _addSubtask,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        onReorder: _reorderSubtasks,
                        children: List.generate(
                          _subtaskControllers.length,
                          (index) => Container(
                            key: Key('$index'),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                                width: 1,
                              ),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    child: const Icon(
                                      Icons.drag_handle,
                                      size: 20,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        TextFormField(
                                          controller: _subtaskControllers[index],
                                          decoration: InputDecoration(
                                            hintText: 'Subtask ${index + 1}',
                                            hintStyle: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFFD1D5DB),
                                            ),
                                            filled: false,
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 8,
                                                ),
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _openAssignWorkersForSubtask(
                                                    index,
                                                  ),
                                              icon: const Icon(
                                                Icons.group_add_outlined,
                                                size: 16,
                                              ),
                                              label: Text(
                                                _subtaskWorkerDrafts[index]
                                                        .workerIds
                                                        .isEmpty
                                                    ? 'Add Worker'
                                                    : '${_subtaskWorkerDrafts[index].workerIds.length} worker(s)',
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                            ),
                                            if (_subtaskWorkerDrafts[index]
                                                .workerIds
                                                .isEmpty)
                                              const Text(
                                                'Worker required',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            if (_subtaskWorkerDrafts[index]
                                                .hasShift)
                                              Text(
                                                '${_subtaskWorkerDrafts[index].shiftStartDisplay} - ${_subtaskWorkerDrafts[index].shiftEndDisplay}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF6B7280),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_subtaskControllers.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: IconButton(
                                      onPressed: () => _removeSubtask(index),
                                      icon: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      splashRadius: 18,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_showSubtaskError)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Please add at least one subtask',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (_showWorkerRequiredError)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Please assign at least one worker for every subtask.',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  const Spacer(),
                  ElevatedButton(
                    onPressed: (_isLoading ||
                            _isLoadingExistingPhases ||
                            _isLoadingBudget ||
                            _isScheduleExhausted)
                        ? null
                        : _submitPhase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Add',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
  }
}

class _SubtaskWorkerDraft {
  final Set<int> workerIds;
  final String? shiftStartApi;
  final String? shiftEndApi;
  final String? shiftStartDisplay;
  final String? shiftEndDisplay;

  const _SubtaskWorkerDraft({
    required this.workerIds,
    this.shiftStartApi,
    this.shiftEndApi,
    this.shiftStartDisplay,
    this.shiftEndDisplay,
  });

  factory _SubtaskWorkerDraft.empty() =>
      const _SubtaskWorkerDraft(workerIds: <int>{});

  bool get hasShift =>
      shiftStartApi != null &&
      shiftEndApi != null &&
      shiftStartDisplay != null &&
      shiftEndDisplay != null;
}

class _DraftWorker {
  final int id;
  final String name;
  final String role;
  final List<String> assignedProjectNames;
  final bool assignedToOtherProject;

  const _DraftWorker({
    required this.id,
    required this.name,
    required this.role,
    required this.assignedProjectNames,
    required this.assignedToOtherProject,
  });
}

class _AssignWorkersForDraftSubtaskModal extends StatefulWidget {
  final int projectId;
  final String subtaskTitle;
  final _SubtaskWorkerDraft initialDraft;
  final Set<int> blockedWorkerIds;

  const _AssignWorkersForDraftSubtaskModal({
    required this.projectId,
    required this.subtaskTitle,
    required this.initialDraft,
    required this.blockedWorkerIds,
  });

  @override
  State<_AssignWorkersForDraftSubtaskModal> createState() =>
      _AssignWorkersForDraftSubtaskModalState();
}

class _AssignWorkersForDraftSubtaskModalState
    extends State<_AssignWorkersForDraftSubtaskModal> {
  final List<String> _roles = const [
    'All',
    'Mason',
    'Painter',
    'Electrician',
    'Carpenter',
  ];

  List<_DraftWorker> _workers = const [];
  String _search = '';
  String _selectedRole = 'All';
  bool _loading = true;
  String? _error;
  late Set<int> _selectedIds;
  TimeOfDay? _shiftStart;
  TimeOfDay? _shiftEnd;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<int>.from(widget.initialDraft.workerIds);
    _shiftStart = _parseApiTime(widget.initialDraft.shiftStartApi);
    _shiftEnd = _parseApiTime(widget.initialDraft.shiftEndApi);
    _loadWorkers();
  }

  TimeOfDay? _parseApiTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatDisplayTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatApiTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  bool get _hasValidShift {
    if (_shiftStart == null || _shiftEnd == null) return false;
    final start = (_shiftStart!.hour * 60) + _shiftStart!.minute;
    final end = (_shiftEnd!.hour * 60) + _shiftEnd!.minute;
    return start != end;
  }

  bool get _isOvernightShift {
    if (_shiftStart == null || _shiftEnd == null) return false;
    final start = (_shiftStart!.hour * 60) + _shiftStart!.minute;
    final end = (_shiftEnd!.hour * 60) + _shiftEnd!.minute;
    return end < start;
  }

  Future<void> _loadWorkers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final currentUser = AuthService().currentUser;
      final currentUserType = (currentUser?['type'] ?? '').toString();
      final isRealUser =
          currentUserType.toLowerCase() == 'user' ||
          (currentUserType.isEmpty &&
              currentUser?['supervisor_id'] == null &&
              currentUser?['client_id'] == null);
      final rawUserId = currentUser?['user_id'];
      final int? parsedUserId = (isRealUser && rawUserId != null)
          ? (rawUserId is int ? rawUserId : int.tryParse(rawUserId.toString()))
          : null;

      final response = await http.get(
        AppConfig.apiUri(
          'field-workers/?include_other_projects=true&project_id=${widget.projectId}',
        ),
        headers: {
          if (parsedUserId != null && parsedUserId > 0)
            'X-User-Id': parsedUserId.toString(),
        },
      );
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Failed to load workers';
        });
        return;
      }

      final decoded = jsonDecode(response.body);
      final list = decoded is List
          ? decoded
          : (decoded is Map<String, dynamic> && decoded['results'] is List
                ? decoded['results'] as List<dynamic>
                : <dynamic>[]);
      final workers = list
          .whereType<Map>()
          .map((raw) {
            final map = raw.cast<String, dynamic>();
            final rawId = map['fieldworker_id'] ?? map['id'];
            final id = rawId is int
                ? rawId
                : int.tryParse(rawId?.toString() ?? '') ?? 0;
            final status = (map['assignment_status'] ?? 'Available').toString();
            final assignedProjects = map['assigned_projects'];
            final List<String> assignedProjectNames = [];
            if (assignedProjects is List) {
              for (final p in assignedProjects.cast<dynamic>()) {
                if (p is! Map<String, dynamic>) continue;
                final assignedProjectIdRaw = p['project_id'];
                final assignedProjectId = assignedProjectIdRaw is int
                    ? assignedProjectIdRaw
                    : int.tryParse(assignedProjectIdRaw?.toString() ?? '');
                if (assignedProjectId == widget.projectId) continue;
                final projectName = p['project_name']?.toString().trim();
                if (projectName == null || projectName.isEmpty) continue;
                if (!assignedProjectNames.contains(projectName)) {
                  assignedProjectNames.add(projectName);
                }
              }
            }
            return _DraftWorker(
              id: id,
              name:
                  '${map['first_name'] ?? ''} ${map['last_name'] ?? ''}'.trim(),
              role: (map['role'] ?? 'Field Worker').toString(),
              assignedProjectNames: assignedProjectNames,
              assignedToOtherProject: assignedProjectNames.isNotEmpty,
            );
          })
          .where((w) => w.id > 0)
          .toList();
      setState(() {
        _workers = workers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart
        ? (_shiftStart ?? const TimeOfDay(hour: 8, minute: 0))
        : (_shiftEnd ?? const TimeOfDay(hour: 16, minute: 0));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _shiftStart = picked;
      } else {
        _shiftEnd = picked;
      }
    });
  }

  void _save() {
    if (_selectedIds.isNotEmpty && !_hasValidShift) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set a valid shift schedule.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _SubtaskWorkerDraft(
        workerIds: Set<int>.from(_selectedIds),
        shiftStartApi: _selectedIds.isEmpty || _shiftStart == null
            ? null
            : _formatApiTime(_shiftStart!),
        shiftEndApi: _selectedIds.isEmpty || _shiftEnd == null
            ? null
            : _formatApiTime(_shiftEnd!),
        shiftStartDisplay: _selectedIds.isEmpty || _shiftStart == null
            ? null
            : _formatDisplayTime(_shiftStart!),
        shiftEndDisplay: _selectedIds.isEmpty || _shiftEnd == null
            ? null
            : _formatDisplayTime(_shiftEnd!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _workers.where((w) {
      final q = _search.trim().toLowerCase();
      final bySearch =
          q.isEmpty || w.name.toLowerCase().contains(q) || w.role.toLowerCase().contains(q);
      final byRole = _selectedRole == 'All' || w.role == _selectedRole;
      return bySearch && byRole;
    }).toList();

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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Row(
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
                          'Subtask: ${widget.subtaskTitle}',
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
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      onChanged: (value) => setState(() => _search = value),
                      decoration: InputDecoration(
                        hintText: 'Search workers by name or role...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFFF7A18)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Shift Schedule',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickTime(true),
                            icon: const Icon(Icons.schedule, size: 18),
                            label: Text(
                              _shiftStart == null
                                  ? 'Shift Start'
                                  : _formatDisplayTime(_shiftStart!),
                            ),
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              foregroundColor: const Color(0xFF0C1935),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickTime(false),
                            icon: const Icon(Icons.schedule, size: 18),
                            label: Text(
                              _shiftEnd == null
                                  ? 'Shift End'
                                  : _formatDisplayTime(_shiftEnd!),
                            ),
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              foregroundColor: const Color(0xFF0C1935),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _shiftStart != null && _shiftEnd != null
                          ? (_hasValidShift
                                ? (_isOvernightShift
                                      ? 'Overnight shift: ${_formatDisplayTime(_shiftStart!)} - ${_formatDisplayTime(_shiftEnd!)} (next day)'
                                      : 'Shift: ${_formatDisplayTime(_shiftStart!)} - ${_formatDisplayTime(_shiftEnd!)}')
                                : 'Shift start and end cannot be the same.')
                          : 'Set the shift time first (e.g., 8:00 AM - 4:00 PM).',
                      style: TextStyle(
                        fontSize: 12,
                        color: _shiftStart != null && _shiftEnd != null
                            ? (_hasValidShift
                                  ? const Color(0xFF10B981)
                                  : Colors.red)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                                  onSelected: (_) =>
                                      setState(() => _selectedRole = role),
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
                              ActionChip(
                                onPressed: () async {
                                  final result = await showDialog(
                                    context: context,
                                    builder: (_) => AddFieldWorkerModal(
                                      workerType: 'Field Worker',
                                      projectId: widget.projectId,
                                    ),
                                  );
                                  if (result == true) _loadWorkers();
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
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_error != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'Error: $_error',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red[600],
                            ),
                          ),
                        ),
                      )
                    else if (filtered.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            _search.isNotEmpty || _selectedRole != 'All'
                                ? 'No workers match your filters'
                                : 'No workers available',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: filtered.map((w) {
                          final blockedBySubtask = widget.blockedWorkerIds.contains(w.id);
                          return _DraftWorkerChecklistItem(
                            worker: w,
                            blockedByOtherSubtask: blockedBySubtask,
                            isSelected: _selectedIds.contains(w.id),
                            onChanged: (value) {
                              if (w.assignedToOtherProject || blockedBySubtask) return;
                              setState(() {
                                if (_selectedIds.contains(w.id)) {
                                  _selectedIds.remove(w.id);
                                } else {
                                  _selectedIds.add(w.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                    if (_selectedIds.isNotEmpty)
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
                          '${_selectedIds.length} worker${_selectedIds.length > 1 ? 's' : ''} selected',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
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
                    onPressed: _selectedIds.isNotEmpty ? _save : null,
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
                    child: const Text('Assign Workers'),
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

class _DraftWorkerChecklistItem extends StatelessWidget {
  final _DraftWorker worker;
  final bool blockedByOtherSubtask;
  final bool isSelected;
  final ValueChanged<bool?> onChanged;

  const _DraftWorkerChecklistItem({
    required this.worker,
    required this.blockedByOtherSubtask,
    required this.isSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final blocked = worker.assignedToOtherProject || blockedByOtherSubtask;
    final String statusLabel = blockedByOtherSubtask
        ? 'On another subtask in this phase'
        : (worker.assignedToOtherProject
              ? (worker.assignedProjectNames.isNotEmpty
                    ? worker.assignedProjectNames.join(' • ')
                    : 'Assigned to another project')
              : 'Available');

    return Opacity(
      opacity: blocked && !isSelected ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF2E8) : Colors.white,
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF7A18)
                : const Color(0xFFE5E7EB),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: blocked ? null : onChanged,
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: blocked
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
                        color: blocked
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF10B981),
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
  }
}
