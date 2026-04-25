import 'package:flutter/material.dart';

class TutorialStepItem {
  const TutorialStepItem({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.route,
  });

  final String title;
  final String description;
  final String actionLabel;
  final String route;
}

enum _TutorialStepChoice { back, next, doAction, close }

Future<void> showNewAccountTutorialDialog({
  required BuildContext context,
  required String roleLabel,
  required List<TutorialStepItem> steps,
  required Future<void> Function(String route) onStepAction,
  int startIndex = 0,
}) async {
  if (steps.isEmpty) return;
  var currentIndex = startIndex.clamp(0, steps.length - 1);

  while (context.mounted && currentIndex >= 0 && currentIndex < steps.length) {
    final currentStep = steps[currentIndex];
    final progress = '${currentIndex + 1} / ${steps.length}';
    final choice = await showDialog<_TutorialStepChoice>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          title: Row(
            children: [
              const Icon(Icons.mark_chat_read_outlined, color: Color(0xFF0C1935)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$roleLabel Tutorial',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0C1935),
                  ),
                ),
              ),
              Text(
                progress,
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: (currentIndex + 1) / steps.length,
                color: const Color(0xFF0C1935),
                backgroundColor: const Color(0xFFE5EAF2),
              ),
              const SizedBox(height: 12),
              Text(
                currentStep.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C1935),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                currentStep.description,
                style: TextStyle(color: Colors.grey[700], height: 1.35),
              ),
              const SizedBox(height: 8),
              Text(
                'Tip: finish this step, then return here and we will continue.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            if (currentIndex > 0)
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(_TutorialStepChoice.back),
                child: const Text('Back'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                currentIndex < steps.length - 1
                    ? _TutorialStepChoice.next
                    : _TutorialStepChoice.close,
              ),
              child: Text(currentIndex < steps.length - 1 ? 'Next tip' : 'Close'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_TutorialStepChoice.doAction),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C1935),
                foregroundColor: Colors.white,
              ),
              child: Text('Do now: ${currentStep.actionLabel}'),
            ),
          ],
        );
      },
    );

    if (choice == _TutorialStepChoice.back) {
      currentIndex -= 1;
      continue;
    }
    if (choice == _TutorialStepChoice.next) {
      currentIndex += 1;
      continue;
    }
    if (choice == _TutorialStepChoice.doAction) {
      await onStepAction(currentStep.route);
      return;
    }
    return;
  }
}
