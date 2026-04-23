import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/budget_service.dart';

/// Dialog that lets the Project Manager edit the project's total budget.
///
/// Returns the updated project map from the backend on success (so the
/// caller can refresh its state), or null on cancel.
class EditProjectBudgetModal extends StatefulWidget {
  final int projectId;
  final String projectName;
  final num currentBudget;
  final num totalAllocated;

  const EditProjectBudgetModal({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.currentBudget,
    required this.totalAllocated,
  });

  @override
  State<EditProjectBudgetModal> createState() => _EditProjectBudgetModalState();
}

class _EditProjectBudgetModalState extends State<EditProjectBudgetModal> {
  late final TextEditingController _controller;
  bool _submitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentBudget.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    final value = double.tryParse(raw);
    if (value == null) {
      setState(() => _errorText = 'Enter a valid number.');
      return;
    }
    if (value < 0) {
      setState(() => _errorText = 'Budget cannot be negative.');
      return;
    }
    if (value < widget.totalAllocated) {
      setState(
        () => _errorText =
            'New budget (${value.toStringAsFixed(2)}) is less than the sum '
            'of phase allocations (${widget.totalAllocated}). Reduce phase '
            'allocations first.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      final updated = await BudgetService.setProjectBudget(
        projectId: widget.projectId,
        budget: value,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on BudgetApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = 'Unexpected error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit budget — ${widget.projectName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Currently allocated across phases: ₱${widget.totalAllocated}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              prefixText: '₱ ',
              labelText: 'Total project budget',
              border: const OutlineInputBorder(),
              errorText: _errorText,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
