import 'package:flutter/material.dart';
import 'widgets/responsive_page_layout.dart';
import 'modals/tool_details_modal.dart';
import 'modals/add_inventory_item_modal.dart';
import 'modals/manage_usage_modal.dart';
import '../services/inventory_service.dart';
import '../services/auth_service.dart';

class ToolItem {
  final String id;
  final String name;
  final String category;
  final String status;
  final String? photoUrl;
  final String? serialNumber;
  final int quantity;
  final String? location;
  final String? notes;
  final List<Map<String, dynamic>> activeUsages;

  ToolItem({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    this.photoUrl,
    this.serialNumber,
    this.quantity = 1,
    this.location,
    this.notes,
    this.activeUsages = const [],
  });

  factory ToolItem.fromJson(Map<String, dynamic> json) {
    return ToolItem(
      id: json['item_id'].toString(),
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      status: json['status'] ?? 'Available',
      photoUrl: json['photo_url'],
      serialNumber: json['serial_number'],
      quantity: json['quantity'] ?? 1,
      location: json['location'],
      notes: json['notes'],
      activeUsages:
          (json['active_usages'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
    );
  }
}

class ActiveUsage {
  final ToolItem tool;
  final List<String> users;
  final String usageStatus;

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

  List<ToolItem> _items = [];
  List<ActiveUsage> _active = [];
  bool _isLoading = true;

  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final userId = AuthService().currentUser?['user_id'];
      if (userId == null) return;
      final data = await InventoryService.getInventoryItems(userId: userId);
      final items = data.map((j) => ToolItem.fromJson(j)).toList();

      // Build active usage list from items that have active_usages
      final active = <ActiveUsage>[];
      for (final item in items) {
        if (item.activeUsages.isNotEmpty) {
          final users = item.activeUsages
              .map((u) => u['supervisor_name']?.toString() ?? 'Unknown')
              .toList();
          active.add(
            ActiveUsage(tool: item, users: users, usageStatus: 'Checked Out'),
          );
        }
      }

      if (mounted) {
        setState(() {
          _items = items;
          _active = active;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading inventory: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadItems,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 18),
                      // Search and Add button row
                      if (isMobile) ...[
                        SizedBox(
                          height: 36,
                          child: TextField(
                            onChanged: (v) => setState(() => _query = v),
                            decoration: InputDecoration(
                              hintText: 'Search tools...',
                              hintStyle: const TextStyle(fontSize: 13),
                              prefixIcon: const Icon(Icons.search, size: 18),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0C1935),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final result = await showDialog(
                                context: context,
                                builder: (ctx) => const AddInventoryItemModal(),
                              );
                              if (result == true) {
                                _loadItems();
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
                        ),
                        const SizedBox(height: 12),
                      ] else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Add Item button
                            SizedBox(
                              height: 40,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await showDialog(
                                    context: context,
                                    builder: (ctx) =>
                                        const AddInventoryItemModal(),
                                  );
                                  if (result == true) {
                                    _loadItems();
                                  }
                                },
                                icon: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Add Item',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Search field (compact)
                            SizedBox(
                              height: 36,
                              width: 200,
                              child: TextField(
                                onChanged: (v) => setState(() => _query = v),
                                decoration: InputDecoration(
                                  hintText: 'Search tools...',
                                  hintStyle: const TextStyle(fontSize: 13),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 18,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF0C1935),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 18),

                      // Table of all items
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'All Tools & Machines',
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0C1935),
                              ),
                            ),
                          ),
                          Text(
                            '${_filtered.length} items',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
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
                                  SizedBox(
                                    width: isMobile ? 70 : 90,
                                  ), // for manage button
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
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
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
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0C1935),
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
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _active.length,
                                    itemBuilder: (context, i) {
                                      final a = _active[i];
                                      final isEven = i.isEven;
                                      return _activeUsageRow(
                                        a,
                                        isEven,
                                        isMobile,
                                      );
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
            ),
    );
  }

  void _showManageStatusDialog(ToolItem? tool) {
    if (tool == null) return;
    final statuses = ['Available', 'Maintenance', 'Checked Out', 'Returned'];
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Manage: ${tool.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...statuses.map((s) {
                return ListTile(
                  title: Text(s),
                  leading: Radio<String>(
                    value: s,
                    groupValue: tool.status,
                    onChanged: null,
                  ),
                  trailing: tool.status == s
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    try {
                      final userId = AuthService().currentUser?['user_id'];
                      await InventoryService.updateItemStatus(
                        itemId: int.parse(tool.id),
                        status: s,
                        userId: userId,
                      );
                      _loadItems();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${tool.name} status changed to $s'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                );
              }),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'Delete Item',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmDeleteItem(tool);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteItem(ToolItem tool) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text(
          'Are you sure you want to permanently delete "${tool.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final userId = AuthService().currentUser?['user_id'];
      await InventoryService.deleteItem(
        itemId: int.parse(tool.id),
        userId: userId,
      );
      _loadItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tool.name} deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
                      child: t.photoUrl != null && t.photoUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                t.photoUrl!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.construction,
                                  color: primary,
                                  size: 20,
                                ),
                              ),
                            )
                          : Icon(Icons.construction, color: primary, size: 20),
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

            // View details icon + Manage button
            SizedBox(
              width: isMobile ? 70 : 90,
              child: TextButton(
                onPressed: () => _showManageStatusDialog(t),
                child: Text(
                  'Manage',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
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
                    child:
                        a.tool.photoUrl != null && a.tool.photoUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              a.tool.photoUrl!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Icon(Icons.build, color: primary, size: 20),
                            ),
                          )
                        : Icon(Icons.build, color: primary, size: 20),
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

          // View button
          SizedBox(
            width: isMobile ? 70 : 110,
            child: TextButton(
              onPressed: () => _showToolDetails(a.tool),
              child: Text(
                'View',
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
