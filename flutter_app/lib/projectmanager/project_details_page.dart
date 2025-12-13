import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'modals/task_details_modal.dart';

class WeeklyTask {
  final String weekTitle;
  final String description;
  final String status;
  final String date;
  final double progress;

  WeeklyTask({
    required this.weekTitle,
    required this.description,
    required this.status,
    required this.date,
    required this.progress,
  });
}

class ProjectDetailsPage extends StatelessWidget {
  final String projectTitle;
  final String projectLocation;
  final String projectImage;
  final double progress;
  final String? budget;

  const ProjectDetailsPage({
    super.key,
    required this.projectTitle,
    required this.projectLocation,
    required this.projectImage,
    required this.progress,
    this.budget,
  });

  static final List<WeeklyTask> _todoTasks = [
    WeeklyTask(
      weekTitle: 'Week 5 - Pre-Construction & Site Prep',
      description:
          'Conduct site survey, clearing, excavation, soil compaction, and set up temporary facilities.',
      status: 'In-Process',
      date: 'Sept 28',
      progress: 0.65,
    ),
    WeeklyTask(
      weekTitle: 'Week 6 - Foundation',
      description:
          'Build foundation by reinforcing, pouring, curing, and inspecting footings and foundation walls.',
      status: 'In-Process',
      date: 'Oct 5',
      progress: 0.45,
    ),
    WeeklyTask(
      weekTitle: 'Week 7 - Structural Framework',
      description:
          'Construct the structural framework, including beams, columns, and slab preparation.',
      status: 'In-Process',
      date: 'Oct 12',
      progress: 0.30,
    ),
    WeeklyTask(
      weekTitle: 'Week 8 - Superstructure & Roofing',
      description:
          'Complete slab concreting, masonry works, install frames, set roof trusses, and finish with roofing and cleanup.',
      status: 'In-Process',
      date: 'Oct 19',
      progress: 0.15,
    ),
  ];

  static final List<WeeklyTask> _finishedTasks = [
    WeeklyTask(
      weekTitle: 'Week 1 - Pre-Construction & Site Prep',
      description:
          'Conduct site survey, clearing, excavation, soil compaction, and set up temporary facilities.',
      status: 'Completed',
      date: 'Completed',
      progress: 1.0,
    ),
    WeeklyTask(
      weekTitle: 'Week 2 - Foundation',
      description:
          'Build foundation by reinforcing, pouring, curing, and inspecting footings and foundation walls.',
      status: 'Completed',
      date: 'Completed',
      progress: 1.0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          const Sidebar(currentPage: 'Projects'),
          Expanded(
            child: Column(
              children: [
                const DashboardHeader(title: 'Projects'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back button and project header
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back),
                              color: const Color(0xFF0C1935),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  projectTitle,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0C1935),
                                  ),
                                ),
                                Text(
                                  projectLocation,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Project info badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: progress >= 1
                                    ? const Color(0xFFE5F8ED)
                                    : const Color(0xFFFFF2E8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${(progress * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: progress >= 1
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFFF7A18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (budget != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.account_balance_wallet_outlined,
                                      size: 16,
                                      color: Color(0xFF2E7D32),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '₱ $budget',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: AssetImage(projectImage),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Tabs
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _TabButton(
                                label: 'List',
                                icon: Icons.list,
                                isSelected: true,
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Search and Filter
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 18,
                                  ),
                                  hintText: 'Search task...',
                                  hintStyle: const TextStyle(fontSize: 13),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0C1935),
                                side: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.filter_list, size: 18),
                              label: const Text('Filter'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0C1935),
                                side: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.sort, size: 18),
                              label: const Text('Sort: Date Created'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // To Do Section
                        _TaskSection(
                          title: 'To Do',
                          count: _todoTasks.length,
                          tasks: _todoTasks,
                        ),
                        const SizedBox(height: 24),

                        // Finished Section
                        _TaskSection(
                          title: 'Finished',
                          count: _finishedTasks.length,
                          tasks: _finishedTasks,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.transparent,
        foregroundColor: isSelected ? Colors.white : const Color(0xFF6B7280),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _TaskSection extends StatelessWidget {
  final String title;
  final int count;
  final List<WeeklyTask> tasks;

  const _TaskSection({
    required this.title,
    required this.count,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  '$title /$count',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0C1935),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 20),
                  color: const Color(0xFF6B7280),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz, size: 20),
                  color: const Color(0xFF6B7280),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...tasks.map((task) => _WeeklyTaskCard(task: task)),
        ],
      ),
    );
  }
}

class _WeeklyTaskCard extends StatelessWidget {
  final WeeklyTask task;

  const _WeeklyTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.weekTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      task.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        task.date,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => TaskDetailsModal(task: task),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A18),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'View more',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: task.progress >= 1
                      ? const Color(0xFFE5F8ED)
                      : const Color(0xFFFFF2E8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  task.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: task.progress >= 1
                        ? const Color(0xFF10B981)
                        : const Color(0xFFFF7A18),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${(task.progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
