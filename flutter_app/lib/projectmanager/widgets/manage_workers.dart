import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../project_details_page.dart';
import '../../services/app_config.dart';
import '../../services/subscription_helper.dart';
import '../../services/auth_service.dart';

class Worker {
  final int workerId;
  final String name;
  final String role;
  final String status;
  final String? imageUrl;

  Worker({
    required this.workerId,
    required this.name,
    required this.role,
    required this.status,
    this.imageUrl,
  });
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
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedRole = 'All';

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

      // Fetch all field workers accessible to this user, including from other projects
      // The assignment_status will be computed by the backend based on current project context
      final endpoint = 'field-workers/?include_other_projects=true&project_id=$projectId';

      print('🔍 Fetching field workers from: $endpoint');
      
      final headers = <String, String>{
        if (parsedUserId != null && parsedUserId > 0)
          'X-User-Id': parsedUserId.toString(),
      };

      final response = await http.get(
        AppConfig.apiUri(endpoint),
        headers: headers,
      );
      
      print('✅ Response status: ${response.statusCode}');
      print('✅ Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final parsed = decoded is List
            ? decoded
            : (decoded is Map<String, dynamic> && decoded['results'] is List
                  ? decoded['results'] as List<dynamic>
                  : <dynamic>[]);

        print('📊 Field workers fetched: ${parsed.length}');

        setState(() {
          _availableWorkers = parsed
              .map((json) {
                final rawId = json['fieldworker_id'] ?? json['id'];
                final workerId = rawId is int
                    ? rawId
                    : int.tryParse(rawId?.toString() ?? '') ?? 0;

                return Worker(
                  workerId: workerId,
                  name: '${json['first_name']} ${json['last_name']}',
                  role: json['role'] ?? 'Field Worker',
                  status: json['assignment_status'] ?? 'Available', // Use backend-computed status
                );
              })
              .where((worker) => worker.workerId > 0)
              .toList();
          _filteredWorkers = _availableWorkers;
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

  void _toggleWorker(int workerId) {
    setState(() {
      if (_selectedWorkerIds.contains(workerId)) {
        _selectedWorkerIds.remove(workerId);
      } else {
        _selectedWorkerIds.add(workerId);
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
        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  void _saveAssignments() async {
    if (_selectedWorkerIds.isEmpty) {
      Navigator.pop(context);
      return;
    }

    try {
      // First, clear existing assignments for this subtask
      final deleteResponse = await http.delete(
        AppConfig.apiUri(
          'subtask-assignments/?subtask_id=${widget.subtask.subtaskId}',
        ),
      );

      if (!mounted) return;

      // Check for subscription expiry on delete
      if (SubscriptionHelper.handleResponse(context, deleteResponse)) {
        return;
      }

      // Create assignments payload
      final assignments = _selectedWorkerIds.map((workerId) {
        return {'subtask': widget.subtask.subtaskId, 'field_worker': workerId};
      }).toList();

      print('📤 Saving assignments: $assignments');

      final response = await http.post(
        AppConfig.apiUri('subtask-assignments/'),
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

      if (response.statusCode == 201) {
        Navigator.pop(context, _selectedWorkerIds.toList());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedWorkerIds.length} worker${_selectedWorkerIds.length > 1 ? 's' : ''} assigned successfully',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to assign workers'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error saving assignments: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                            children: _roles.map((role) {
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
                            }).toList(),
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
                          return _WorkerChecklistItem(
                            worker: worker,
                            isSelected: _selectedWorkerIds.contains(
                              worker.workerId,
                            ),
                            onChanged: (value) {
                              _toggleWorker(worker.workerId);
                            },
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                    if (_selectedWorkerIds.isNotEmpty)
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
                          '${_selectedWorkerIds.length} worker${_selectedWorkerIds.length > 1 ? 's' : ''} selected',
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
                    onPressed: _saveAssignments,
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
    // Determine if worker is assigned to other project's subtasks
    final isAssignedToOtherProject = worker.status == 'Assigned';
    
    return Container(
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
              onChanged: onChanged,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isAssignedToOtherProject ? const Color(0xFFFEE2E2) : const Color(0xFFE5F8ED),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isAssignedToOtherProject ? 'Assigned' : 'Available',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isAssignedToOtherProject ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
