import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/budget_service.dart';

/// Dialog that lets the PM set allocated_budget for a specific phase.
///
/// Returns the updated phase map on success, null on cancel.
class AllocatePhaseBudgetModal extends StatefulWidget {
  final int phaseId;
  final String phaseName;
  final num currentAllocation;
  final num phaseUsedBudget;
  final num projectBudget;
  final num otherPhasesAllocated;

  const AllocatePhaseBudgetModal({
    super.key,
    required this.phaseId,
    required this.phaseName,
    required this.currentAllocation,
    required this.phaseUsedBudget,
    required this.projectBudget,
    required this.otherPhasesAllocated,
  });

  @override
  State<AllocatePhaseBudgetModal> createState() =>
      _AllocatePhaseBudgetModalState();
}

class _AllocatePhaseBudgetModalState extends State<AllocatePhaseBudgetModal> {
  late final TextEditingController _controller;
  bool _submitting = false;
  String? _errorText;

  num get _roomLeft => widget.projectBudget - widget.otherPhasesAllocated;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentAllocation.toStringAsFixed(2),
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
      setState(() => _errorText = 'Allocation cannot be negative.');
      return;
    }
    if (value < widget.phaseUsedBudget) {
      setState(
        () => _errorText =
            'Cannot allocate less than what has already been used '
            '(₱${widget.phaseUsedBudget}).',
      );
      return;
    }
    if (value > _roomLeft) {
      setState(
        () => _errorText =
            'Exceeds the project budget. Room left for this phase: '
            '₱${_roomLeft.toStringAsFixed(2)}.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      final updated = await BudgetService.allocatePhaseBudget(
        phaseId: widget.phaseId,
        allocatedBudget: value,
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
      title: Text('Allocate budget — ${widget.phaseName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            label: 'Project budget',
            value: '₱${widget.projectBudget}',
          ),
          _InfoRow(
            label: 'Other phases allocated',
            value: '₱${widget.otherPhasesAllocated}',
          ),
          _InfoRow(
            label: 'Room left for this phase',
            value: '₱${_roomLeft.toStringAsFixed(2)}',
            emphasised: true,
          ),
          _InfoRow(
            label: 'Already used in this phase',
            value: '₱${widget.phaseUsedBudget}',
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
              labelText: 'Allocated budget',
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasised;

  const _InfoRow({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: emphasised
                  ? const Color(0xFF0C1935)
                  : const Color(0xFF6B7280),
              fontWeight: emphasised ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: emphasised ? FontWeight.w700 : FontWeight.w600,
              color: emphasised
                  ? const Color(0xFF0C1935)
                  : const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}
