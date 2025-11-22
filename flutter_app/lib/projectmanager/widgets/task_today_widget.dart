import 'package:flutter/material.dart';

class TaskTodayWidget extends StatefulWidget {
  const TaskTodayWidget({super.key});

  @override
  State<TaskTodayWidget> createState() => _TaskTodayWidgetState();
}

class _TaskTodayWidgetState extends State<TaskTodayWidget> {
  final List<Map<String, dynamic>> tasks = [
    {
      'title': 'Create userflow for Hisphonic Application Design',
      'status': 'In Review',
      'statusColor': Colors.orange,
      'checked': true,
    },
    {
      'title': 'Homepage design for Diphub Application',
      'status': 'In Progress',
      'statusColor': Colors.green,
      'checked': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              const Text(
                'Task Today',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C1935),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Row(
                  children: const [
                    Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue,
                      ),
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
            '/10',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ...tasks.map((task) => _buildTaskItem(task)),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
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
            value: task['checked'],
            onChanged: (value) {
              setState(() {
                task['checked'] = value;
              });
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task['title'],
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF0C1935),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: task['statusColor'].withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              task['status'],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: task['statusColor'],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildAvatarStack(),
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

  Widget _buildAvatarStack() {
    return SizedBox(
      width: 50,
      height: 24,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.blue[300],
              child: const Icon(Icons.person, size: 12, color: Colors.white),
            ),
          ),
          Positioned(
            left: 18,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.orange[300],
              child: const Icon(Icons.person, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
