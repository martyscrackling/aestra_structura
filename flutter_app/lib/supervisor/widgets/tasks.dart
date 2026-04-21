import 'package:flutter/material.dart';
import '../../services/supervisor_dashboard_data_service.dart';

class Tasks extends StatefulWidget {
  final int? projectId;

  const Tasks({super.key, required this.projectId});

  @override
  State<Tasks> createState() => _TasksState();
}

class _TasksState extends State<Tasks> {
  Future<List<Map<String, dynamic>>>? _tasksFuture;
  bool _showAllTasks = false;

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
      _showAllTasks = false;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTasks() async {
    final projectId = widget.projectId;
    if (projectId == null) return [];

    final tasks = await SupervisorDashboardDataService.fetchTasksForProject(
      projectId,
    );

    final sorted = List<Map<String, dynamic>>.from(tasks)
      ..sort((a, b) {
        final aUpdated = (a['updated_at'] as String?) ?? '';
        final bUpdated = (b['updated_at'] as String?) ?? '';
        return bUpdated.compareTo(aUpdated);
      });

    return sorted;
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

  bool _isCompletedStatus(dynamic rawStatus) {
    return (rawStatus ?? '').toString().trim().toLowerCase() == 'completed';
  }

  int? _phaseIdForTask(Map<String, dynamic> task) {
    final phaseRaw = task['phase'] ?? task['phase_id'];
    if (phaseRaw is int) return phaseRaw;
    return int.tryParse(phaseRaw?.toString() ?? '');
  }

  Map<int, ({int total, int completed})> _buildPhaseStats(
    List<Map<String, dynamic>> tasks,
  ) {
    final stats = <int, ({int total, int completed})>{};

    for (final task in tasks) {
      final phaseId = _phaseIdForTask(task);
      if (phaseId == null) continue;

      final current = stats[phaseId] ?? (total: 0, completed: 0);
      final nextTotal = current.total + 1;
      final nextCompleted =
          current.completed + (_isCompletedStatus(task['status']) ? 1 : 0);
      stats[phaseId] = (total: nextTotal, completed: nextCompleted);
    }

    return stats;
  }

  double _progressForTask(
    Map<String, dynamic> task,
    String status,
    Map<int, ({int total, int completed})> phaseStats,
  ) {
    final dynamic raw =
        task['progress'] ?? task['progress_percent'] ?? task['completion'];

    if (raw is num) {
      final value = raw.toDouble();
      if (value > 1) {
        return (value / 100).clamp(0.0, 1.0);
      }
      return value.clamp(0.0, 1.0);
    }

    if (raw is String) {
      final parsed = double.tryParse(raw.trim());
      if (parsed != null) {
        if (parsed > 1) {
          return (parsed / 100).clamp(0.0, 1.0);
        }
        return parsed.clamp(0.0, 1.0);
      }
    }

    final phaseId = _phaseIdForTask(task);
    final phaseStat = phaseId != null ? phaseStats[phaseId] : null;
    if (phaseStat != null && phaseStat.total > 0) {
      final ratio = phaseStat.completed / phaseStat.total;
      return ratio.clamp(0.0, 1.0);
    }

    switch (status) {
      case "Completed":
        return 1.0;
      case "In Progress":
        return 0.5;
      case "In Review":
        return 0.8;
      case "Pending":
      case "Assigned":
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
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
      color: Colors.white,
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
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _tasksFuture,
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? 0;
                    final canToggle = count > 4;

                    return TextButton(
                      onPressed: canToggle
                          ? () {
                              setState(() {
                                _showAllTasks = !_showAllTasks;
                              });
                            }
                          : null,
                      child: Text(
                        _showAllTasks ? 'Show less' : 'View all',
                        style: TextStyle(
                          fontSize: 13,
                          color: canToggle
                              ? const Color(0xFFFF6F00)
                              : Colors.grey,
                        ),
                      ),
                    );
                  },
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

                  final phaseStats = _buildPhaseStats(tasks);
                  final visibleTasks = _showAllTasks
                      ? tasks
                      : tasks.take(4).toList(growable: false);

                  return Column(
                    children: visibleTasks.map((task) {
                      final title =
                          (task['title'] as String?) ?? 'Untitled task';
                      final rawStatus =
                          (task['status'] as String?) ?? 'pending';
                      final status = _statusLabel(rawStatus);
                      final color = getStatusColor(status);
                      final progress = _progressForTask(
                        task,
                        status,
                        phaseStats,
                      );

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
                                    color: Colors.white,
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
