import 'package:flutter/material.dart';

import '../../services/pm_dashboard_service.dart';
import '../project_info.dart';

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

    final showCarousel = projects.length >= 4;

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
            if (showCarousel)
              _CarouselControls(
                onPrevious: () => _carouselKey.currentState?.previous(),
                onNext: () => _carouselKey.currentState?.next(),
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
        else if (showCarousel)
          _ProjectCarousel(
            key: _carouselKey,
            projects: projects,
            cardSpacing: cardSpacing,
            isMobile: isMobile,
            isTablet: isTablet,
          )
        else
          // Responsive layout for 1-3 projects
          if (isMobile)
            // Mobile: Stack vertically
            Column(
              children: [
                for (final project in projects) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ProjectCard(
                      projectId: project.projectId,
                      title: project.name,
                      location: project.location,
                      progress: project.progress,
                      tasksCompleted: project.tasksCompleted,
                      totalTasks: project.totalTasks,
                      image: project.image,
                      budget: project.budget,
                    ),
                  ),
                  if (project != projects.last) SizedBox(height: cardSpacing),
                ],
              ],
            )
          else if (isTablet)
            // Tablet: 2 cards per row
            _ProjectGrid(
              projects: projects,
              columns: 2,
              spacing: cardSpacing,
            )
          else
            // Desktop: 3 cards in a row
            _ProjectGrid(projects: projects, columns: 3, spacing: cardSpacing),
      ],
    );
  }

  static final GlobalKey<_ProjectCarouselState> _carouselKey =
      GlobalKey<_ProjectCarouselState>();
}


class _CarouselControls extends StatelessWidget {
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _CarouselControls({required this.onPrevious, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildButton(Icons.chevron_left, onPrevious),
        const SizedBox(width: 8),
        _buildButton(Icons.chevron_right, onNext),
      ],
    );
  }

  Widget _buildButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: const Color(0xFF0C1935)),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
    );
  }
}

class _ProjectCarousel extends StatefulWidget {
  final List<PmRecentProject> projects;
  final double cardSpacing;
  final bool isMobile;
  final bool isTablet;

  const _ProjectCarousel({
    super.key,
    required this.projects,
    required this.cardSpacing,
    required this.isMobile,
    required this.isTablet,
  });

  @override
  State<_ProjectCarousel> createState() => _ProjectCarouselState();
}

class _ProjectCarouselState extends State<_ProjectCarousel> {
  late PageController _controller;
  final int _baseIndex = 1000;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: _baseIndex,
      viewportFraction: widget.isMobile ? 0.92 : (widget.isTablet ? 0.48 : 0.32),
    );
  }

  void previous() {
    _controller.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200, // Matches ProjectCard height + buffer
      child: PageView.builder(
        controller: _controller,
        itemBuilder: (context, index) {
          final project = widget.projects[index % widget.projects.length];
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.cardSpacing / 4),
            child: ProjectCard(
              projectId: project.projectId,
              title: project.name,
              location: project.location,
              progress: project.progress,
              tasksCompleted: project.tasksCompleted,
              totalTasks: project.totalTasks,
              image: project.image,
              budget: project.budget,
            ),
          );
        },
      ),
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
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final project in row) ...[
                  Expanded(
                    child: ProjectCard(
                      projectId: project.projectId,
                      title: project.name,
                      location: project.location,
                      progress: project.progress,
                      tasksCompleted: project.tasksCompleted,
                      totalTasks: project.totalTasks,
                      image: project.image,
                      budget: project.budget,
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
          ),
          if (row != rows.last) SizedBox(height: spacing),
        ],
      ],
    );
  }
}

class ProjectCard extends StatelessWidget {
  final int projectId;
  final String title;
  final String location;
  final double progress;
  final int tasksCompleted;
  final int totalTasks;
  final String? image;
  final String? budget;

  const ProjectCard({
    super.key,
    required this.projectId,
    required this.title,
    required this.location,
    required this.progress,
    required this.tasksCompleted,
    required this.totalTasks,
    this.image,
    this.budget,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isExtraSmallPhone = screenWidth <= 320;
    final isSmallPhone = screenWidth < 375;
    final isDesktopOrTablet = screenWidth >= 768;
    final padding = isExtraSmallPhone
        ? 10.0
        : isSmallPhone
        ? 12.0
        : 14.0;

    return Container(
      constraints: BoxConstraints(minHeight: isDesktopOrTablet ? 170 : 0),
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
              _ViewButton(
                onPressed: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          ProjectDetailsPage(
                        projectTitle: title,
                        projectLocation: location,
                        projectImage: image ?? 'assets/images/engineer.jpg',
                        progress: progress,
                        budget: budget ?? '0',
                        projectId: projectId,
                      ),
                      transitionDuration: Duration.zero,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

}

class _ViewButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _ViewButton({required this.onPressed});

  @override
  State<_ViewButton> createState() => _ViewButtonState();
}

class _ViewButtonState extends State<_ViewButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    const darkBlue = Color(0xFF0C1935);
    const orange = Color(0xFFFF7A18);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
        },
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: _isPressed ? darkBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isPressed
                  ? darkBlue
                  : (_isHovered ? orange : orange.withOpacity(0.8)),
              width: 1.5,
            ),
          ),
          child: Text(
            'View',
            style: TextStyle(
              color: _isPressed ? Colors.white : orange,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
