import 'package:flutter/material.dart';
import '../models/project_item.dart';
import 'project_card.dart';

class ProjectsGrid extends StatelessWidget {
  const ProjectsGrid({super.key, required this.items});

  final List<ProjectItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columnCount = constraints.maxWidth > 1300
          ? 3
          : constraints.maxWidth > 900
              ? 3
              : constraints.maxWidth > 700
                  ? 2
                  : 1;

      final cardWidth = (constraints.maxWidth - (columnCount - 1) * 16) / columnCount;

      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: items
            .map((p) => SizedBox(width: cardWidth, child: ProjectCard(item: p)))
            .toList(),
      );
    });
  }
}
