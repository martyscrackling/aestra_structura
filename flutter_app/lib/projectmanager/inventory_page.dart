import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/responsive_page_layout.dart';
import 'modals/tool_details_modal.dart';
import 'modals/add_inventory_item_modal.dart';
import 'modals/manage_usage_modal.dart';

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

  ActiveUsage({
    required this.tool,
    required this.users,
    required this.usageStatus,
  });
}

class InventoryPage extends StatefulWidget {
  InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final Color primary = const Color(0xFFFF7A18);
  final Color neutral = const Color(0xFFF4F6F9);

  // Example data
  final List<ToolItem> _items = [
    ToolItem(
      id: 't1',
      name: 'Concrete Mixer',
      category: 'Machinery',
      status: 'Available',
      photoAsset: null,
    ),
    ToolItem(
      id: 't2',
      name: 'Electric Drill',
      category: 'Hand Tool',
      status: 'Maintenance',
      photoAsset: null,
    ),
    ToolItem(
      id: 't3',
      name: 'Safety Harness',
      category: 'PPE',
      status: 'Available',
      photoAsset: null,
    ),
    ToolItem(
      id: 't4',
      name: 'Excavator ZX200',
      category: 'Machinery',
      status: 'Available',
      photoAsset: null,
    ),
    ToolItem(
      id: 't5',
      name: 'Laser Level',
      category: 'Measurement',
      status: 'Checked Out',
      photoAsset: null,
    ),
  ];

  late List<ActiveUsage> _active;

  String _query = '';

  @override
  void initState() {
    super.initState();
    _active = [
      ActiveUsage(
        tool: _items[4],
        users: ['Carlos Reyes'],
        usageStatus: 'In Use',
      ),
      ActiveUsage(
        tool: _items[1],
        users: ['Jane Smith', 'John Doe'],
        usageStatus: 'Checked Out',
      ),
    ];
  }

  List<ToolItem> get _filtered => _items.where((t) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return t.name.toLowerCase().contains(q) ||
        t.category.toLowerCase().contains(q) ||
        t.status.toLowerCase().contains(q);
  }).toList();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 1100;
    final isMobile = width < 768;

    return ResponsivePageLayout(
      currentPage: 'Inventory',
      title: 'Inventory',
      padding: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 18),
            // Search and Add button row
            if (isMobile) ...[
              SizedBox(
                    width: double.infinity,
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search tools',
                        isDense: true,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await showDialog(
                          context: context,
                          builder: (ctx) => const AddInventoryItemModal(),
                        );
                        if (result != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added: ${result['name']}'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Tool'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A18),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ] else
                  Row(
                children: [
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
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await showDialog(
                            context: context,
                            builder: (ctx) => const AddInventoryItemModal(),
                          );
                          if (result != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added: ${result['name']}'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          'Add Item',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                        ),
                      ),
                    ],
                  ),
            
            const SizedBox(height: 18),

            // Grid of all items
            Text(
              'All Tools & Machines',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, c) {
                final maxWidth = c.maxWidth;
                final crossAxis =
                    maxWidth ~/ 260; // each card ~260px
                final crossAxisCount = crossAxis.clamp(1, 4);
                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
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
              },
            ),
            const SizedBox(height: 22),

            // Active / In-use section
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Currently In Use',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${_active.length} active',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _active.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'No active tools currently',
                    ),
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _active
                        .map((a) => _activeCard(a, context))
                        .toList(),
                  ),
            SizedBox(height: isMobile ? 100 : 28),
          ],
        ),
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                color: Colors.grey[100],
              ),
              child: t.photoAsset != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: Image.asset(t.photoAsset!, fit: BoxFit.cover),
                    )
                  : Center(
                      child: Icon(
                        Icons.construction,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t.category,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusChip(t.status),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _showToolDetails(t),
                        icon: const Icon(Icons.more_horiz),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status.toLowerCase() == 'available'
        ? Colors.green
        : (status.toLowerCase() == 'maintenance'
              ? Colors.orange
              : Colors.redAccent);
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

  Widget _activeCard(ActiveUsage a, BuildContext ctx) {
    return SizedBox(
      width: 320,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // small photo
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: a.tool.photoAsset != null
                    ? Image.asset(a.tool.photoAsset!, fit: BoxFit.cover)
                    : const Icon(Icons.build, size: 36, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.tool.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Used by: ${a.users.join(', ')}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _statusChip(a.usageStatus),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            final result = await showDialog(
                              context: context,
                              builder: (ctx) =>
                                  ManageUsageModal(activeUsage: a),
                            );
                            if (result != null) {
                              if (result['action'] == 'return') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${a.tool.name} returned successfully',
                                    ),
                                  ),
                                );
                              } else if (result['action'] == 'update') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Usage updated successfully'),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text(
                            'Manage',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showToolDetails(ToolItem t) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ToolDetailsModal(tool: t),
    );
  }
}
