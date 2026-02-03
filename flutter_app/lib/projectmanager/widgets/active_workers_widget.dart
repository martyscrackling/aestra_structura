import 'package:flutter/material.dart';

class ActiveWorkersWidget extends StatelessWidget {
  const ActiveWorkersWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    final isSmallPhone = screenWidth < 375;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Workers',
          style: TextStyle(
            fontSize: isSmallPhone ? 14.0 : isMobile ? 16.0 : isTablet ? 17.0 : 18.0,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0C1935),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(
              child: WorkerCard(
                icon: Icons.business_center_outlined,
                title: 'Project Managers',
                count: 32,
                color: Colors.orange,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: WorkerCard(
                icon: Icons.architecture_outlined,
                title: 'Architects',
                count: 32,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(
              child: WorkerCard(
                icon: Icons.engineering_outlined,
                title: 'Engineers',
                count: 32,
                color: Colors.orange,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: WorkerCard(
                icon: Icons.supervisor_account_outlined,
                title: 'Supervisors',
                count: 32,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class WorkerCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color color;

  const WorkerCard({
    super.key,
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    final isSmallPhone = screenWidth < 375;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    
    final padding = isSmallPhone ? 10.0 : isMobile ? 12.0 : isTablet ? 14.0 : 16.0;
    final iconSize = isSmallPhone ? 32.0 : isMobile ? 36.0 : isTablet ? 40.0 : 48.0;
    final spacing = isSmallPhone ? 6.0 : isMobile ? 8.0 : 12.0;
    final titleSize = isSmallPhone ? 10.0 : isMobile ? 11.0 : isTablet ? 12.0 : 13.0;
    final countSize = isSmallPhone ? 18.0 : isMobile ? 20.0 : isTablet ? 22.0 : 24.0;

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
        children: [
          Icon(icon, size: iconSize, color: color),
          SizedBox(height: spacing),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: titleSize,
              color: const Color(0xFF0C1935),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: countSize,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
