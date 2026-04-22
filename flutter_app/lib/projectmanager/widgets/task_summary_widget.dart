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
              Expanded(
                child: Text(
                  'Task Summary',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _SummaryStatCard(
                  label: 'Projects',
                  value: totalProjects.toString(),
                  icon: Icons.folder_outlined,
                  iconColor: Colors.white,
                  labelColor: Colors.white,
                  valueColor: Colors.white,
                  backgroundColor: Colors.blue[600]!,
                  isSmallPhone: isSmallPhone,
                  isMobile: isMobile,
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
                child: _SummaryStatCard(
                  label: 'Assigned',
                  value: assignedTasks.toString(),
                  icon: Icons.assignment_outlined,
                  iconColor: Colors.white,
                  labelColor: Colors.white,
                  valueColor: Colors.white,
                  backgroundColor: Colors.cyan[400]!,
                  isSmallPhone: isSmallPhone,
                  isMobile: isMobile,
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
                child: _SummaryStatCard(
                  label: 'All',
                  value: totalTasks.toString(),
                  icon: Icons.grid_view_rounded,
                  iconColor: Colors.grey[400]!,
                  labelColor: Colors.grey[600]!,
                  valueColor: Colors.grey[800]!,
                  backgroundColor: Colors.grey[100]!,
                  isSmallPhone: isSmallPhone,
                  isMobile: isMobile,
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

class _SummaryStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color labelColor;
  final Color valueColor;
  final Color backgroundColor;
  final bool isSmallPhone;
  final bool isMobile;

  const _SummaryStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.labelColor,
    required this.valueColor,
    required this.backgroundColor,
    required this.isSmallPhone,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        isSmallPhone
            ? 8.0
            : isMobile
            ? 12.0
            : 16.0,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: isSmallPhone ? 20.0 : 28.0),
          SizedBox(height: isSmallPhone ? 4.0 : 8.0),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: labelColor,
                  fontSize: isSmallPhone ? 10.0 : 13.0,
                  height: 1.2,
                ),
              ),
            ),
          ),
          SizedBox(height: isSmallPhone ? 2.0 : 4.0),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: isSmallPhone ? 18.0 : 24.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
