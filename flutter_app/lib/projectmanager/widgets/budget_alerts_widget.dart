import 'package:flutter/material.dart';
import '../../services/budget_service.dart';
import '../../services/inventory_service.dart';
import '../project_details_page.dart';

/// Dashboard card that surfaces budget-health alerts across all of a
/// PM's projects:
///   - 50 %+ of total project budget consumed
///   - any phase that has exceeded its allocated budget
///
/// It calls `InventoryService.getProjectsForPM` once, then fan-outs
/// `BudgetService.getBudgetSummary` calls in parallel. Tapping an alert
/// row opens `ProjectTaskDetailsPage` for that project, where the PM
/// can act directly via the Budget Overview card.
///
/// When no alerts are active, the widget renders a compact "All budgets
/// healthy" state. When there is no budget data yet (no projects or no
/// budgets set), the widget renders nothing so it doesn't clutter the
/// dashboard.
class BudgetAlertsWidget extends StatefulWidget {
  final int userId;

  const BudgetAlertsWidget({super.key, required this.userId});

  @override
  State<BudgetAlertsWidget> createState() => _BudgetAlertsWidgetState();
}

class _BudgetAlertsWidgetState extends State<BudgetAlertsWidget> {
  bool _loading = true;
  String? _error;

  /// Project summary payloads enriched with a `_name` field resolved
  /// from the projects list (so we don't need another request for it).
  List<Map<String, dynamic>> _summaries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BudgetAlertsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final projects = await InventoryService.getProjectsForPM(
        userId: widget.userId,
      );

      final summaries = await Future.wait(
        projects.map((p) async {
          final projectId = _asInt(p['project_id']) ?? _asInt(p['id']);
          if (projectId == null) return null;
          try {
            final summary = await BudgetService.getBudgetSummary(
              projectId: projectId,
            );
            summary['_project_id'] = projectId;
            summary['_name'] = _asString(p['project_name']) ??
                _asString(p['name']) ??
                'Project $projectId';
            summary['_location'] = _asString(p['location']) ?? '';
            summary['_image'] = _asString(p['project_image']) ?? '';
            return summary;
          } catch (_) {
            // Individual failures shouldn't blow up the whole card.
            return null;
          }
        }),
      );

      if (!mounted) return;
      setState(() {
        _summaries =
            summaries.whereType<Map<String, dynamic>>().toList(growable: false);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── alert extraction ─────────────────────────────────────────────────

  List<_BudgetAlert> get _alerts {
    final result = <_BudgetAlert>[];
    for (final s in _summaries) {
      final total = _asDouble(s['total_budget']);
      final used = _asDouble(s['total_used']);
      final projectId = s['_project_id'] as int;
      final projectName = s['_name'] as String;

      if (total > 0 && used >= total * 0.5) {
        final pct = (used / total * 100).toStringAsFixed(1);
        result.add(_BudgetAlert(
          projectId: projectId,
          projectName: projectName,
          projectLocation: s['_location'] as String,
          projectImage: s['_image'] as String,
          severity: used >= total
              ? _AlertSeverity.critical
              : _AlertSeverity.warning,
          title: used >= total
              ? '$projectName has consumed its entire project budget'
              : '$projectName has consumed $pct% of its budget',
          subtitle:
              '₱${_fmt(used)} used of ₱${_fmt(total)} '
              '(remaining ₱${_fmt(total - used)})',
        ));
      }

      final phases = (s['phases'] as List?) ?? const [];
      for (final ph in phases.whereType<Map>()) {
        final allocated = _asDouble(ph['allocated_budget']);
        final phUsed = _asDouble(ph['used_budget']);
        if (allocated > 0 && phUsed > allocated) {
          result.add(_BudgetAlert(
            projectId: projectId,
            projectName: projectName,
            projectLocation: s['_location'] as String,
            projectImage: s['_image'] as String,
            severity: _AlertSeverity.critical,
            title:
                '${ph['phase_name']} in $projectName is over budget',
            subtitle:
                'Used ₱${_fmt(phUsed)} of ₱${_fmt(allocated)} '
                '(over by ₱${_fmt(phUsed - allocated)})',
          ));
        }
      }
    }

    // Sort: critical first, then warnings.
    result.sort((a, b) {
      if (a.severity == b.severity) return 0;
      return a.severity == _AlertSeverity.critical ? -1 : 1;
    });
    return result;
  }

  bool get _anyBudgetConfigured =>
      _summaries.any((s) => _asDouble(s['total_budget']) > 0);

  // ── render ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }

  Widget _shell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }

  // ── navigation ───────────────────────────────────────────────────────

  void _openProject(_BudgetAlert alert) async {
    final refreshed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProjectTaskDetailsPage(
          projectTitle: alert.projectName,
          projectLocation: alert.projectLocation.isEmpty
              ? '-'
              : alert.projectLocation,
          projectImage: alert.projectImage.isEmpty
              ? 'assets/images/engineer.jpg'
              : alert.projectImage,
          progress: 0.0, // recalculated inside the page
          projectId: alert.projectId,
        ),
      ),
    );
    if (refreshed != false) {
      // Regardless of the popped value, reload the alerts in case the
      // PM adjusted a budget while drilled in.
      _load();
    }
  }

  // ── utils ────────────────────────────────────────────────────────────

  static double _asDouble(Object? v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static String? _asString(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
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

enum _AlertSeverity { warning, critical }

class _BudgetAlert {
  final int projectId;
  final String projectName;
  final String projectLocation;
  final String projectImage;
  final _AlertSeverity severity;
  final String title;
  final String subtitle;

  const _BudgetAlert({
    required this.projectId,
    required this.projectName,
    required this.projectLocation,
    required this.projectImage,
    required this.severity,
    required this.title,
    required this.subtitle,
  });
}

class _AlertTile extends StatelessWidget {
  final _BudgetAlert alert;
  final VoidCallback onTap;

  const _AlertTile({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCritical = alert.severity == _AlertSeverity.critical;
    final bg = isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFFFF8E1);
    final border = isCritical
        ? const Color(0xFFFCA5A5)
        : const Color(0xFFFBBF24);
    final textColor = isCritical
        ? const Color(0xFF991B1B)
        : const Color(0xFF92400E);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isCritical
                    ? Icons.error_outline
                    : Icons.warning_amber_rounded,
                color: textColor,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alert.subtitle,
                      style: TextStyle(fontSize: 11, color: textColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: textColor.withValues(alpha: 0.8),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
