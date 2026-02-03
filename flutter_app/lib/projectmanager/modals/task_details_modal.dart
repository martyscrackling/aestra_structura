import 'package:flutter/material.dart';
import '../project_details_page.dart';
import 'photo_viewer_modal.dart';

class SubTask {
  final String title;
  final bool isCompleted;

  SubTask({required this.title, required this.isCompleted});
}

// Modal for displaying Phase subtasks from database
class PhaseDetailsModal extends StatelessWidget {
  final Phase phase;

  const PhaseDetailsModal({super.key, required this.phase});

  @override
  Widget build(BuildContext context) {
    final completedCount = phase.subtasks
        .where((s) => s.status == 'completed')
        .length;
    final progress = phase.subtasks.isEmpty
        ? 0.0
        : completedCount / phase.subtasks.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          phase.phaseName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0C1935),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: phase.status == 'completed'
                                ? const Color(0xFFE5F8ED)
                                : const Color(0xFFFFF2E8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: phase.status == 'completed'
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFFF7A18),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                phase.status.replaceAll('_', ' ').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: phase.status == 'completed'
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFFF7A18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    if (phase.description != null &&
                        phase.description!.isNotEmpty) ...[
                      Text(
                        phase.description!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Progress bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: const Color(0xFFF3F4F6),
                              valueColor: AlwaysStoppedAnimation(
                                progress >= 1
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFFF7A18),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(progress * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0C1935),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Subtasks header
                    Text(
                      'Subtasks ($completedCount/${phase.subtasks.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Subtasks list
                    if (phase.subtasks.isEmpty)
                      const Text(
                        'No subtasks',
                        style: TextStyle(color: Color(0xFF6B7280)),
                      )
                    else
                      ...phase.subtasks.map(
                        (subtask) => _PhaseSubtaskItem(subtask: subtask),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseSubtaskItem extends StatelessWidget {
  final Subtask subtask;

  const _PhaseSubtaskItem({required this.subtask});

  @override
  Widget build(BuildContext context) {
    final isCompleted = subtask.status == 'completed';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: isCompleted
                ? const Color(0xFF10B981)
                : const Color(0xFF9CA3AF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              subtask.title,
              style: TextStyle(
                fontSize: 14,
                color: isCompleted
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF0C1935),
                decoration: isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isCompleted
                  ? const Color(0xFFE5F8ED)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              subtask.status.replaceAll('_', ' '),
              style: TextStyle(
                fontSize: 11,
                color: isCompleted
                    ? const Color(0xFF10B981)
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TaskDetailsModal extends StatelessWidget {
  final WeeklyTask task;

  const TaskDetailsModal({super.key, required this.task});

  static final List<SubTask> _subtasks = [
    SubTask(
      title: 'Site survey, layout, soil test, clear site.',
      isCompleted: true,
    ),
    SubTask(
      title:
          'Mobilize equipment, set up temporary facilities (storage, worker quarters).',
      isCompleted: true,
    ),
    SubTask(title: 'Excavation for foundation.', isCompleted: true),
    SubTask(title: 'Continue excavation, soil compaction.', isCompleted: true),
    SubTask(
      title: 'Marking & leveling foundation trenches.',
      isCompleted: true,
    ),
    SubTask(title: 'Excavation for foundation.', isCompleted: true),
    SubTask(title: 'Continue excavation, soil compaction.', isCompleted: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.weekTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0C1935),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: task.progress >= 1
                                ? const Color(0xFFE5F8ED)
                                : const Color(0xFFFFF2E8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: task.progress >= 1
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFFF7A18),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                task.status,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: task.progress >= 1
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFFF7A18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: task.progress,
                              minHeight: 10,
                              backgroundColor: const Color(0xFFF3F4F6),
                              valueColor: AlwaysStoppedAnimation(
                                task.progress >= 1
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFFF7A18),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(task.progress * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0C1935),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Subtasks header
                    const Text(
                      'Subtasks',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Subtasks list
                    ..._subtasks.map(
                      (subtask) => _SubtaskItem(subtask: subtask),
                    ),

                    const SizedBox(height: 24),

                    // Photo button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) =>
                                PhotoViewerModal(weekTitle: task.weekTitle),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          color: Color(0xFF0C1935),
                        ),
                        label: const Text(
                          'View Photos',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0C1935),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubtaskItem extends StatefulWidget {
  final SubTask subtask;

  const _SubtaskItem({required this.subtask});

  @override
  State<_SubtaskItem> createState() => _SubtaskItemState();
}

class _SubtaskItemState extends State<_SubtaskItem> {
  late bool _isChecked;

  @override
  void initState() {
    super.initState();
    _isChecked = widget.subtask.isCompleted;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _isChecked,
            onChanged: (value) {
              setState(() {
                _isChecked = value ?? false;
              });
            },
            activeColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                widget.subtask.title,
                style: TextStyle(
                  fontSize: 14,
                  color: _isChecked
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF0C1935),
                  decoration: _isChecked
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.copy, size: 16),
            color: const Color(0xFF9CA3AF),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz, size: 16),
            color: const Color(0xFF9CA3AF),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
