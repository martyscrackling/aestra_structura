import 'package:flutter/material.dart';

class ActiveWorkersWidget extends StatelessWidget {
  const ActiveWorkersWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Workers',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0C1935),
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
    return Container(
      padding: const EdgeInsets.all(16),
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
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF0C1935),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
