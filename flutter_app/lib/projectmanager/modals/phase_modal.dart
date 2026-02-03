import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
  List<String> _existingPhases = []; // Phases already in database

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
    _fetchExistingPhases();
  }

  Future<void> _fetchExistingPhases() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://127.0.0.1:8000/api/phases/?project_id=${widget.projectId}',
        ),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _existingPhases = data
              .map((phase) => phase['phase_name'] as String)
              .toList();
        });
      }
    } catch (e) {
      // Silently fail - user can still add phases
      print('Error fetching existing phases: $e');
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
        Uri.parse('http://127.0.0.1:8000/api/phases/'),
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.projectTitle,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Phase dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedPhase,
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
                              ),
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
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _daysDurationController,
                        keyboardType: TextInputType.number,
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

class _DetailColumn extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;

  const _DetailColumn({required this.label, required this.icon, this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          if (value != null) ...[
            const SizedBox(height: 4),
            Text(value!, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }
}

// Usage:
// showDialog(context: context, builder: (_) => const CreatePhaseModal());
