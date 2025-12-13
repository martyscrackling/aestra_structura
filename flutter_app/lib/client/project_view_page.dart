import 'package:flutter/material.dart';
import 'models/project_item.dart';

class ProjectViewPage extends StatelessWidget {
  const ProjectViewPage({super.key, required this.project});

  final ProjectItem project;

  // Sample weekly breakdown and tasks. In a real app these would come from the
  // `tasks` and `progress_logs` tables in the database filtered by project_id.
  List<_Week> get _weeks => [
        _Week(
          title: 'Week 1 - Pre-Construction & Site Prep',
          date: 'Sept 28',
          tasks: [
            _TaskItem(
              title: 'Site survey, layout, soil test, clear site.',
              imageUrl:
                  'https://images.unsplash.com/photo-1545259742-9e4f2baf2d4d?auto=format&fit=crop&w=800&q=60',
            ),
            _TaskItem(title: 'Mobilize equipment, set up temporary facilities.', imageUrl: ''),
            _TaskItem(title: 'Excavation for foundation.', imageUrl: ''),
          ],
        ),
        _Week(
          title: 'Week 2 - Foundation',
          date: 'Oct 5',
          tasks: [
            _TaskItem(title: 'Build foundation by reinforcing, pouring, curing.', imageUrl: ''),
            _TaskItem(title: 'Inspect footings and foundation walls.', imageUrl: ''),
          ],
        ),
        _Week(
          title: 'Week 3 - Structural Framework',
          date: 'Oct 12',
          tasks: [
            _TaskItem(title: 'Construct beams, columns, slab preparation.', imageUrl: ''),
          ],
        ),
      ];

  void _showTasksModal(BuildContext context, _Week week) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 520),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(week.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Subtasks', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: week.tasks.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final t = week.tasks[index];
                      return ListTile(
                        leading: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                        ),
                        title: Text(t.title),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (t.imageUrl.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.image_outlined),
                                onPressed: () => _showImagePreview(context, t.imageUrl),
                              ),
                            PopupMenuButton<int>(
                              itemBuilder: (_) => [const PopupMenuItem(value: 1, child: Text('...'))],
                              icon: const Icon(Icons.more_horiz),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showImagePreview(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(url, fit: BoxFit.contain, errorBuilder: (c, e, s) => Container(
                height: 200,
                color: Colors.grey[200],
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
              )),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(project.title, style: const TextStyle(color: Color(0xFF0C1935))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              project.imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 200,
                color: Colors.grey[200],
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(project.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0C1935))),
          const SizedBox(height: 8),
          Text('${project.startDate}  •  ${project.endDate}', style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: LinearProgressIndicator(
                value: project.progress,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  project.progress > 0.7 ? Colors.green : project.progress > 0.4 ? Colors.orange : Colors.red,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('${(project.progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          Row(children: [const Icon(Icons.location_on_outlined, color: Color(0xFFFF7A18)), const SizedBox(width: 8), Expanded(child: Text(project.location))]),
          const SizedBox(height: 20),
          const Text('To Do', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          // Weekly sections
          ..._weeks.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
                  child: ListTile(
                    title: Text(w.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(w.date),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('${w.tasks.length}/${w.tasks.length}', style: const TextStyle(color: Color(0xFF6B7280))),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => _showTasksModal(context, w),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7A18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('View more', style: TextStyle(color: Colors.white)),
                      ),
                    ]),
                  ),
                ),
              )),
        ]),
      ),
    );
  }
}

class _Week {
  _Week({required this.title, required this.date, required this.tasks});
  final String title;
  final String date;
  final List<_TaskItem> tasks;
}

class _TaskItem {
  _TaskItem({required this.title, required this.imageUrl});
  final String title;
  final String imageUrl;
}
