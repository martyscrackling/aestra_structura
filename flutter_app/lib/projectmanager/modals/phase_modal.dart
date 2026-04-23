import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/app_config.dart';
import '../../services/budget_service.dart';
import '../../services/subscription_helper.dart';

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
  List<String> _existingPhases = []; // Phase names already in database

  int? _projectDurationDays;
  int _existingPhasesDurationDays = 0;
  String? _durationWarning;
  bool _showSubtaskError = false;
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
    });
  }

  void _removeSubtask(int index) {
    setState(() {
      _subtaskControllers[index].dispose();
      _subtaskControllers.removeAt(index);
    });
  }

  void _reorderSubtasks(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _subtaskControllers.removeAt(oldIndex);
      _subtaskControllers.insert(newIndex, item);
    });
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
      });
      return;
    }

    setState(() {
      _showSubtaskError = false;
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
                          if (days == null || days < 0) {
                            return 'Please enter a valid number of days';
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
                                    child: TextFormField(
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
