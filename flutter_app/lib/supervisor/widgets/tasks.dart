import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/app_config.dart';

class Tasks extends StatefulWidget {
  final int? projectId;

  const Tasks({super.key, required this.projectId});

  @override
  State<Tasks> createState() => _TasksState();
}

class _TasksState extends State<Tasks> {
  Future<List<Map<String, dynamic>>>? _tasksFuture;

  @override
  void initState() {
    super.initState();
    _tasksFuture = _fetchTasks();
  }

  @override
  void didUpdateWidget(covariant Tasks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      _tasksFuture = _fetchTasks();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTasks() async {
    final projectId = widget.projectId;
    if (projectId == null) return [];

    try {
      final response = await http.get(
        AppConfig.apiUri('subtasks/?project_id=$projectId'),
      );

      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return [];

      final tasks = decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      tasks.sort((a, b) {
        final aUpdated = (a['updated_at'] as String?) ?? '';
        final bUpdated = (b['updated_at'] as String?) ?? '';
        return bUpdated.compareTo(aUpdated);
      });

      // Keep the widget compact
      return tasks.take(4).toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  String _statusLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'in_progress':
      case 'in progress':
        return 'In Progress';
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'in_review':
      case 'in review':
        return 'In Review';
      default:
        return raw.isEmpty ? 'Pending' : raw;
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "Completed":
        return const Color.fromARGB(255, 31, 240, 4); // Grey
      case "In Progress":
        return const Color(0xFFFF6F00); // Orange
      case "Pending":
        return const Color.fromARGB(255, 253, 207, 1); // Light Grey
      case "In Review":
        return const Color(0xFFFF8F00); // Light Orange
      case "Assigned":
        return const Color(0xFF2563EB);
      default:
        return Colors.grey;
    }
  }

  double _progressFor(String status) {
    switch (status) {
      case "Completed":
        return 1.0;
      case "In Progress":
        return 0.45;
      case "In Review":
        return 0.78;
      case "Pending":
        return 0.12;
      case "Assigned":
        return 0.2;
      default:
        return 0.0;
    }
  }

  String _initials(String title) {
    final parts = title.split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Widget _statusChip(String status) {
    final color = getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Tasks To Do",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    "View all",
                    style: TextStyle(fontSize: 13, color: Color(0xFFFF6F00)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.projectId == null)
              const Text(
                'No project assigned.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            else
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _tasksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final tasks = snapshot.data ?? const [];
                  if (tasks.isEmpty) {
                    return const Text(
                      'No tasks found.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    );
                  }

                  return Column(
                    children: tasks.map((task) {
                      final title =
                          (task['title'] as String?) ?? 'Untitled task';
                      final rawStatus =
                          (task['status'] as String?) ?? 'pending';
                      final status = _statusLabel(rawStatus);
                      final color = getStatusColor(status);
                      final progress = _progressFor(status);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _initials(title),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2E3A44),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF2E3A44),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today_outlined,
                                              size: 12,
                                              color: Colors.grey[500],
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              status == "Completed"
                                                  ? "Done"
                                                  : "Due soon",
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            _statusChip(status),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<int>(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.more_horiz,
                                      color: Colors.grey,
                                    ),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 0,
                                        child: Text('Edit'),
                                      ),
                                      PopupMenuItem(
                                        value: 1,
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 8,
                                        color: color,
                                        backgroundColor: Colors.grey[200],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${(progress * 100).toInt()}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
