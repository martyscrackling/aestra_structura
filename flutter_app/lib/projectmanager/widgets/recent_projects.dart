import 'package:flutter/material.dart';

import '../../services/pm_dashboard_service.dart';

class RecentProjects extends StatelessWidget {
  final List<PmRecentProject> projects;

  const RecentProjects({super.key, required this.projects});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final isExtraSmallPhone = screenWidth <= 320;
    final isSmallPhone = screenWidth < 375;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    final titleSize = isExtraSmallPhone
        ? 13.0
        : isSmallPhone
        ? 14.0
        : isMobile
        ? 16.0
        : 18.0;
    final cardSpacing = isExtraSmallPhone
        ? 8.0
        : isSmallPhone
        ? 12.0
        : isMobile
        ? 16.0
        : isTablet
        ? 16.0
        : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Projects',
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0C1935),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () {},
              iconSize: isSmallPhone ? 18 : 20,
              color: Colors.grey[600],
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        SizedBox(height: cardSpacing),
        if (projects.isEmpty)
          Container(
            width: double.infinity,
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
            child: Text(
              'No projects yet.',
              style: TextStyle(color: Colors.grey[700]),
            ),
          )
        else
        // Responsive layout
        if (isMobile)
          // Mobile: Stack vertically
          Column(
            children: [
              for (final project in projects) ...[
                SizedBox(
                  width: double.infinity,
                  child: ProjectCard(
                    title: project.name,
                    location: project.location,
                    progress: project.progress,
                    tasksCompleted: project.tasksCompleted,
                    totalTasks: project.totalTasks,
                  ),
                ),
                if (project != projects.last) SizedBox(height: cardSpacing),
              ],
            ],
          )
        else if (isTablet)
          // Tablet: 2 cards per row
          Column(
            children: [
              _ProjectGrid(
                projects: projects,
                columns: 2,
                spacing: cardSpacing,
              ),
            ],
          )
        else
          // Desktop: 3 cards in a row
          _ProjectGrid(projects: projects, columns: 3, spacing: cardSpacing),
      ],
    );
  }
}

class _ProjectGrid extends StatelessWidget {
  final List<PmRecentProject> projects;
  final int columns;
  final double spacing;

  const _ProjectGrid({
    required this.projects,
    required this.columns,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <List<PmRecentProject>>[];
    for (var i = 0; i < projects.length; i += columns) {
      final end = (i + columns) > projects.length
          ? projects.length
          : (i + columns);
      rows.add(projects.sublist(i, end));
    }

    return Column(
      children: [
        for (final row in rows) ...[
          Row(
            children: [
              for (final project in row) ...[
                Expanded(
                  child: ProjectCard(
                    title: project.name,
                    location: project.location,
                    progress: project.progress,
                    tasksCompleted: project.tasksCompleted,
                    totalTasks: project.totalTasks,
                  ),
                ),
                if (project != row.last) SizedBox(width: spacing),
              ],
              for (var i = row.length; i < columns; i++) ...[
                SizedBox(width: spacing),
                const Expanded(child: SizedBox.shrink()),
              ],
            ],
          ),
          if (row != rows.last) SizedBox(height: spacing),
        ],
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isExtraSmallPhone = screenWidth <= 320;
    final isSmallPhone = screenWidth < 375;
    final padding = isExtraSmallPhone
        ? 10.0
        : isSmallPhone
        ? 12.0
        : 16.0;

    return Container(
      constraints: BoxConstraints(
        minWidth: isExtraSmallPhone
            ? 150
            : 200, // Adjust for very small screens
      ),
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
        mainAxisSize: MainAxisSize.min,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () {},
                iconSize: 18,
                color: Colors.grey,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            location,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
