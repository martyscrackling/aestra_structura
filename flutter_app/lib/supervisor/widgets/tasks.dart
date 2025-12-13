import 'package:flutter/material.dart';

class Tasks extends StatelessWidget {
  const Tasks({super.key});

  final List<Map<String, String>> tasks = const [
    {"title": "Site survey, layout, soil test, clear site.", "status": "In Progress"},
    {"title": "Mobilize equipment, set up temporary facilities (storage, worker quarters).", "status": "Completed"},
    {"title": "Excavation for foundation.", "status": "Pending"},
    {"title": "Continue excavation, soil compaction.", "status": "In Review"},
  ];

  Color getStatusColor(String status) {
    switch (status) {
      case "Completed":
        return const Color(0xFF6CBA63);
      case "In Progress":
        return const Color(0xFF1396E9);
      case "Pending":
        return const Color(0xFFFFA726);
      case "In Review":
        return const Color(0xFF8E44AD);
      default:
        return Colors.grey;
    }
  }

  double _progressFor(String status) {
    switch (status) {
      case "Completed":
        return 1.0;
      case "In Progress":
        return 0.45;
      case "In Review":
        return 0.78;
      case "Pending":
        return 0.12;
      default:
        return 0.0;
    }
  }

  String _initials(String title) {
    final parts = title.split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Widget _statusChip(String status) {
    final color = getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Tasks To Do",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    "View all",
                    style: TextStyle(fontSize: 13, color: Color(0xFF1396E9)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tasks list
            Column(
              children: tasks.map((task) {
                final title = task["title"]!;
                final status = task["status"]!;
                final color = getStatusColor(status);
                final progress = _progressFor(status);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Avatar / initials
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  _initials(title),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2E3A44)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Title and small meta
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2E3A44)),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey[500]),
                                      const SizedBox(width: 6),
                                      Text(
                                        status == "Completed" ? "Done" : "Due soon",
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                      ),
                                      const SizedBox(width: 12),
                                      _statusChip(status),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Menu
                            PopupMenuButton<int>(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.more_horiz, color: Colors.grey),
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 0, child: Text('Edit')),
                                PopupMenuItem(value: 1, child: Text('Delete')),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Progress row
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 8,
                                  color: color,
                                  backgroundColor: Colors.grey[200],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('${(progress * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
