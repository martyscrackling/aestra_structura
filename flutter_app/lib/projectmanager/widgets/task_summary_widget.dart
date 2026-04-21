import 'package:flutter/material.dart';

class TaskSummaryWidget extends StatelessWidget {
  final int totalProjects;
  final int assignedTasks;
  final int totalTasks;
  final double completionRate;

  const TaskSummaryWidget({
    super.key,
    required this.totalProjects,
    required this.assignedTasks,
    required this.totalTasks,
    required this.completionRate,
  });

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

    final displayedCompletion = completionRate.isNaN
        ? 0
        : completionRate.clamp(0, 100).round();

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
                'Task Summary',
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
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () {},
                iconSize: 20,
                color: Colors.grey[600],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(
                    isSmallPhone
                        ? 8.0
                        : isMobile
                        ? 12.0
                        : 16.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        color: Colors.white,
                        size: isSmallPhone ? 20.0 : 28.0,
                      ),
                      SizedBox(height: isSmallPhone ? 4.0 : 8.0),
                      Text(
                        'Projects',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallPhone ? 10.0 : 13.0,
                        ),
                      ),
                      SizedBox(height: isSmallPhone ? 2.0 : 4.0),
                      Text(
                        totalProjects.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallPhone ? 18.0 : 24.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: isSmallPhone
                    ? 6.0
                    : isMobile
                    ? 8.0
                    : 16.0,
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(
                    isSmallPhone
                        ? 8.0
                        : isMobile
                        ? 12.0
                        : 16.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.cyan[400],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        color: Colors.white,
                        size: isSmallPhone ? 20.0 : 28.0,
                      ),
                      SizedBox(height: isSmallPhone ? 4.0 : 8.0),
                      Text(
                        'Assigned',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallPhone ? 10.0 : 13.0,
                        ),
                      ),
                      SizedBox(height: isSmallPhone ? 2.0 : 4.0),
                      Text(
                        assignedTasks.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallPhone ? 18.0 : 24.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: isSmallPhone
                    ? 6.0
                    : isMobile
                    ? 8.0
                    : 16.0,
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(
                    isSmallPhone
                        ? 8.0
                        : isMobile
                        ? 12.0
                        : 16.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.grid_view_rounded,
                        color: Colors.grey[400],
                        size: isSmallPhone ? 20.0 : 28.0,
                      ),
                      SizedBox(height: isSmallPhone ? 4.0 : 8.0),
                      Text(
                        'All',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isSmallPhone ? 10.0 : 13.0,
                        ),
                      ),
                      SizedBox(height: isSmallPhone ? 2.0 : 4.0),
                      Text(
                        totalTasks.toString(),
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: isSmallPhone ? 18.0 : 24.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'On-time Completion Rate',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$displayedCompletion%',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C1935),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
