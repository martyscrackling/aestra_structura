import 'package:flutter/material.dart';

class RecentProjects extends StatelessWidget {
  const RecentProjects({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Projects',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0C1935),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () {},
              iconSize: 20,
              color: Colors.grey[600],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(
              child: ProjectCard(
                title: 'Super Highway',
                location: 'Divisoria, Zamboanga City',
                progress: 0.55,
                tasksCompleted: 8,
                totalTasks: 15,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: ProjectCard(
                title: 'Richmond\'s House',
                location: 'Sta. Maria, Zamboanga City',
                progress: 0.30,
                tasksCompleted: 8,
                totalTasks: 40,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: ProjectCard(
                title: 'Diversion Road',
                location: 'Luyahan, Zamboanga City',
                progress: 0.89,
                tasksCompleted: 40,
                totalTasks: 53,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ProjectCard extends StatelessWidget {
  final String title;
  final String location;
  final double progress;
  final int tasksCompleted;
  final int totalTasks;

  const ProjectCard({
    super.key,
    required this.title,
    required this.location,
    required this.progress,
    required this.tasksCompleted,
    required this.totalTasks,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0C1935),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () {},
                iconSize: 18,
                color: Colors.grey,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            location,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(
                      progress > 0.7
                          ? Colors.green
                          : progress > 0.4
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0C1935),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.check_box_outlined, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '$tasksCompleted/$totalTasks',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              _buildAvatarStack(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarStack() {
    return SizedBox(
      width: 70,
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
          Positioned(
            left: 36,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.grey[400],
              child: const Text(
                '+2',
                style: TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
