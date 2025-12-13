import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';

class ToolItem {
  final String id;
  final String name;
  final String category;
  final String status;
  final String? photoAsset; // optional asset path

  ToolItem({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    this.photoAsset,
  });
}

class ActiveUsage {
  final ToolItem tool;
  final List<String> users;
  final String usageStatus; // e.g. "In Use", "Checked Out"

  ActiveUsage({required this.tool, required this.users, required this.usageStatus});
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final Color primary = const Color(0xFF1396E9);
  final Color neutral = const Color(0xFFF6F8FA);

  // Example data
  final List<ToolItem> _items = [
    ToolItem(id: 't1', name: 'Concrete Mixer', category: 'Machinery', status: 'Available', photoAsset: null),
    ToolItem(id: 't2', name: 'Electric Drill', category: 'Hand Tool', status: 'Maintenance', photoAsset: null),
    ToolItem(id: 't3', name: 'Safety Harness', category: 'PPE', status: 'Available', photoAsset: null),
    ToolItem(id: 't4', name: 'Excavator ZX200', category: 'Machinery', status: 'Available', photoAsset: null),
    ToolItem(id: 't5', name: 'Laser Level', category: 'Measurement', status: 'Checked Out', photoAsset: null),
  ];

  late List<ActiveUsage> _active;

  String _query = '';

  @override
  void initState() {
    super.initState();
    _active = [
      ActiveUsage(tool: _items[4], users: ['Carlos Reyes'], usageStatus: 'In Use'),
      ActiveUsage(tool: _items[1], users: ['Jane Smith', 'John Doe'], usageStatus: 'Checked Out'),
    ];
  }

  List<ToolItem> get _filtered => _items.where((t) {
        final q = _query.trim().toLowerCase();
        if (q.isEmpty) return true;
        return t.name.toLowerCase().contains(q) || t.category.toLowerCase().contains(q) || t.status.toLowerCase().contains(q);
      }).toList();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 1100;

    return Scaffold(
      backgroundColor: neutral,
      body: Row(
        children: [
          const Sidebar(activePage: 'Inventory'),
          Expanded(
            child: Column(
              children: [
                // White header with slim blue line at left corner
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  child: Row(
                    children: [
                      Container(width: 4, height: 48, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(6))),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                        Text('Inventory', style: TextStyle(color: Color(0xFF0C1935), fontSize: 20, fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text('Tools & machines used on site', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ]),
                      const Spacer(),
                      // Search field (compact)
                      SizedBox(
                        width: isWide ? 360 : 200,
                        child: TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: 'Search tools, category, status',
                            isDense: true,
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: () {
                          // Open the Materials page
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MaterialsPage()));
                        },
                        icon: const Icon(Icons.layers),
                        label: const Text('Materials'),
                        style: TextButton.styleFrom(foregroundColor: primary),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add Item (demo)')));
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Item'),
                        style: ElevatedButton.styleFrom(backgroundColor: primary),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Grid of all items
                          Text('All Tools & Machines', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.grey[800])),
                          const SizedBox(height: 12),
                          LayoutBuilder(builder: (context, c) {
                            final maxWidth = c.maxWidth;
                            final crossAxis = maxWidth ~/ 260; // each card ~260px
                            final crossAxisCount = crossAxis.clamp(1, 4);
                            return GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisExtent: 220,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: _filtered.length,
                              itemBuilder: (context, i) {
                                final t = _filtered[i];
                                return _toolCard(t);
                              },
                            );
                          }),
                          const SizedBox(height: 22),

                          // Active / In-use section
                          Row(
                            children: [
                              const Expanded(child: Text('Currently In Use', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                              Text('${_active.length} active', style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _active.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                                  child: const Text('No active tools currently'),
                                )
                              : Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: _active.map((a) => _activeCard(a, context)).toList(),
                                ),
                          const SizedBox(height: 28),
                        ],
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

  Widget _toolCard(ToolItem t) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showToolDetails(t),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // image area
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                color: Colors.grey[100],
              ),
              child: t.photoAsset != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.asset(t.photoAsset!, fit: BoxFit.cover),
                    )
                  : Center(
                      child: Icon(Icons.construction, size: 48, color: Colors.grey[400]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      child: Text(t.category, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    _statusChip(t.status),
                    const Spacer(),
                    IconButton(onPressed: () => _showToolDetails(t), icon: const Icon(Icons.more_horiz)),
                  ],
                ),
              ]),
            )
          ],
        ),
      ),
      );
  }

  Widget _statusChip(String status) {
    final color = status.toLowerCase() == 'available' ? Colors.green : (status.toLowerCase() == 'maintenance' ? Colors.orange : Colors.redAccent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _activeCard(ActiveUsage a, BuildContext ctx) {
    return SizedBox(
      width: 320,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // small photo
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: a.tool.photoAsset != null ? Image.asset(a.tool.photoAsset!, fit: BoxFit.cover) : const Icon(Icons.build, size: 36, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.tool.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Used by: ${a.users.join(', ')}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Row(children: [
                  _statusChip(a.usageStatus),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Manage usage (demo)')));
                    },
                    child: const Text('Manage', style: TextStyle(fontSize: 12)),
                  )
                ]),
              ]),
            )
          ]),
        ),
      ),
    );
  }

  void _showToolDetails(ToolItem t) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (t.photoAsset != null)
              Image.asset(t.photoAsset!, height: 120, fit: BoxFit.cover)
            else
              const SizedBox(height: 120, child: Center(child: Icon(Icons.construction, size: 48, color: Colors.grey))),
            const SizedBox(height: 12),
            Row(children: [Text('Category: ', style: TextStyle(fontWeight: FontWeight.w700)), Text(t.category)]),
            const SizedBox(height: 6),
            Row(children: [Text('Status: ', style: TextStyle(fontWeight: FontWeight.w700)), _statusChip(t.status)]),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }
}

// New: simple Materials data model and page (example UI)
class MaterialItem {
  final String id;
  final String name;
  final String unit;
  double quantity; // changed from final to mutable
  final String status;

  MaterialItem({required this.id, required this.name, required this.unit, required this.quantity, required this.status});
}

class MaterialsPage extends StatefulWidget {
  const MaterialsPage({super.key});

  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  final Color primary = const Color(0xFF1396E9);
  final Color neutral = const Color(0xFFF6F8FA);

  final List<MaterialItem> _materials = [
    MaterialItem(id: 'm1', name: 'Cement 50kg', unit: 'bags', quantity: 120, status: 'In Stock'),
    MaterialItem(id: 'm2', name: 'Rebar 12mm', unit: 'pcs', quantity: 450, status: 'Low'),
    MaterialItem(id: 'm3', name: 'Sand (m3)', unit: 'm3', quantity: 32.5, status: 'In Stock'),
    MaterialItem(id: 'm4', name: 'Gravel (m3)', unit: 'm3', quantity: 18.0, status: 'Reserved'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: neutral,
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF0C1935)),
        title: const Text('Materials', style: TextStyle(color: Color(0xFF0C1935), fontWeight: FontWeight.w800)),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add Material (demo)'))),
            icon: const Icon(Icons.add, color: Color(0xFF1396E9)),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 140, // slightly larger to fit 'Use' button
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _materials.length,
          itemBuilder: (context, i) {
            final m = _materials[i];
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: InkWell(
                onTap: () => _showMaterialDetails(m),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                        child: Text('${_formatQty(m.quantity)} ${m.unit}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                      const SizedBox(width: 8),
                      _materialStatusChip(m.status),
                      const Spacer(),
                      // show details / use
                      IconButton(onPressed: () => _showMaterialDetails(m), icon: const Icon(Icons.more_horiz)),
                    ]),
                    const Spacer(),
                    // small Use button directly on card for quick deduct
                    Align(
                      alignment: Alignment.bottomRight,
                      child: TextButton.icon(
                        onPressed: () => _showUseDialog(m),
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        label: const Text('Use', style: TextStyle(fontSize: 12)),
                      ),
                    )
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatQty(double q) {
    return q == q.roundToDouble() ? q.toInt().toString() : q.toString();
  }

  Widget _materialStatusChip(String status) {
    final color = status.toLowerCase() == 'in stock' ? Colors.green : (status.toLowerCase() == 'low' ? Colors.orange : Colors.redAccent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  // New: dialog to enter used quantity and deduct it
  void _showUseDialog(MaterialItem m) {
    final controller = TextEditingController();
    String? error;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setStateDialog) {
        return AlertDialog(
          title: Text('Use ${m.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Available: ${_formatQty(m.quantity)} ${m.unit}'),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Quantity to use',
                  hintText: 'e.g. 5',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
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
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Used ${_formatQty(used)} ${m.unit} from ${m.name}')));
              },
              child: const Text('Use'),
            ),
          ],
        );
      }),
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
            Row(children: [const Text('Quantity: ', style: TextStyle(fontWeight: FontWeight.w700)), Text('${_formatQty(m.quantity)} ${m.unit}')]),
            const SizedBox(height: 8),
            Row(children: [const Text('Status: ', style: TextStyle(fontWeight: FontWeight.w700)), _materialStatusChip(m.status)]),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          TextButton(onPressed: () { Navigator.of(ctx).pop(); _showUseDialog(m); }, child: const Text('Use')),
        ],
      ),
    );
  }
}