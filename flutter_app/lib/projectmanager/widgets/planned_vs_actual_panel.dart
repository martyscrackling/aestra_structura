import 'package:flutter/material.dart';
import '../../services/budget_service.dart';

/// Read-only panel that renders `GET /phases/<id>/planned-vs-actual/`
/// as a compact table of Planned qty/cost vs Actual qty/cost with
/// variance chips. Used by both PM and Supervisor modals.
class PlannedVsActualPanel extends StatefulWidget {
  final int phaseId;

  const PlannedVsActualPanel({super.key, required this.phaseId});

  @override
  State<PlannedVsActualPanel> createState() => PlannedVsActualPanelState();
}

class PlannedVsActualPanelState extends State<PlannedVsActualPanel> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await BudgetService.getPlannedVsActual(
        phaseId: widget.phaseId,
      );
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
      });
    } on BudgetApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load report: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _error!,
            style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
          ),
          TextButton.icon(
            onPressed: reload,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      );
    }

    final items = (_data?['items'] as List?) ?? const [];
    final allocated = _asDouble(_data?['allocated_budget']);
    final used = _asDouble(_data?['used_budget']);
    final phaseStatus = (_data?['phase_status'] ?? '').toString();
    final isPhaseCompleted = phaseStatus == 'completed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Material usage',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0C1935),
              ),
            ),
            if (isPhaseCompleted) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'phase closed',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ],
            const Spacer(),
            Text(
              'Budget: ₱${_fmt(used)} / ₱${_fmt(allocated)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              'No materials assigned or used yet for this phase.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          )
        else
          _buildTable(items),
      ],
    );
  }

  Widget _buildTable(List items) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: const Row(
              children: [
                Expanded(flex: 4, child: _HeaderCell('Material')),
                Expanded(flex: 2, child: _HeaderCell('Assigned', right: true)),
                Expanded(flex: 2, child: _HeaderCell('Used', right: true)),
                Expanded(flex: 2, child: _HeaderCell('Remaining', right: true)),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++)
            _ItemRow(
              item: Map<String, dynamic>.from(items[i] as Map),
              isLast: i == items.length - 1,
            ),
        ],
      ),
    );
  }

  static double _asDouble(Object? v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static String _fmt(double v) {
    final fixed = v.toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return '$intPart.${parts[1]}';
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final bool right;

  const _HeaderCell(this.label, {this.right = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isLast;

  const _ItemRow({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final name = (item['inventory_item_name'] ?? '-') as String;
    final unit = ((item['unit_of_measure'] ?? '').toString().trim().isEmpty)
        ? ''
        : (item['unit_of_measure']).toString().trim();
    final assignedQty = (item['planned_quantity'] ?? 0) as num;
    final usedQty = (item['actual_quantity'] ?? 0) as num;
    final assignedCost = PlannedVsActualPanelState._asDouble(
      item['planned_cost'],
    );
    final usedCost = PlannedVsActualPanelState._asDouble(item['actual_cost']);
    final hasAssignment = (item['has_plan'] ?? true) as bool;
    // `remaining_quantity` is provided by the server (clamped at 0). Fall
    // back to a local calc so older payloads still render.
    final remainingQty = item.containsKey('remaining_quantity')
        ? (item['remaining_quantity'] ?? 0) as num
        : (assignedQty - usedQty).clamp(0, double.infinity);
    final isClosed = (item['plan_status']?.toString() ?? '') == 'closed';
    final leftover = (item['leftover_quantity'] ?? 0) as num;
    final overUsed = hasAssignment && usedQty > assignedQty;
    final depleted = hasAssignment && remainingQty <= 0 && assignedQty > 0;
    final stPlans = item['subtask_plans'];
    String? stPlanLine;
    if (stPlans is List && stPlans.isNotEmpty) {
      stPlanLine = stPlans
          .map((e) {
            if (e is! Map) return '';
            final t = (e['subtask_title'] ?? '').toString().trim();
            final q = (e['planned_quantity'] ?? 0);
            if (t.isEmpty) {
              return '$q';
            }
            return '$q → $t';
          })
          .where((s) => s.isNotEmpty)
          .join('  ·  ');
    }

    final Color remainingColor;
    if (isClosed) {
      remainingColor = const Color(0xFF374151);
    } else if (overUsed) {
      remainingColor = const Color(0xFFB91C1C);
    } else if (depleted) {
      remainingColor = const Color(0xFFB45309);
    } else if (!hasAssignment) {
      remainingColor = const Color(0xFF6B7280);
    } else {
      remainingColor = const Color(0xFF2E7D32);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0C1935),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (stPlanLine != null && stPlanLine.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    stPlanLine,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF6B7280),
                      height: 1.2,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (isClosed)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      leftover > 0
                          ? 'closed • $leftover${unit.isEmpty ? '' : ' $unit'} returned'
                          : 'closed',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                      ),
                    ),
                  )
                else if (!hasAssignment)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'not assigned',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _QtyCostCell(qty: assignedQty, cost: assignedCost),
          ),
          Expanded(
            flex: 2,
            child: _QtyCostCell(qty: usedQty, cost: usedCost),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isClosed
                      ? '—'
                      : (hasAssignment ? remainingQty.toString() : '—'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: remainingColor,
                  ),
                ),
                if (overUsed && !isClosed)
                  Text(
                    'over by ${usedQty - assignedQty}',
                    style: TextStyle(fontSize: 10, color: remainingColor),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyCostCell extends StatelessWidget {
  final num qty;
  final double cost;

  const _QtyCostCell({required this.qty, required this.cost});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          qty.toString(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        Text(
          '₱${PlannedVsActualPanelState._fmt(cost)}',
          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}
