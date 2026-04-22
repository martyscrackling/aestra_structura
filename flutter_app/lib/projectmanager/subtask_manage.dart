import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/manage_workers.dart';
import 'project_details_page.dart';
import '../services/app_config.dart';
import '../services/auth_service.dart';

class SubtaskManagePage extends StatefulWidget {
  final Phase phase;

  const SubtaskManagePage({super.key, required this.phase});

  @override
  State<SubtaskManagePage> createState() => _SubtaskManagePageState();
}

class _SubtaskManagePageState extends State<SubtaskManagePage> {
  late Phase _phase;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phase = widget.phase;
  }

  Future<void> _refreshPhase() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        AppConfig.apiUri('phases/${_phase.phaseId}/'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _phase = Phase.fromJson(jsonDecode(response.body));
        });
      }
    } catch (e) {
      debugPrint('Error refreshing phase: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editSubtask(Subtask subtask) async {
    final controller = TextEditingController(text: subtask.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Subtask Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter subtask name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7A18)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != subtask.title) {
      try {
        final response = await http.patch(
          AppConfig.apiUri('subtasks/${subtask.subtaskId}/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'title': newTitle}),
        );
        if (response.statusCode == 200) {
          _refreshPhase();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Subtask updated')),
            );
          }
        }
      } catch (e) {
        debugPrint('Error editing subtask: $e');
      }
    }
  }

  Future<void> _removeSubtask(Subtask subtask) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Subtask'),
        content: Text('Are you sure you want to remove "${subtask.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await http.delete(
          AppConfig.apiUri('subtasks/${subtask.subtaskId}/'),
        );
        if (response.statusCode == 204) {
          _refreshPhase();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Subtask removed')),
            );
          }
        }
      } catch (e) {
        debugPrint('Error removing subtask: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          const Sidebar(currentPage: 'Projects'),
          Expanded(
            child: Column(
              children: [
                const DashboardHeader(title: 'Subtasks'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back button and phase header
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back),
                              color: const Color(0xFF0C1935),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _phase.phaseName,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0C1935),
                                    ),
                                  ),
                                  if (_phase.description != null &&
                                      _phase.description!.isNotEmpty)
                                    Text(
                                      _phase.description!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Phase info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 18,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Duration: ${_phase.daysDuration != null ? '${_phase.daysDuration} days' : 'Not set'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 16),
                              if (_phase.status != 'not_started')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusBgColor(_phase.status),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _phase.status
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _getStatusColor(_phase.status),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Subtasks section
                        Text(
                          'Subtasks / ${_phase.subtasks.length}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0C1935),
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_phase.subtasks.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.checklist_outlined,
                                    size: 48,
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No subtasks yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: _phase.subtasks
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                    final index = entry.key;
                                    final subtask = entry.value;
                                    final isLast =
                                        index ==
                                        _phase.subtasks.length - 1;
                                    return Column(
                                      children: [
                                        _SubtaskTile(
                                          subtask: subtask,
                                          phase: _phase,
                                          onEdit: () => _editSubtask(subtask),
                                          onRemove: () => _removeSubtask(subtask),
                                        ),
                                        if (!isLast)
                                          const Divider(
                                            height: 1,
                                            color: Color(0xFFF3F4F6),
                                          ),
                                      ],
                                    );
                                  })
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'in_progress':
        return const Color(0xFFFF7A18);
      case 'not_started':
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFFE5F8ED);
      case 'in_progress':
        return const Color(0xFFFFF2E8);
      case 'not_started':
      default:
        return const Color(0xFFF3F4F6);
    }
  }
}

class _SubtaskTile extends StatelessWidget {
  final Subtask subtask;
  final Phase phase;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _SubtaskTile({
    required this.subtask,
    required this.phase,
    required this.onEdit,
    required this.onRemove,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'in_progress':
        return const Color(0xFFFF7A18);
      case 'not_started':
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFFE5F8ED);
      case 'in_progress':
        return const Color(0xFFFFF2E8);
      case 'not_started':
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusBgColor(subtask.status),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              subtask.status.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _getStatusColor(subtask.status),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtask.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0C1935),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => ViewWorkForceModal(subtask: subtask),
              );
            },
            icon: const Icon(Icons.groups_outlined),
            tooltip: 'View Work Force',
            color: const Color(0xFF0C1935),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) =>
                    ManageWorkersModal(subtask: subtask, phase: phase),
              );
            },
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Manage workers',
            color: const Color(0xFFFF7A18),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
            tooltip: 'Options',
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'remove') {
                onRemove();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20, color: Color(0xFF0C1935)),
                    SizedBox(width: 12),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Remove', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// View Work Force Modal
class ViewWorkForceModal extends StatefulWidget {
  final Subtask subtask;

  const ViewWorkForceModal({super.key, required this.subtask});

  @override
  State<ViewWorkForceModal> createState() => _ViewWorkForceModalState();
}

class _ViewWorkForceModalState extends State<ViewWorkForceModal> {
  List<Map<String, dynamic>> _assignedWorkers = [];
  bool _isLoading = true;
  String? _error;

  String _formatApiTime(String? value) {
    if (value == null || value.isEmpty) return '';
    final parts = value.split(':');
    if (parts.length < 2) return value;
    final hour24 = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour24 == null || minute == null) return value;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = (hour24 % 12 == 0) ? 12 : hour24 % 12;
    final minuteText = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteText $period';
  }

  String _buildShiftLabel(Map<String, dynamic> assignment) {
    final shiftStart = assignment['shift_start']?.toString();
    final shiftEnd = assignment['shift_end']?.toString();
    if ((shiftStart == null || shiftStart.isEmpty) ||
        (shiftEnd == null || shiftEnd.isEmpty)) {
      return 'No shift schedule set';
    }
    return '${_formatApiTime(shiftStart)} - ${_formatApiTime(shiftEnd)}';
  }

  @override
  void initState() {
    super.initState();
    _fetchAssignedWorkers();
  }

  Future<void> _fetchAssignedWorkers() async {
    try {
      print(
        '🔍 Fetching assigned workers for subtask: ${widget.subtask.subtaskId}',
      );
      final response = await http.get(
        AppConfig.apiUri(
          'subtask-assignments/?subtask_id=${widget.subtask.subtaskId}',
        ),
      );

      print('✅ Response status: ${response.statusCode}');
      print('✅ Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> assignments = jsonDecode(response.body);
        print('📊 Assignments fetched: ${assignments.length}');

        // Fetch details for each assigned worker
        List<Map<String, dynamic>> workers = [];
        for (var assignment in assignments) {
          final userId = AuthService().currentUser?['user_id'];
          final workerResponse = await http.get(
            (userId != null)
                ? AppConfig.apiUri(
                    'field-workers/${assignment['field_worker']}/?user_id=$userId',
                  )
                : AppConfig.apiUri(
                    'field-workers/${assignment['field_worker']}/',
                  ),
          );

          if (workerResponse.statusCode == 200) {
            final workerData = jsonDecode(workerResponse.body);
            workers.add({
              'assignment_id': assignment['assignment_id'],
              'field_worker_id': assignment['field_worker'],
              'name': '${workerData['first_name']} ${workerData['last_name']}',
              'role': workerData['role'] ?? 'Field Worker',
              'phone': workerData['phone_number'] ?? 'N/A',
              'shift_label': _buildShiftLabel(assignment),
            });
          }
        }

        setState(() {
          _assignedWorkers = workers;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load assigned workers';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching assigned workers: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _removeAssignedWorker(Map<String, dynamic> worker) async {
    final assignmentId = worker['assignment_id'];
    if (assignmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing assignment id.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Remove Worker'),
        content: Text('Remove ${worker['name']} from this subtask?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await http.delete(
        AppConfig.apiUri('subtask-assignments/$assignmentId/'),
      );

      if (!mounted) return;

      if (response.statusCode == 204 || response.statusCode == 200) {
        setState(() {
          _assignedWorkers.removeWhere(
            (w) => w['assignment_id'].toString() == assignmentId.toString(),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${worker['name']} removed from subtask')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove worker (${response.statusCode})'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing worker: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.5,
        constraints: const BoxConstraints(maxHeight: 500),
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assigned Work Force',
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
            ),
            // Worker list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                  : _assignedWorkers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.group_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No workers assigned yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Click "Manage workers" to assign field workers',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: _assignedWorkers.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final worker = _assignedWorkers[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFFFF7A18),
                                child: Text(
                                  worker['name']
                                      .toString()
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      worker['name'],
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0C1935),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.construction,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          worker['role'],
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.phone,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          worker['phone'],
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          worker['shift_label'] ??
                                              'No shift schedule set',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5F8ED),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Assigned',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Remove worker',
                                onPressed: () => _removeAssignedWorker(worker),
                                icon: const Icon(
                                  Icons.person_remove,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ${_assignedWorkers.length} worker${_assignedWorkers.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
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
                    child: const Text('Close'),
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
