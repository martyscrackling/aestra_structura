import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/budget_service.dart';
import '../../services/inventory_service.dart';

/// Supervisor modal to record material usage against a phase.
///
/// - Dropdown of materials visible to this supervisor, with live stock
///   (in whatever unit — pcs, bags, etc.) and the unit of measure.
/// - Enforces quantity > 0 and stock checks client-side; server provides
///   authoritative validation.
/// - Budget / peso info is intentionally hidden — supervisors never see
///   money, only quantities.
/// - Displays server warnings after a successful save.
/// - Returns `true` on close if any usage was recorded, so the caller
///   can refresh upstream widgets.
class RecordUsageModal extends StatefulWidget {
  final int phaseId;
  final String phaseName;
  final int supervisorId;
  final int projectId;

  const RecordUsageModal({
    super.key,
    required this.phaseId,
    required this.phaseName,
    required this.supervisorId,
    required this.projectId,
  });

  @override
  State<RecordUsageModal> createState() => _RecordUsageModalState();
}

class _RecordUsageModalState extends State<RecordUsageModal> {
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  List<Map<String, dynamic>> _inventory = const [];
  bool _loadingInventory = true;
  String? _loadError;

  int? _selectedItemId;
  bool _submitting = false;
  String? _submitError;
  List<String> _lastWarnings = const [];
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    setState(() {
      _loadingInventory = true;
      _loadError = null;
    });
    try {
      final items = await InventoryService.getInventoryItemsForSupervisor(
        supervisorId: widget.supervisorId,
        projectId: widget.projectId,
        phaseId: widget.phaseId,
      );
      // Only bulk materials can be consumed through the material-usage flow.
      // Tools and machines are checked out via the separate unit flow.
      final materials = items.where((i) {
        final type = i['item_type'];
        if (type is String && type.trim().toLowerCase() == 'material') {
          return true;
        }
        final raw = i['category'];
        if (raw is! String) return false;
        final cat = raw.trim().toLowerCase();
        return cat == 'material' || cat == 'materials';
      }).toList();
      if (!mounted) return;
      setState(() {
        _inventory = materials;
        _loadingInventory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loadingInventory = false;
      });
    }
  }

  Map<String, dynamic>? get _selectedItem {
    if (_selectedItemId == null) return null;
    for (final item in _inventory) {
      if (item['item_id'] == _selectedItemId) return item;
    }
    return null;
  }

  Future<void> _submit() async {
    final itemId = _selectedItemId;
    final qty = int.tryParse(_qtyCtrl.text.trim());
    if (itemId == null) {
      setState(() => _submitError = 'Pick a material.');
      return;
    }
    if (qty == null || qty <= 0) {
      setState(() => _submitError = 'Enter a positive quantity.');
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
      _lastWarnings = const [];
    });
    try {
      final result = await BudgetService.recordMaterialUsage(
        phaseId: widget.phaseId,
        inventoryItemId: itemId,
        quantity: qty,
        supervisorId: widget.supervisorId,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (!mounted) return;

      final warnings = ((result['warnings'] as List?) ?? const [])
          .map((w) => w.toString())
          .toList();

      setState(() {
        _lastWarnings = warnings;
        _qtyCtrl.clear();
        _notesCtrl.clear();
        _selectedItemId = null;
        _recorded = true;
      });

      await _loadInventory(); // refresh stock after deduction

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usage recorded.')),
      );
    } on BudgetApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitError = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

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
              child: SingleChildScrollView(
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
                    onPressed: () => Navigator.of(context).pop(_recorded),
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
                  'Record Material Usage',
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
            onPressed: () => Navigator.of(context).pop(_recorded),
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
        if (_lastWarnings.isNotEmpty) ...[
          _WarningsBanner(warnings: _lastWarnings),
          const SizedBox(height: 12),
        ],
        const Text(
          'New usage entry',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        if (_loadingInventory)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_loadError != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _loadError!,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
              ),
              TextButton.icon(
                onPressed: _loadInventory,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          )
        else
          _buildForm(),
      ],
    );
  }

  Widget _buildForm() {
    final item = _selectedItem;
    final stock = item == null ? null : (item['quantity'] ?? 0) as num;
    final unit = item == null
        ? ''
        : ((item['unit_of_measure'] ?? 'pcs').toString().trim().isEmpty
            ? 'pcs'
            : (item['unit_of_measure']).toString().trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _selectedItemId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Material',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: _inventory.map((i) {
            final itemUnit =
                ((i['unit_of_measure'] ?? 'pcs').toString().trim().isEmpty
                        ? 'pcs'
                        : (i['unit_of_measure']).toString().trim());
            final label =
                '${i['name']}  •  ${i['quantity'] ?? 0} $itemUnit available';
            return DropdownMenuItem<int>(
              value: i['item_id'] as int,
              child: Text(label, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedItemId = v),
          hint: _inventory.isEmpty
              ? const Text('No inventory visible to you yet.')
              : const Text('Pick a material'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _qtyCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: unit.isEmpty ? 'Quantity used' : 'Quantity used ($unit)',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (item != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Available: $stock $unit',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildForecastHint(stock: stock, unit: unit),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _notesCtrl,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (_submitError != null) ...[
          const SizedBox(height: 8),
          Text(
            _submitError!,
            style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Record usage'),
          ),
        ),
      ],
    );
  }

  /// Renders an inline hint under the stock row warning the supervisor
  /// *before* submit if the pending usage would exhaust stock. Purely
  /// client-side; the server is still authoritative on enforcement.
  /// Budget-based forecasts are deliberately omitted — supervisors must
  /// not see monetary amounts.
  Widget _buildForecastHint({required num? stock, required String unit}) {
    final messages = <_ForecastHint>[];

    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty > 0 && stock != null && qty > stock) {
      messages.add(
        _ForecastHint(
          severity: _ForecastSeverity.error,
          text:
              'Not enough stock: requested $qty $unit, only $stock $unit '
              'assigned to your phases. The server will reject this submit.',
        ),
      );
    }

    if (messages.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: messages.map((m) {
          final isError = m.severity == _ForecastSeverity.error;
          final bg = isError
              ? const Color(0xFFFEE2E2)
              : const Color(0xFFFEF3C7);
          final fg = isError
              ? const Color(0xFF991B1B)
              : const Color(0xFF92400E);
          return Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.warning_amber_rounded,
                  size: 14,
                  color: fg,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    m.text,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

enum _ForecastSeverity { error }

class _ForecastHint {
  final _ForecastSeverity severity;
  final String text;

  const _ForecastHint({required this.severity, required this.text});
}

class _WarningsBanner extends StatelessWidget {
  final List<String> warnings;

  const _WarningsBanner({required this.warnings});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: Color(0xFF92400E),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Warnings',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                ...warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      '• $w',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                      ),
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
