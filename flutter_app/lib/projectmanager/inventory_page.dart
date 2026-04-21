import 'package:flutter/material.dart';
import 'widgets/responsive_page_layout.dart';
import 'modals/add_inventory_item_modal.dart';
import 'modals/assign_inventory_item_modal.dart';
import 'modals/manage_usage_modal.dart';
import '../services/inventory_service.dart';
import '../services/auth_service.dart';

class ToolItem {
  final String id;
  final String name;
  final String category;
  final String status;
  final String? projectName;
  final String? photoUrl;
  final String? serialNumber;
  final int quantity;
  final int assignedProjectsCount;
  final String? location;
  final String? notes;
  final List<Map<String, dynamic>> units;
  final List<Map<String, dynamic>> activeUsages;

  ToolItem({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    this.projectName,
    this.photoUrl,
    this.serialNumber,
    this.quantity = 1,
    this.assignedProjectsCount = 0,
    this.location,
    this.notes,
    this.units = const [],
    this.activeUsages = const [],
  });

  factory ToolItem.fromJson(Map<String, dynamic> json) {
    return ToolItem(
      id: json['item_id'].toString(),
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      status: json['status'] ?? 'Available',
      projectName: json['project_name'],
      photoUrl: json['photo_url'],
      serialNumber: json['serial_number'],
      quantity: json['quantity'] ?? 1,
      assignedProjectsCount: json['assigned_projects_count'] ?? 0,
      location: json['location'],
      notes: json['notes'],
      units:
          (json['units'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
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
  final String unitCode;
  final String projectName;
  final String usedBy;
  final List<String> users;
  final String usageStatus;
  final String expectedReturnDate;

  ActiveUsage({
    required this.tool,
    required this.unitCode,
    required this.projectName,
    required this.usedBy,
    this.users = const [],
    required this.usageStatus,
    required this.expectedReturnDate,
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
        for (final usage in item.activeUsages) {
          final status = (usage['status'] ?? '').toString().trim();
          if (status.toLowerCase() != 'checked out') {
            continue;
          }

          final supervisor = (usage['supervisor_name'] ?? '').toString().trim();
          final fieldWorker = (usage['field_worker_name'] ?? '')
              .toString()
              .trim();
          final usedBy = fieldWorker.isNotEmpty
              ? '$supervisor / $fieldWorker'
              : (supervisor.isNotEmpty ? supervisor : 'Unknown');

          final unitCode = (usage['unit_code'] ?? '').toString().trim();
          final projectName = (usage['project_name'] ?? '').toString().trim();
          final expectedReturnDate = (usage['expected_return_date'] ?? '')
              .toString()
              .trim();

          active.add(
            ActiveUsage(
              tool: item,
              unitCode: unitCode.isNotEmpty ? unitCode : 'No Unit Code',
              projectName: projectName.isNotEmpty ? projectName : 'Unassigned',
              usedBy: usedBy,
              users: [usedBy],
              usageStatus: status.isNotEmpty ? status : 'Checked Out',
              expectedReturnDate: expectedReturnDate.isNotEmpty
                  ? expectedReturnDate
                  : 'Not set',
            ),
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
        t.category.toLowerCase().contains(q);
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
                        color: Colors.white,
                        surfaceTintColor: Colors.transparent,
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
                                  if (!isMobile)
                                    const Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Unit',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  if (!isMobile)
                                    const Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Project',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  SizedBox(
                                    width: isMobile ? 120 : 160,
                                  ), // for assign/manage actions
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
                              color: Colors.white,
                              surfaceTintColor: Colors.transparent,
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
                                            'Unit',
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
                                            'Project',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: isMobile ? 12 : 13,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: isMobile ? 2 : 3,
                                          child: Text(
                                            'Expected Return Date',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: isMobile ? 12 : 13,
                                            ),
                                          ),
                                        ),
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
    final hasAssignedUnits = tool.units.any(
      (u) => (u['current_project_name'] ?? '').toString().trim().isNotEmpty,
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Manage: ${tool.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF0C1935),
                ),
                title: const Text(
                  'Increase Units',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Add more unit records to this item profile',
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showAdjustUnitsDialog(tool: tool, isIncrease: true);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.orange,
                ),
                title: const Text(
                  'Decrease Units',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Removes only unassigned removable units from this profile',
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showAdjustUnitsDialog(tool: tool, isIncrease: false);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: Text(
                  'Delete Item',
                  style: TextStyle(
                    color: hasAssignedUnits
                        ? const Color(0xFF9CA3AF)
                        : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: hasAssignedUnits
                    ? const Text(
                        'Disabled while one or more units are assigned to projects',
                      )
                    : null,
                onTap: hasAssignedUnits
                    ? null
                    : () {
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

  Future<void> _showAdjustUnitsDialog({
    required ToolItem tool,
    required bool isIncrease,
  }) async {
    final countController = TextEditingController(text: '1');
    final serialControllers = <TextEditingController>[TextEditingController()];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        void syncSerialControllers() {
          final target = int.tryParse(countController.text.trim()) ?? 1;
          final safeTarget = target < 1 ? 1 : target;
          while (serialControllers.length < safeTarget) {
            serialControllers.add(TextEditingController());
          }
          while (serialControllers.length > safeTarget) {
            serialControllers.removeLast().dispose();
          }
        }

        if (isIncrease) {
          syncSerialControllers();
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(isIncrease ? 'Increase Units' : 'Decrease Units'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: countController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Unit count',
                          hintText: 'Enter number of units',
                        ),
                        onChanged: (_) {
                          if (!isIncrease) return;
                          setModalState(() {
                            syncSerialControllers();
                          });
                        },
                      ),
                      if (isIncrease) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Serial Numbers (optional)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(serialControllers.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextField(
                              controller: serialControllers[index],
                              decoration: InputDecoration(
                                labelText: 'Unit ${index + 1} serial',
                                hintText: 'Enter serial number',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final parsed = int.tryParse(countController.text.trim());
                    if (parsed == null || parsed < 1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid unit count.'),
                        ),
                      );
                      return;
                    }

                    final serialNumbers = serialControllers
                        .map((c) => c.text.trim())
                        .where((s) => s.isNotEmpty)
                        .toList();

                    Navigator.of(
                      ctx,
                    ).pop({'count': parsed, 'serial_numbers': serialNumbers});
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    countController.dispose();
    for (final controller in serialControllers) {
      controller.dispose();
    }

    final count = result?['count'] as int?;
    final serialNumbers = (result?['serial_numbers'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    if (count == null || count < 1) return;

    try {
      final userId = AuthService().currentUser?['user_id'];
      final itemId = int.parse(tool.id);

      if (isIncrease) {
        await InventoryService.addUnitsToItem(
          itemId: itemId,
          userId: userId,
          count: count,
          serialNumbers: serialNumbers,
        );
      } else {
        await InventoryService.removeUnitsFromItem(
          itemId: itemId,
          userId: userId,
          count: count,
        );
      }

      await _loadItems();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isIncrease
                ? 'Added $count unit(s) to ${tool.name}'
                : 'Removed $count unit(s) from ${tool.name}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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

  Future<void> _showAssignProjectDialog(ToolItem tool) async {
    final itemId = int.tryParse(tool.id);
    if (itemId == null) return;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          AssignInventoryItemModal(itemId: itemId, itemName: tool.name),
    );

    if (result == null) return;

    await _loadItems();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updated unit assignments for ${tool.name}')),
    );
  }

  Widget _tableRow(ToolItem t, bool isEven, bool isMobile) {
    return Container(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isMobile ? 13 : 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isMobile) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Units: ${t.quantity} • Projects: ${_projectsSummary(t)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
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

          // Units (desktop)
          if (!isMobile)
            Expanded(
              flex: 1,
              child: Text(
                _unitsDisplayText(t),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Projects summary (desktop)
          if (!isMobile)
            Expanded(
              flex: 2,
              child: Text(
                _projectsSummary(t),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // View details icon + Manage button
          SizedBox(
            width: isMobile ? 120 : 160,
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _showAssignProjectDialog(t),
                    child: Text(
                      'Assign',
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0C1935),
                      ),
                    ),
                  ),
                ),
                Expanded(
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
        ],
      ),
    );
  }

  String _projectsSummary(ToolItem item) {
    final projectNames = item.units
        .map((u) => (u['current_project_name'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .toSet();

    return projectNames.isEmpty
        ? 'Unassigned'
        : projectNames.length == 1
        ? projectNames.first
        : '${projectNames.length} projects';
  }

  int _assignedUnitsCount(ToolItem item) {
    return item.units
        .where(
          (u) => (u['current_project_name'] ?? '').toString().trim().isNotEmpty,
        )
        .length;
  }

  String _unitsDisplayText(ToolItem item) {
    final assignedCount = _assignedUnitsCount(item);
    if (assignedCount <= 0) {
      return item.quantity.toString();
    }
    return '${item.quantity} ($assignedCount assigned)';
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
          // Unit with parent item name
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.unitCode,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isMobile ? 13 : 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a.tool.name,
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: const Color(0xFF6B7280),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
              a.usedBy,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                color: Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 8),

          // Project
          Expanded(
            flex: isMobile ? 2 : 3,
            child: Text(
              a.projectName,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                color: Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 8),

          // Return Date
          Expanded(
            flex: isMobile ? 2 : 3,
            child: Text(
              a.expectedReturnDate,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
