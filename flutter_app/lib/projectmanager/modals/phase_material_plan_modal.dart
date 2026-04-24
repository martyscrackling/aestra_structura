import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/app_config.dart';
import '../../services/budget_service.dart';
import '../../services/inventory_service.dart';
import 'add_inventory_item_modal.dart';
import '../widgets/planned_vs_actual_panel.dart';

/// PM modal to manage material plans for one phase:
///  - list existing plans (edit qty / delete)
///  - add a new plan (pick item + planned quantity)
///  - shows live planned-vs-actual report underneath
class PhaseMaterialPlanModal extends StatefulWidget {
  /// Project-manager user id (owner of inventory items). Needed to list
  /// the inventory dropdown.
  final dynamic pmUserId;
  final int phaseId;
  final String phaseName;

  const PhaseMaterialPlanModal({
    super.key,
    required this.pmUserId,
    required this.phaseId,
    required this.phaseName,
  });

  @override
  State<PhaseMaterialPlanModal> createState() => _PhaseMaterialPlanModalState();
}

class _PhaseMaterialPlanModalState extends State<PhaseMaterialPlanModal> {
  final GlobalKey<PlannedVsActualPanelState> _reportKey =
      GlobalKey<PlannedVsActualPanelState>();

  List<Map<String, dynamic>> _plans = const [];
  List<Map<String, dynamic>> _inventory = const [];
  List<Map<String, dynamic>> _subtasks = const [];
  bool _loading = true;
  String? _error;

  // Add-form state
  int? _selectedItemId;
  int? _selectedSubtaskId;
  final TextEditingController _qtyCtrl = TextEditingController();
  bool _submittingAdd = false;
  String? _addError;

  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        BudgetService.listPhasePlans(phaseId: widget.phaseId),
        InventoryService.getInventoryItems(userId: widget.pmUserId),
        _loadSubtasksForPhase(),
      ]);
      if (!mounted) return;
      setState(() {
        _plans = results[0];
        _inventory = results[1];
        _subtasks = results[2];
        _loading = false;
        _dropInvalidMaterialSelection();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Set<int> get _plannedItemIds =>
      _plans.map((p) => p['inventory_item'] as int).toSet();

  bool _isMaterial(Map<String, dynamic> item) {
    final type = item['item_type'];
    if (type is String && type.trim().toLowerCase() == 'material') {
      return true;
    }
    // Legacy rows may only carry a free-text `category` like "Materials".
    final cat = item['category'];
    if (cat is! String) return false;
    final normalized = cat.trim().toLowerCase();
    return normalized == 'material' || normalized == 'materials';
  }

  int _stockQuantity(Map<String, dynamic> item) {
    final q = item['quantity'];
    if (q is int) return q;
    if (q is num) return q.toInt();
    return int.tryParse(q?.toString() ?? '0') ?? 0;
  }

  List<Map<String, dynamic>> get _unplannedInventory => _inventory
      .where(
        (i) =>
            _isMaterial(i) &&
            !_plannedItemIds.contains(i['item_id']) &&
            _stockQuantity(i) > 0,
      )
      .toList();

  void _dropInvalidMaterialSelection() {
    final valid = <int>{};
    for (final i in _unplannedInventory) {
      final id = i['item_id'];
      if (id is int) {
        valid.add(id);
      } else if (id is num) {
        valid.add(id.toInt());
      }
    }
    if (_selectedItemId != null && !valid.contains(_selectedItemId)) {
      _selectedItemId = null;
    }
  }

  Future<void> _addPlan() async {
    final itemId = _selectedItemId;
    final subtaskId = _selectedSubtaskId;
    final qty = int.tryParse(_qtyCtrl.text.trim());
    if (itemId == null) {
      setState(() => _addError = 'Pick a material.');
      return;
    }
    if (subtaskId == null) {
      setState(() => _addError = 'Pick a subtask destination.');
      return;
    }
    if (qty == null || qty <= 0) {
      setState(() => _addError = 'Enter a positive quantity.');
      return;
    }

    setState(() {
      _submittingAdd = true;
      _addError = null;
    });
    try {
      await BudgetService.createPhasePlan(
        phaseId: widget.phaseId,
        inventoryItemId: itemId,
        plannedQuantity: qty,
        subtaskId: subtaskId,
      );
      _selectedItemId = null;
      _selectedSubtaskId = null;
      _qtyCtrl.clear();
      _changed = true;
      await _refreshLists();
    } on BudgetApiException catch (e) {
      if (!mounted) return;
      setState(() => _addError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _addError = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _submittingAdd = false);
    }
  }

  Future<void> _updatePlan(int planId, int newQty) async {
    try {
      await BudgetService.updatePhasePlan(
        planId: planId,
        plannedQuantity: newQty,
      );
      _changed = true;
      await _refreshLists();
    } on BudgetApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Unexpected error: $e', isError: true);
    }
  }

  Future<void> _deletePlan(int planId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete plan?'),
        content: const Text(
          'Removing this plan does not delete any recorded usage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await BudgetService.deletePhasePlan(planId: planId);
      _changed = true;
      await _refreshLists();
    } on BudgetApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Unexpected error: $e', isError: true);
    }
  }

  Future<void> _refreshLists() async {
    try {
      final plans = await BudgetService.listPhasePlans(phaseId: widget.phaseId);
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _dropInvalidMaterialSelection();
      });
      _reportKey.currentState?.reload();
    } catch (_) {
      // ignore — next full load will fix it
    }
  }

  Future<List<Map<String, dynamic>>> _loadSubtasksForPhase() async {
    try {
      final response = await http.get(
        AppConfig.apiUri('phases/${widget.phaseId}/'),
      );
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final rawSubtasks = decoded['subtasks'];
      if (rawSubtasks is! List) return const [];
      return rawSubtasks
          .whereType<Map>()
          .map((s) => Map<String, dynamic>.from(s))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _openAddMaterialModal() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => const AddInventoryItemModal(initialCategory: 'Material'),
    );
    if (added == true && mounted) {
      final inventory = await InventoryService.getInventoryItems(
        userId: widget.pmUserId,
      );
      if (!mounted) return;
      setState(() {
        _inventory = inventory;
        _dropInvalidMaterialSelection();
      });
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFB91C1C) : null,
      ),
    );
  }

  // ── render ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 560 ? screenWidth - 32 : 560.0;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFFB91C1C)),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: _loadAll,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildBody(),
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_changed),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Material Plan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                ),
                Text(
                  widget.phaseName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(_changed),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Planned materials',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        if (_plans.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              'No planned materials yet. Add one below.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          )
        else
          Column(
            children: _plans
                .map(
                  (p) => _PlanRow(
                    plan: p,
                    onSave: (qty) => _updatePlan(p['plan_id'] as int, qty),
                    onDelete: () => _deletePlan(p['plan_id'] as int),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 14),
        _buildAddForm(),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 10),
        PlannedVsActualPanel(key: _reportKey, phaseId: widget.phaseId),
      ],
    );
  }

  Widget _buildAddForm() {
    final available = _unplannedInventory;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add a material to plan',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _selectedSubtaskId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Subtask destination',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _subtasks.map((s) {
              final id = s['subtask_id'] as int?;
              final title = (s['title'] ?? '').toString().trim();
              if (id == null || title.isEmpty) {
                return null;
              }
              return DropdownMenuItem<int>(
                value: id,
                child: Text(title, overflow: TextOverflow.ellipsis),
              );
            }).whereType<DropdownMenuItem<int>>().toList(),
            onChanged: _subtasks.isEmpty
                ? null
                : (v) => setState(() => _selectedSubtaskId = v),
            hint: Text(
              _subtasks.isEmpty
                  ? 'No subtasks available for this phase.'
                  : 'Pick target subtask',
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _selectedItemId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Material',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: available.map((i) {
              final label =
                  '${i['name']}  •  ₱${i['price'] ?? 0}  •  stock ${i['quantity'] ?? 0}';
              return DropdownMenuItem<int>(
                value: i['item_id'] as int,
                child: Text(label, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: available.isEmpty
                ? null
                : (v) => setState(() => _selectedItemId = v),
            hint: Text(
              available.isEmpty
                  ? 'No material with available stock, or all are already in this plan.'
                  : 'Pick a material',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Planned quantity',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (_addError != null) ...[
            const SizedBox(height: 6),
            Text(
              _addError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _openAddMaterialModal,
                icon: const Icon(Icons.playlist_add, size: 16),
                label: const Text('New Material'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _submittingAdd ? null : _addPlan,
                icon: _submittingAdd
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Text('Add to plan'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Future<void> Function(int newQty) onSave;
  final VoidCallback onDelete;

  const _PlanRow({
    required this.plan,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_PlanRow> createState() => _PlanRowState();
}

class _PlanRowState extends State<_PlanRow> {
  late final TextEditingController _ctrl;
  bool _saving = false;
  late int _lastSavedQty;

  @override
  void initState() {
    super.initState();
    _lastSavedQty = (widget.plan['planned_quantity'] as num).toInt();
    _ctrl = TextEditingController(text: _lastSavedQty.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final val = int.tryParse(_ctrl.text.trim());
    if (val == null || val <= 0) return;
    if (val == _lastSavedQty) return;
    setState(() => _saving = true);
    await widget.onSave(val);
    if (mounted) {
      setState(() {
        _saving = false;
        _lastSavedQty = val;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.plan['inventory_item_name'] as String? ?? '-';
    final subtask = (widget.plan['subtask_title'] ?? '').toString().trim();
    final price = widget.plan['inventory_item_unit_price']?.toString() ?? '0';
    final plannedCost = widget.plan['planned_cost']?.toString() ?? '0';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtask.isNotEmpty)
                  Text(
                    'Subtask: $subtask',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF4B5563),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  '₱$price/unit  •  planned cost ₱$plannedCost',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
          ),
          IconButton(
            tooltip: 'Save',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check, size: 18),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: widget.onDelete,
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: Color(0xFFB91C1C),
            ),
          ),
        ],
      ),
    );
  }
}
