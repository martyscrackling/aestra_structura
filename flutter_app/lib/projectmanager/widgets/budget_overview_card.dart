import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/budget_service.dart';
import '../modals/edit_project_budget_modal.dart';
import '../modals/allocate_phase_budget_modal.dart';
import '../modals/phase_material_plan_modal.dart';

/// Drop-in card that the PM sees on project details. It fetches
/// `/projects/<id>/budget-summary/` and renders:
///   - total budget / allocated / used / remaining
///   - consumed progress bar + 50% warning banner
///   - per-phase rows with allocate-budget editor
class BudgetOverviewCard extends StatefulWidget {
  final int projectId;
  final String projectName;

  /// Called whenever the summary is (re)loaded successfully, so the parent
  /// page can react if it needs to (e.g. show a toast, refresh other
  /// widgets). Optional.
  final ValueChanged<Map<String, dynamic>>? onSummaryLoaded;

  const BudgetOverviewCard({
    super.key,
    required this.projectId,
    required this.projectName,
    this.onSummaryLoaded,
  });

  @override
  State<BudgetOverviewCard> createState() => BudgetOverviewCardState();
}

class BudgetOverviewCardState extends State<BudgetOverviewCard> {
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Public so the parent page can trigger a refresh after recording a
  /// usage or making other changes.
  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await BudgetService.getBudgetSummary(
        projectId: widget.projectId,
      );
      if (!mounted) return;
      setState(() {
        _summary = data;
        _loading = false;
      });
      widget.onSummaryLoaded?.call(data);
    } on BudgetApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load budget: $e';
        _loading = false;
      });
    }
  }

  // ── render ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: _loading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : _error != null
          ? _buildError()
          : _buildLoaded(),
    );
  }

  Widget _buildError() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Budget Overview',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0C1935),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _error!,
          style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: reload,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildLoaded() {
    final summary = _summary!;
    final total = _asDouble(summary['total_budget']);
    final allocated = _asDouble(summary['total_allocated']);
    final used = _asDouble(summary['total_used']);
    final remaining = _asDouble(summary['remaining_budget']);
    final phases = (summary['phases'] as List?) ?? const [];

    final consumedFraction = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final over50 = total > 0 && used >= total * 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Budget Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C1935),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _editBudget,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
            ),
          ],
        ),
        const SizedBox(height: 6),

        if (over50) ...[
          _BudgetBanner(
            icon: Icons.warning_amber_rounded,
            title: '50% of the project budget has been consumed.',
            subtitle:
                'Used ₱${_fmt(used)} of ₱${_fmt(total)}. Consider reviewing '
                'remaining phase allocations.',
            color: const Color(0xFFFFF3CD),
            textColor: const Color(0xFF92400E),
          ),
          const SizedBox(height: 10),
        ],

        _TotalsGrid(
          total: total,
          allocated: allocated,
          used: used,
          remaining: remaining,
        ),
        const SizedBox(height: 10),

        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: consumedFraction,
            minHeight: 10,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(
              over50 ? const Color(0xFFF59E0B) : const Color(0xFF2E7D32),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(consumedFraction * 100).toStringAsFixed(1)}% of total consumed',
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),

        const SizedBox(height: 16),
        const Text(
          'Per-phase allocation',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        if (phases.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No phases yet. Add a phase to start allocating budget.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          )
        else
          ...phases
              .whereType<Map>()
              .map((p) => _PhaseRow(
                    phase: Map<String, dynamic>.from(p),
                    projectBudget: total,
                    otherPhasesAllocated:
                        allocated - _asDouble(p['allocated_budget']),
                    onEdit: (phase) => _editPhaseAllocation(
                      phase: phase,
                      projectBudget: total,
                      otherPhasesAllocated: allocated -
                          _asDouble(phase['allocated_budget']),
                    ),
                    onPlan: _openPlanModal,
                  )),
      ],
    );
  }

  // ── actions ───────────────────────────────────────────────────────────

  Future<void> _editBudget() async {
    final summary = _summary;
    if (summary == null) return;
    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => EditProjectBudgetModal(
        projectId: widget.projectId,
        projectName: widget.projectName,
        currentBudget: _asDouble(summary['total_budget']),
        totalAllocated: _asDouble(summary['total_allocated']),
      ),
    );
    if (updated != null) {
      await reload();
    }
  }

  Future<void> _openPlanModal(Map<String, dynamic> phase) async {
    final pmUserId = AuthService().currentUser?['user_id'];
    if (pmUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not signed in.')),
      );
      return;
    }
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => PhaseMaterialPlanModal(
        pmUserId: pmUserId,
        phaseId: phase['phase_id'] as int,
        phaseName: (phase['phase_name'] ?? '') as String,
      ),
    );
    if (changed == true) {
      await reload();
    }
  }

  Future<void> _editPhaseAllocation({
    required Map<String, dynamic> phase,
    required double projectBudget,
    required double otherPhasesAllocated,
  }) async {
    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AllocatePhaseBudgetModal(
        phaseId: phase['phase_id'] as int,
        phaseName: (phase['phase_name'] ?? '') as String,
        currentAllocation: _asDouble(phase['allocated_budget']),
        phaseUsedBudget: _asDouble(phase['used_budget']),
        projectBudget: projectBudget,
        otherPhasesAllocated: otherPhasesAllocated,
      ),
    );
    if (updated != null) {
      await reload();
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────

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

// ── internal widgets ─────────────────────────────────────────────────────

class _TotalsGrid extends StatelessWidget {
  final double total;
  final double allocated;
  final double used;
  final double remaining;

  const _TotalsGrid({
    required this.total,
    required this.allocated,
    required this.used,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _Tile(
          label: 'Total budget',
          value: total,
          color: const Color(0xFF1D4ED8),
        ),
        _Tile(
          label: 'Allocated',
          value: allocated,
          color: const Color(0xFF6B7280),
        ),
        _Tile(
          label: 'Used',
          value: used,
          color: const Color(0xFFB45309),
        ),
        _Tile(
          label: 'Remaining',
          value: remaining,
          color: const Color(0xFF2E7D32),
          emphasised: true,
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool emphasised;

  const _Tile({
    required this.label,
    required this.value,
    required this.color,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '₱${BudgetOverviewCardState._fmt(value)}',
            style: TextStyle(
              fontSize: emphasised ? 16 : 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color textColor;

  const _BudgetBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  final Map<String, dynamic> phase;
  final double projectBudget;
  final double otherPhasesAllocated;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onPlan;

  const _PhaseRow({
    required this.phase,
    required this.projectBudget,
    required this.otherPhasesAllocated,
    required this.onEdit,
    required this.onPlan,
  });

  @override
  Widget build(BuildContext context) {
    final name = (phase['phase_name'] ?? 'Phase') as String;
    final allocated = BudgetOverviewCardState._asDouble(
      phase['allocated_budget'],
    );
    final used = BudgetOverviewCardState._asDouble(phase['used_budget']);
    final remaining = BudgetOverviewCardState._asDouble(phase['remaining']);
    final fraction = allocated > 0 ? (used / allocated).clamp(0.0, 1.0) : 0.0;
    final overBudget = allocated > 0 && used > allocated;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0C1935),
                  ),
                ),
              ),
              Text(
                '₱${BudgetOverviewCardState._fmt(used)} / '
                '₱${BudgetOverviewCardState._fmt(allocated)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: overBudget
                      ? const Color(0xFFB91C1C)
                      : const Color(0xFF374151),
                ),
              ),
              IconButton(
                tooltip: 'Material plan',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.inventory_2_outlined, size: 16),
                onPressed: () => onPlan(phase),
              ),
              IconButton(
                tooltip: 'Edit allocation',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.tune, size: 16),
                onPressed: () => onEdit(phase),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(
                overBudget
                    ? const Color(0xFFB91C1C)
                    : fraction >= 0.8
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF2E7D32),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            overBudget
                ? 'Over budget by ₱${BudgetOverviewCardState._fmt(used - allocated)}'
                : 'Remaining: ₱${BudgetOverviewCardState._fmt(remaining)}',
            style: TextStyle(
              fontSize: 11,
              color: overBudget
                  ? const Color(0xFFB91C1C)
                  : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
