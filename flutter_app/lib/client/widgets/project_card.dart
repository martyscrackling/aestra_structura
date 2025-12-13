import 'package:flutter/material.dart';
import '../models/project_item.dart';
import '../project_view_page.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.item});

  final ProjectItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Image.network(
                  item.imageUrl,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 140,
                    color: Colors.grey[200],
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                  ),
                ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0C1935),
                        ),
                      ),
                    ),
                        // Non-interactive overflow icon for clients (read-only access)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.more_horiz, color: Colors.grey),
                        ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.startDate}  •  ${item.endDate}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: item.progress,
                          minHeight: 6,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(
                            item.progress > 0.7
                                ? Colors.green
                                : item.progress > 0.4
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(item.progress * 100).toInt()}%',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0C1935)),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFFFF7A18)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.location,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_box_outlined, size: 16, color: Color(0xFF6B7280)),
                        const SizedBox(width: 6),
                        Text('${item.tasksCompleted}/${item.totalTasks}', style: const TextStyle(color: Color(0xFF6B7280))),
                      ],
                    ),
                    const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            // Open read-only project view
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ProjectViewPage(project: item),
                            ));
                          },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('View more', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
