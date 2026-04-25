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

Future<void> showNewAccountTutorialDialog({
  required BuildContext context,
  required String roleLabel,
  required List<TutorialStepItem> steps,
  required Future<void> Function(String route) onStepAction,
}) async {
  if (steps.isEmpty) return;
  int currentIndex = 0;
  bool isWorking = false;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final currentStep = steps[currentIndex];
          final progress = '${currentIndex + 1} / ${steps.length}';

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school_outlined, color: Color(0xFF0C1935)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$roleLabel Tutorial',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0C1935),
                          ),
                        ),
                      ),
                      Text(
                        progress,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: (currentIndex + 1) / steps.length,
                    color: const Color(0xFF0C1935),
                    backgroundColor: const Color(0xFFE5EAF2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    currentStep.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0C1935),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentStep.description,
                    style: TextStyle(color: Colors.grey[700], height: 1.35),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: isWorking || currentIndex == 0
                            ? null
                            : () => setState(() => currentIndex -= 1),
                        child: const Text('Back'),
                      ),
                      ElevatedButton(
                        onPressed: isWorking
                            ? null
                            : () async {
                                setState(() => isWorking = true);
                                await onStepAction(currentStep.route);
                                if (!dialogContext.mounted) return;
                                setState(() => isWorking = false);
                                Navigator.of(dialogContext).pop();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0C1935),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(currentStep.actionLabel),
                      ),
                      TextButton(
                        onPressed: isWorking
                            ? null
                            : () {
                                if (currentIndex < steps.length - 1) {
                                  setState(() => currentIndex += 1);
                                } else {
                                  Navigator.of(dialogContext).pop();
                                }
                              },
                        child: Text(
                          currentIndex < steps.length - 1 ? 'Next' : 'Close',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
