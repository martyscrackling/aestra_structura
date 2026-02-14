import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/app_config.dart';

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

  String? _selectedPhase;
  final List<TextEditingController> _subtaskControllers = [];
  List<String> _existingPhases = []; // Phase names already in database

  int? _projectDurationDays;
  int _existingPhasesDurationDays = 0;
  String? _durationWarning;

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
      }
    } catch (e) {
      // Silently fail; modal can still work without duration validation.
      // ignore: avoid_print
      print('Error fetching project duration: $e');
    }
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
        });

        _recomputeDurationWarning();
      }
    } catch (e) {
      // Silently fail - user can still add phases
      // ignore: avoid_print
      print('Error fetching existing phases: $e');
    }
  }

  void _recomputeDurationWarning() {
    final projectDays = _projectDurationDays;
    final enteredDays = int.tryParse(_daysDurationController.text.trim());

    if (projectDays == null || projectDays <= 0) {
      setState(() {
        _durationWarning = null;
      });
      return;
    }

    if (enteredDays == null) {
      setState(() {
        _durationWarning = null;
      });
      return;
    }

    final total = _existingPhasesDurationDays + enteredDays;
    final remaining = projectDays - _existingPhasesDurationDays;

    if (total > projectDays) {
      setState(() {
        _durationWarning =
            'Not valid: phase duration exceeds project duration. Remaining: $remaining days.';
      });
    } else {
      setState(() {
        _durationWarning = null;
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _daysDurationController.dispose();
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

  bool _isLoading = false;

  Future<void> _submitPhase() async {
    if (!_formKey.currentState!.validate()) return;

    if (_durationWarning != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_durationWarning!),
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

      // Prepare phase data
      final phaseData = {
        'project': widget.projectId,
        'phase_name': _selectedPhase,
        'description': _descriptionController.text,
        'days_duration': _daysDurationController.text.isNotEmpty
            ? int.tryParse(_daysDurationController.text)
            : null,
        'status': 'not_started',
        'subtasks': subtasks,
      };

      final response = await http.post(
        AppConfig.apiUri('phases/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(phaseData),
      );

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
                  Flexible(
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
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
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
                      DropdownButtonFormField<String>(
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
                        ),
                        items: _phases.map((phase) {
                          final isDisabled = _existingPhases.contains(phase);
                          return DropdownMenuItem<String>(
                            value: phase,
                            enabled: !isDisabled,
                            child: Text(
                              phase,
                              style: TextStyle(
                                color: isDisabled
                                    ? Colors.grey.shade400
                                    : Colors.black,
                                fontSize: isMobile ? 13 : 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPhase = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a phase';
                          }
                          return null;
                        },
                      ),

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
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _daysDurationController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _recomputeDurationWarning(),
                        validator: (value) {
                          final trimmed = (value ?? '').trim();
                          if (trimmed.isEmpty) return null;

                          final days = int.tryParse(trimmed);
                          if (days == null || days < 0) {
                            return 'Please enter a valid number of days';
                          }

                          final pd = _projectDurationDays;
                          if (pd == null || pd <= 0) return null;

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
                        ),
                      ),

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
                    onPressed: _isLoading ? null : _submitPhase,
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
                            style: TextStyle(fontWeight: FontWeight.w600),
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
