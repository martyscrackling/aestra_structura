import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/responsive_page_layout.dart';
import 'modals/tool_details_modal.dart';
import 'modals/add_inventory_item_modal.dart';
import 'modals/manage_usage_modal.dart';
import 'materials_page.dart';

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
      child: SingleChildScrollView(
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
                          SnackBar(content: Text('Added: ${result['name']}')),
                        );
                      }
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Add Item',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(backgroundColor: primary),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MaterialsPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.layers),
                    label: const Text('Materials'),
                    style: TextButton.styleFrom(foregroundColor: primary),
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
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MaterialsPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.layers),
                      label: const Text('Materials'),
                      style: TextButton.styleFrom(foregroundColor: primary),
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
                            SnackBar(content: Text('Added: ${result['name']}')),
                          );
                        }
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'Add Item',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(backgroundColor: primary),
                    ),
                  ],
                ),

              const SizedBox(height: 18),

              // Table of all items
              Row(
                children: [
                  Text(
                    'All Tools & Machines',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_filtered.length} items',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Table Container
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Table Header
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
                              'Tool/Machine Name',
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
                                'Category',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          Expanded(
                            flex: isMobile ? 1 : 2,
                            child: Text(
                              'Status',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: isMobile ? 12 : 13,
                              ),
                            ),
                          ),
                          SizedBox(width: isMobile ? 22 : 40), // for icon
                        ],
                      ),
                    ),

                    // Table Body
                    _filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'No tools found',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) {
                              final t = _filtered[i];
                              final isEven = i.isEven;
                              return _tableRow(t, isEven, isMobile);
                            },
                          ),
                  ],
                ),
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
              // Currently In Use Table
              _active.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('No active tools currently'),
                    )
                  : Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Table Header
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
                                  flex: 4,
                                  child: Text(
                                    'Tool/Machine',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: isMobile ? 12 : 13,
                                    ),
                                  ),
                                ),
                                if (!isMobile)
                                  const Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Category',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                const Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Used By',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: isMobile ? 2 : 3,
                                  child: Text(
                                    'Status',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: isMobile ? 12 : 13,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: isMobile ? 70 : 110,
                                ), // for manage button
                              ],
                            ),
                          ),

                          // Table Body
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _active.length,
                            itemBuilder: (context, i) {
                              final a = _active[i];
                              final isEven = i.isEven;
                              return _activeUsageRow(a, isEven, isMobile);
                            },
                          ),
                        ],
                      ),
                    ),
              SizedBox(height: isMobile ? 100 : 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableRow(ToolItem t, bool isEven, bool isMobile) {
    return InkWell(
      onTap: () => _showToolDetails(t),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: isEven ? Colors.grey.shade50 : Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Tool name with icon
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  if (!isMobile) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.construction, color: primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      t.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: isMobile ? 13 : 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Category (hidden on mobile)
            if (!isMobile)
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      t.category,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

            // Status
            Expanded(
              flex: isMobile ? 1 : 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _statusChip(t.status),
              ),
            ),

            // View details icon
            SizedBox(width: isMobile ? 22 : 40),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: isMobile ? 18 : 20,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _activeUsageRow(ActiveUsage a, bool isEven, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: isEven ? Colors.grey.shade50 : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Tool name with icon
          Expanded(
            flex: 4,
            child: Row(
              children: [
                if (!isMobile) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.build, color: primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    a.tool.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: isMobile ? 13 : 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Category (hidden on mobile)
          if (!isMobile)
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    a.tool.category,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),

          const SizedBox(width: 8),

          // Users
          Expanded(
            flex: 3,
            child: Text(
              a.users.join(', '),
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                color: Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 8),

          // Status
          Expanded(
            flex: isMobile ? 2 : 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _statusChip(a.usageStatus),
            ),
          ),

          const SizedBox(width: 8),

          // Manage button
          SizedBox(
            width: isMobile ? 70 : 110,
            child: TextButton(
              onPressed: () async {
                final result = await showDialog(
                  context: context,
                  builder: (ctx) => ManageUsageModal(activeUsage: a),
                );
                if (result != null) {
                  if (result['action'] == 'return') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${a.tool.name} returned successfully'),
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
              child: Text(
                'Manage',
                style: TextStyle(fontSize: isMobile ? 11 : 12),
              ),
            ),
          ),
        ],
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
