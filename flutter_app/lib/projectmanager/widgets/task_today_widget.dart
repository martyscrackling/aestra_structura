import 'package:flutter/material.dart';

import '../../services/pm_dashboard_service.dart';

class TaskTodayWidget extends StatelessWidget {
  final List<PmTaskTodayItem> tasksToday;

  const TaskTodayWidget({super.key, required this.tasksToday});

  ({String label, Color color}) _statusUi(String raw) {
    final s = raw.toLowerCase();
    if (s == 'completed') {
      return (label: 'Completed', color: Colors.green);
    }
    if (s == 'in_progress' || s == 'in progress') {
      return (label: 'In Progress', color: Colors.blue);
    }
    if (s == 'assigned') {
      return (label: 'Assigned', color: Colors.orange);
    }
    if (s == 'pending') {
      return (label: 'Pending', color: Colors.grey);
    }
    return (label: raw, color: Colors.grey);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final isSmallPhone = screenWidth < 375;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    final padding = isSmallPhone
        ? 12.0
        : isMobile
        ? 16.0
        : 20.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Task Today',
                style: TextStyle(
                  fontSize: isSmallPhone
                      ? 14.0
                      : isMobile
                      ? 16.0
                      : isTablet
                      ? 17.0
                      : 18.0,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0C1935),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Row(
                  children: const [
                    Text(
                      'See All',
                      style: TextStyle(fontSize: 13, color: Colors.blue),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 16, color: Colors.blue),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '/${tasksToday.length}',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          if (tasksToday.isEmpty)
            Text('No tasks yet.', style: TextStyle(color: Colors.grey[700]))
          else
            ...tasksToday.map(_buildTaskItem),
        ],
      ),
    );
  }

  Widget _buildTaskItem(PmTaskTodayItem task) {
    final statusUi = _statusUi(task.status);
    final isCompleted = task.status.toLowerCase() == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isCompleted,
            onChanged: null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.title,
              style: const TextStyle(fontSize: 14, color: Color(0xFF0C1935)),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusUi.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusUi.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusUi.color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (task.assignedWorkers.isNotEmpty)
            _buildAvatarStack(task.assignedWorkers),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {},
            iconSize: 18,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarStack(List<PmAssignedWorker> workers) {
    final shown = workers.take(2).toList();
    final colors = [Colors.blue[300], Colors.orange[300]];

    return SizedBox(
      width: 50,
      height: 24,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i == 0 ? 0 : 18,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: colors[i] ?? Colors.blueGrey,
                child: Text(
                  shown[i].fullName.isNotEmpty
                      ? shown[i].fullName.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
