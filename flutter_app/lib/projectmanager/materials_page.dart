import 'package:flutter/material.dart';

class MaterialItem {
  final String id;
  final String name;
  final String unit;
  double quantity;
  final String status;

  MaterialItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.status,
  });
}

class MaterialsPage extends StatefulWidget {
  const MaterialsPage({super.key});

  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  final Color primary = const Color(0xFFFF7A18);
  final Color neutral = const Color(0xFFF4F6F9);

  String _searchQuery = '';

  final List<MaterialItem> _materials = [
    MaterialItem(
      id: 'm1',
      name: 'Cement 50kg',
      unit: 'bags',
      quantity: 120,
      status: 'In Stock',
    ),
    MaterialItem(
      id: 'm2',
      name: 'Rebar 12mm',
      unit: 'pcs',
      quantity: 450,
      status: 'Low',
    ),
    MaterialItem(
      id: 'm3',
      name: 'Sand (m3)',
      unit: 'm3',
      quantity: 32.5,
      status: 'In Stock',
    ),
    MaterialItem(
      id: 'm4',
      name: 'Gravel (m3)',
      unit: 'm3',
      quantity: 18.0,
      status: 'Reserved',
    ),
  ];

  List<MaterialItem> get _filteredMaterials => _materials.where((m) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    return m.name.toLowerCase().contains(query) ||
        m.unit.toLowerCase().contains(query) ||
        m.status.toLowerCase().contains(query);
  }).toList();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return Scaffold(
      backgroundColor: neutral,
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF0C1935)),
        title: const Text(
          'Materials',
          style: TextStyle(
            color: Color(0xFF0C1935),
            fontWeight: FontWeight.w800,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add Material (demo)')),
            ),
            icon: Icon(Icons.add, color: primary),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search bar
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search materials...',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Text(
                  'Construction Materials',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_filteredMaterials.length} items',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Materials table
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Table header
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 16,
                        vertical: isMobile ? 10 : 14,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.05),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Material Name',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: isMobile ? 12 : 13,
                              ),
                            ),
                          ),
                          if (!isMobile)
                            const Expanded(
                              flex: 2,
                              child: Text(
                                'Quantity',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          Expanded(
                            flex: isMobile ? 2 : 2,
                            child: Text(
                              'Status',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: isMobile ? 12 : 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: isMobile ? 60 : 100,
                          ), // for action button
                        ],
                      ),
                    ),

                    // Table body
                    Expanded(
                      child: _filteredMaterials.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Text(
                                  _searchQuery.isEmpty
                                      ? 'No materials found'
                                      : 'No materials match your search',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredMaterials.length,
                              itemBuilder: (context, i) {
                                final m = _filteredMaterials[i];
                                final isEven = i.isEven;

                                return InkWell(
                                  onTap: () => _showMaterialDetails(m),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 12 : 16,
                                      vertical: isMobile ? 10 : 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isEven
                                          ? Colors.grey.shade50
                                          : Colors.white,
                                      border: Border(
                                        bottom:
                                            i == _filteredMaterials.length - 1
                                            ? BorderSide.none
                                            : BorderSide(
                                                color: Colors.grey.shade200,
                                                width: 1,
                                              ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Material name with icon
                                        Expanded(
                                          flex: 3,
                                          child: Row(
                                            children: [
                                              if (!isMobile) ...[
                                                Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: primary.withOpacity(
                                                      0.1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.layers,
                                                    color: primary,
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                              ],
                                              Expanded(
                                                child: Text(
                                                  m.name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: isMobile
                                                        ? 13
                                                        : 14,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Quantity
                                        if (!isMobile)
                                          Expanded(
                                            flex: 2,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[100],
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${_formatQty(m.quantity)} ${m.unit}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),

                                        const SizedBox(width: 12),

                                        // Status
                                        Expanded(
                                          flex: 2,
                                          child: Center(
                                            child: _materialStatusChip(
                                              m.status,
                                            ),
                                          ),
                                        ),

                                        const SizedBox(width: 12),

                                        // Use button
                                        SizedBox(
                                          width: isMobile ? 60 : 100,
                                          child: TextButton.icon(
                                            onPressed: () => _showUseDialog(m),
                                            icon: Icon(
                                              Icons.remove_circle_outline,
                                              size: isMobile ? 14 : 16,
                                            ),
                                            label: Text(
                                              'Use',
                                              style: TextStyle(
                                                fontSize: isMobile ? 11 : 12,
                                              ),
                                            ),
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isMobile ? 4 : 8,
                                                vertical: 6,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
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

  String _formatQty(double q) {
    return q == q.roundToDouble() ? q.toInt().toString() : q.toString();
  }

  Widget _materialStatusChip(String status) {
    final color = status.toLowerCase() == 'in stock'
        ? Colors.green
        : (status.toLowerCase() == 'low' ? Colors.orange : Colors.redAccent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  // New: dialog to enter used quantity and deduct it
  void _showUseDialog(MaterialItem m) {
    final controller = TextEditingController();
    String? error;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setStateDialog) {
          return AlertDialog(
            title: Text('Use ${m.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Available: ${_formatQty(m.quantity)} ${m.unit}'),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Quantity to use',
                    hintText: 'e.g. 5',
                    errorText: error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final input = controller.text.trim();
                  final used = double.tryParse(input);
                  if (used == null || used <= 0) {
                    setStateDialog(() => error = 'Enter a positive number');
                    return;
                  }
                  if (used > m.quantity) {
                    setStateDialog(() => error = 'Not enough in stock');
                    return;
                  }
                  // update outer state so UI refreshes
                  setState(() {
                    m.quantity = (m.quantity - used);
                  });
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Used ${_formatQty(used)} ${m.unit} from ${m.name}',
                      ),
                    ),
                  );
                },
                child: const Text('Use'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMaterialDetails(MaterialItem m) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(m.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Quantity: ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text('${_formatQty(m.quantity)} ${m.unit}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Status: ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                _materialStatusChip(m.status),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showUseDialog(m);
            },
            child: const Text('Use'),
          ),
        ],
      ),
    );
  }
}
