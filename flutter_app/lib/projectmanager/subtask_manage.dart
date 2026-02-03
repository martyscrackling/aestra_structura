import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/manage_workers.dart';
import 'project_details_page.dart';

class SubtaskManagePage extends StatefulWidget {
  final Phase phase;

  const SubtaskManagePage({super.key, required this.phase});

  @override
  State<SubtaskManagePage> createState() => _SubtaskManagePageState();
}

class _SubtaskManagePageState extends State<SubtaskManagePage> {
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
                                    widget.phase.phaseName,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0C1935),
                                    ),
                                  ),
                                  if (widget.phase.description != null &&
                                      widget.phase.description!.isNotEmpty)
                                    Text(
                                      widget.phase.description!,
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
                                'Duration: ${widget.phase.daysDuration != null ? '${widget.phase.daysDuration} days' : 'Not set'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusBgColor(widget.phase.status),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.phase.status
                                      .replaceAll('_', ' ')
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _getStatusColor(widget.phase.status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Subtasks section
                        Text(
                          'Subtasks / ${widget.phase.subtasks.length}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0C1935),
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (widget.phase.subtasks.isEmpty)
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
                              children: widget.phase.subtasks
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                    final index = entry.key;
                                    final subtask = entry.value;
                                    final isLast =
                                        index ==
                                        widget.phase.subtasks.length - 1;
                                    return Column(
                                      children: [
                                        _SubtaskTile(
                                          subtask: subtask,
                                          phase: widget.phase,
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

  const _SubtaskTile({required this.subtask, required this.phase});

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
          Checkbox(
            value: subtask.status.toLowerCase() == 'completed',
            onChanged: (value) {},
            activeColor: const Color(0xFF10B981),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtask.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF0C1935),
                    decoration: subtask.status.toLowerCase() == 'completed'
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => ViewWorkForceModal(subtask: subtask),
              );
            },
            icon: const Icon(Icons.groups_outlined, size: 16),
            label: const Text('View Work Force'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0C1935),
              elevation: 0,
              side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) =>
                    ManageWorkersModal(subtask: subtask, phase: phase),
              );
            },
            icon: const Icon(Icons.person_add_outlined, size: 16),
            label: const Text('Manage workers'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: const Color(0xFFFF7A18),
              elevation: 0,
              side: const BorderSide(color: Color(0xFFFF7A18), width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
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
        Uri.parse(
          'http://127.0.0.1:8000/api/subtask-assignments/?subtask_id=${widget.subtask.subtaskId}',
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
          final workerResponse = await http.get(
            Uri.parse(
              'http://127.0.0.1:8000/api/field-workers/${assignment['field_worker']}/',
            ),
          );

          if (workerResponse.statusCode == 200) {
            final workerData = jsonDecode(workerResponse.body);
            workers.add({
              'name': '${workerData['first_name']} ${workerData['last_name']}',
              'role': workerData['role'] ?? 'Field Worker',
              'phone': workerData['phone_number'] ?? 'N/A',
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
