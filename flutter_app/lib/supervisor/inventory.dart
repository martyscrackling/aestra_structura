import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';
import 'package:go_router/go_router.dart';
import '../services/inventory_service.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';

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
  final bool initialSidebarVisible;

  const InventoryPage({super.key, this.initialSidebarVisible = false});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final Color primary = const Color(0xFF1396E9);
  final Color accent = const Color(0xFFFF6F00);
  final Color neutral = const Color(0xFFF6F8FA);

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
      final user = AuthService().currentUser;
      final supervisorId = user?['supervisor_id'] ?? user?['user_id'];
      if (supervisorId == null) return;
      final data = await InventoryService.getInventoryItemsForSupervisor(
        supervisorId: supervisorId,
      );
      final items = data.map((j) => ToolItem.fromJson(j)).toList();

      final active = <ActiveUsage>[];
      for (final item in items) {
        if (item.activeUsages.isNotEmpty) {
          final users = item.activeUsages
              .map(
                (u) => u['field_worker_name']?.toString().isNotEmpty == true
                    ? u['field_worker_name'].toString()
                    : u['supervisor_name']?.toString() ?? 'Unknown',
              )
              .toList();
          active.add(
            ActiveUsage(tool: item, users: users, usageStatus: 'In Use'),
          );
        }
      }

      setState(() {
        _items = items;
        _active = active;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load inventory: $e')));
      }
    } finally {
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

  void _navigateToPage(String page) {
    switch (page) {
      case 'Dashboard':
        context.go('/supervisor');
        break;
      case 'Workers':
      case 'Worker Management':
        context.go('/supervisor/workers');
        break;
      case 'Attendance':
        context.go('/supervisor/attendance');
        break;
      case 'Logs':
      case 'Daily Logs':
        context.go('/supervisor/daily-logs');
        break;
      case 'Tasks':
      case 'Task Progress':
        context.go('/supervisor/task-progress');
        break;
      case 'Reports':
        context.go('/supervisor/reports');
        break;
      case 'Inventory':
        return; // Already on inventory page
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 1024;
    final isMobile = width <= 600;

    return Scaffold(
      backgroundColor: neutral,
      body: Stack(
        children: [
          Row(
            children: [
              if (isDesktop)
                Sidebar(activePage: 'Inventory', keepVisible: true),
              Expanded(
                child: Column(
                  children: [
                    // White header with slim blue line at left corner
                    Container(
                      color: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 22,
                        vertical: isMobile ? 12 : 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: isMobile ? 3 : 4,
                            height: isMobile ? 40 : 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6F00),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Inventory',
                                  style: TextStyle(
                                    color: const Color(0xFF0C1935),
                                    fontSize: isMobile ? 16 : 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (!isMobile) const SizedBox(height: 4),
                                if (!isMobile)
                                  const Text(
                                    'Tools & machines used on site',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Search field (hidden on mobile)
                          if (!isMobile) ...[
                            SizedBox(
                              width: width > 1100 ? 360 : 200,
                              child: TextField(
                                onChanged: (v) => setState(() => _query = v),
                                decoration: InputDecoration(
                                  hintText: 'Search tools, category, status',
                                  isDense: true,
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 20,
                                  ),
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
                              style: TextButton.styleFrom(
                                foregroundColor: primary,
                              ),
                            ),
                          ],
                          // Notification icon
                          IconButton(
                            icon: Stack(
                              children: [
                                Icon(
                                  Icons.notifications_outlined,
                                  color: const Color(0xFF0C1935),
                                  size: isMobile ? 22 : 24,
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: isMobile ? 8 : 10,
                                    height: isMobile ? 8 : 10,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF6B6B),
                                      borderRadius: BorderRadius.circular(
                                        isMobile ? 4 : 6,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            onPressed: () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Notifications opened (demo)',
                                    ),
                                  ),
                                ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : 22,
                              ),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Mobile search + materials button (only on mobile)
                                    if (isMobile) ...[
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              onChanged: (v) =>
                                                  setState(() => _query = v),
                                              decoration: InputDecoration(
                                                hintText: 'Search tools...',
                                                isDense: true,
                                                prefixIcon: const Icon(
                                                  Icons.search,
                                                  size: 20,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                filled: true,
                                                fillColor: Colors.grey[100],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const MaterialsPage(),
                                                ),
                                              );
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: primary,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 12,
                                                  ),
                                            ),
                                            child: const Icon(
                                              Icons.layers,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                    ],

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
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Tools table
                                    isMobile
                                        ? Column(
                                            children: _filtered.map((tool) {
                                              return Card(
                                                elevation: 1,
                                                margin: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: InkWell(
                                                  onTap: () =>
                                                      _showToolDetails(tool),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          12,
                                                        ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                tool.name,
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                            ),
                                                            _statusChip(
                                                              tool.status,
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        Text(
                                                          tool.category,
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey[600],
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                        if (tool.status ==
                                                            'Available') ...[
                                                          const SizedBox(
                                                            height: 8,
                                                          ),
                                                          Align(
                                                            alignment: Alignment
                                                                .centerRight,
                                                            child: TextButton(
                                                              onPressed: () =>
                                                                  _showUseItemModal(
                                                                    tool,
                                                                  ),
                                                              style: TextButton.styleFrom(
                                                                backgroundColor:
                                                                    accent
                                                                        .withOpacity(
                                                                          0.1,
                                                                        ),
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          16,
                                                                      vertical:
                                                                          6,
                                                                    ),
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        6,
                                                                      ),
                                                                ),
                                                              ),
                                                              child: Text(
                                                                'Use',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: accent,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          )
                                        : Card(
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              children: [
                                                // Table header
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 14,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: primary.withOpacity(
                                                      0.05,
                                                    ),
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                          topLeft:
                                                              Radius.circular(
                                                                12,
                                                              ),
                                                          topRight:
                                                              Radius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Expanded(
                                                        flex: 3,
                                                        child: Text(
                                                          'Tool/Machine Name',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                      const Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          'Category',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                      const Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          'Status',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        width: 40,
                                                      ), // for icon
                                                    ],
                                                  ),
                                                ),

                                                // Table body
                                                _filtered.isEmpty
                                                    ? Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              24,
                                                            ),
                                                        child: Center(
                                                          child: Text(
                                                            'No tools found',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                    : ListView.builder(
                                                        shrinkWrap: true,
                                                        physics:
                                                            const NeverScrollableScrollPhysics(),
                                                        itemCount:
                                                            _filtered.length,
                                                        itemBuilder: (context, i) {
                                                          final t =
                                                              _filtered[i];
                                                          final isEven =
                                                              i.isEven;

                                                          return InkWell(
                                                            onTap: () =>
                                                                _showToolDetails(
                                                                  t,
                                                                ),
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        16,
                                                                    vertical:
                                                                        12,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: isEven
                                                                    ? Colors
                                                                          .grey
                                                                          .shade50
                                                                    : Colors
                                                                          .white,
                                                                border: Border(
                                                                  bottom:
                                                                      i ==
                                                                          _filtered.length -
                                                                              1
                                                                      ? BorderSide
                                                                            .none
                                                                      : BorderSide(
                                                                          color: Colors
                                                                              .grey
                                                                              .shade200,
                                                                          width:
                                                                              1,
                                                                        ),
                                                                ),
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  // Tool name with icon
                                                                  Expanded(
                                                                    flex: 3,
                                                                    child: Row(
                                                                      children: [
                                                                        Container(
                                                                          width:
                                                                              40,
                                                                          height:
                                                                              40,
                                                                          decoration: BoxDecoration(
                                                                            color: primary.withOpacity(
                                                                              0.1,
                                                                            ),
                                                                            borderRadius: BorderRadius.circular(
                                                                              8,
                                                                            ),
                                                                          ),
                                                                          child:
                                                                              t.photoUrl !=
                                                                                      null &&
                                                                                  t.photoUrl!.isNotEmpty
                                                                              ? ClipRRect(
                                                                                  borderRadius: BorderRadius.circular(
                                                                                    8,
                                                                                  ),
                                                                                  child: Image.network(
                                                                                    t.photoUrl!,
                                                                                    width: 40,
                                                                                    height: 40,
                                                                                    fit: BoxFit.cover,
                                                                                    errorBuilder:
                                                                                        (
                                                                                          _,
                                                                                          __,
                                                                                          ___,
                                                                                        ) => Icon(
                                                                                          Icons.construction,
                                                                                          color: primary,
                                                                                          size: 20,
                                                                                        ),
                                                                                  ),
                                                                                )
                                                                              : Icon(
                                                                                  Icons.construction,
                                                                                  color: primary,
                                                                                  size: 20,
                                                                                ),
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              12,
                                                                        ),
                                                                        Expanded(
                                                                          child: Text(
                                                                            t.name,
                                                                            style: const TextStyle(
                                                                              fontWeight: FontWeight.w700,
                                                                              fontSize: 14,
                                                                            ),
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),

                                                                  // Category
                                                                  Expanded(
                                                                    flex: 2,
                                                                    child: Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            10,
                                                                        vertical:
                                                                            6,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: Colors
                                                                            .grey[100],
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              6,
                                                                            ),
                                                                      ),
                                                                      child: Text(
                                                                        t.category,
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              12,
                                                                          color:
                                                                              Colors.grey,
                                                                        ),
                                                                        textAlign:
                                                                            TextAlign.center,
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  ),

                                                                  const SizedBox(
                                                                    width: 12,
                                                                  ),

                                                                  // Status
                                                                  Expanded(
                                                                    flex: 2,
                                                                    child: _statusChip(
                                                                      t.status,
                                                                    ),
                                                                  ),

                                                                  // View details icon
                                                                  const SizedBox(
                                                                    width: 12,
                                                                  ),
                                                                  SizedBox(
                                                                    width: 80,
                                                                    child:
                                                                        t.status ==
                                                                            'Available'
                                                                        ? TextButton(
                                                                            onPressed: () => _showUseItemModal(
                                                                              t,
                                                                            ),
                                                                            style: TextButton.styleFrom(
                                                                              backgroundColor: accent.withOpacity(
                                                                                0.1,
                                                                              ),
                                                                              padding: const EdgeInsets.symmetric(
                                                                                horizontal: 12,
                                                                                vertical: 6,
                                                                              ),
                                                                              shape: RoundedRectangleBorder(
                                                                                borderRadius: BorderRadius.circular(
                                                                                  6,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            child: Text(
                                                                              'Use',
                                                                              style: TextStyle(
                                                                                fontSize: 12,
                                                                                fontWeight: FontWeight.w700,
                                                                                color: accent,
                                                                              ),
                                                                            ),
                                                                          )
                                                                        : Icon(
                                                                            Icons.chevron_right,
                                                                            color:
                                                                                Colors.grey[400],
                                                                            size:
                                                                                20,
                                                                          ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                              ],
                                            ),
                                          ),

                                    const SizedBox(height: 22),

                                    // Active / In-use section
                                    Row(
                                      children: [
                                        Text(
                                          'Currently In Use',
                                          style: TextStyle(
                                            fontSize: isMobile ? 14 : 16,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '${_active.length} active',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Active usage table
                                    isMobile
                                        ? Column(
                                            children: _active.map((usage) {
                                              return Card(
                                                elevation: 1,
                                                margin: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: InkWell(
                                                  onTap: () => _showToolDetails(
                                                    usage.tool,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          12,
                                                        ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                usage.tool.name,
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                            ),
                                                            _statusChip(
                                                              usage.usageStatus,
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        Text(
                                                          usage.tool.category,
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey[600],
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        Text(
                                                          'Used by: ${usage.users.join(', ')}',
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey[700],
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          )
                                        : Card(
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              children: [
                                                // Table header
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 14,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: accent.withOpacity(
                                                      0.05,
                                                    ),
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                          topLeft:
                                                              Radius.circular(
                                                                12,
                                                              ),
                                                          topRight:
                                                              Radius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                  ),
                                                  child: Row(
                                                    children: const [
                                                      Expanded(
                                                        flex: 3,
                                                        child: Text(
                                                          'Tool/Machine Name',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          'Category',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          'Used By',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          'Status',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 80,
                                                      ), // for actions
                                                    ],
                                                  ),
                                                ),

                                                // Table body
                                                _active.isEmpty
                                                    ? Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              24,
                                                            ),
                                                        child: Center(
                                                          child: Text(
                                                            'No active tools currently',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                    : ListView.builder(
                                                        shrinkWrap: true,
                                                        physics:
                                                            const NeverScrollableScrollPhysics(),
                                                        itemCount:
                                                            _active.length,
                                                        itemBuilder: (context, i) {
                                                          final usage =
                                                              _active[i];
                                                          final isEven =
                                                              i.isEven;

                                                          return InkWell(
                                                            onTap: () =>
                                                                _showToolDetails(
                                                                  usage.tool,
                                                                ),
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        16,
                                                                    vertical:
                                                                        12,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: isEven
                                                                    ? Colors
                                                                          .grey
                                                                          .shade50
                                                                    : Colors
                                                                          .white,
                                                                border: Border(
                                                                  bottom:
                                                                      i ==
                                                                          _active.length -
                                                                              1
                                                                      ? BorderSide
                                                                            .none
                                                                      : BorderSide(
                                                                          color: Colors
                                                                              .grey
                                                                              .shade200,
                                                                          width:
                                                                              1,
                                                                        ),
                                                                ),
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  // Tool name with icon
                                                                  Expanded(
                                                                    flex: 3,
                                                                    child: Row(
                                                                      children: [
                                                                        Container(
                                                                          width:
                                                                              40,
                                                                          height:
                                                                              40,
                                                                          decoration: BoxDecoration(
                                                                            color: accent.withOpacity(
                                                                              0.1,
                                                                            ),
                                                                            borderRadius: BorderRadius.circular(
                                                                              8,
                                                                            ),
                                                                          ),
                                                                          child:
                                                                              usage.tool.photoUrl !=
                                                                                      null &&
                                                                                  usage.tool.photoUrl!.isNotEmpty
                                                                              ? ClipRRect(
                                                                                  borderRadius: BorderRadius.circular(
                                                                                    8,
                                                                                  ),
                                                                                  child: Image.network(
                                                                                    usage.tool.photoUrl!,
                                                                                    fit: BoxFit.cover,
                                                                                    errorBuilder:
                                                                                        (
                                                                                          _,
                                                                                          __,
                                                                                          ___,
                                                                                        ) => Icon(
                                                                                          Icons.build,
                                                                                          color: accent,
                                                                                          size: 20,
                                                                                        ),
                                                                                  ),
                                                                                )
                                                                              : Icon(
                                                                                  Icons.build,
                                                                                  color: accent,
                                                                                  size: 20,
                                                                                ),
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              12,
                                                                        ),
                                                                        Expanded(
                                                                          child: Text(
                                                                            usage.tool.name,
                                                                            style: const TextStyle(
                                                                              fontWeight: FontWeight.w700,
                                                                              fontSize: 14,
                                                                            ),
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),

                                                                  // Category
                                                                  Expanded(
                                                                    flex: 2,
                                                                    child: Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            10,
                                                                        vertical:
                                                                            6,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: Colors
                                                                            .grey[100],
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              6,
                                                                            ),
                                                                      ),
                                                                      child: Text(
                                                                        usage
                                                                            .tool
                                                                            .category,
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              12,
                                                                          color:
                                                                              Colors.grey,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  ),

                                                                  const SizedBox(
                                                                    width: 12,
                                                                  ),

                                                                  // Users
                                                                  Expanded(
                                                                    flex: 2,
                                                                    child: Text(
                                                                      usage
                                                                          .users
                                                                          .join(
                                                                            ', ',
                                                                          ),
                                                                      style: const TextStyle(
                                                                        fontSize:
                                                                            13,
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                      ),
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                      maxLines:
                                                                          2,
                                                                    ),
                                                                  ),

                                                                  const SizedBox(
                                                                    width: 12,
                                                                  ),

                                                                  // Status
                                                                  Expanded(
                                                                    flex: 2,
                                                                    child: _statusChip(
                                                                      usage
                                                                          .usageStatus,
                                                                    ),
                                                                  ),

                                                                  // View button
                                                                  const SizedBox(
                                                                    width: 12,
                                                                  ),
                                                                  TextButton(
                                                                    onPressed: () =>
                                                                        _showToolDetails(
                                                                          usage
                                                                              .tool,
                                                                        ),
                                                                    style: TextButton.styleFrom(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            4,
                                                                        vertical:
                                                                            4,
                                                                      ),
                                                                    ),
                                                                    child: const Text(
                                                                      'View',
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                              ],
                                            ),
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
        ],
      ),
      bottomNavigationBar: isMobile ? _buildBottomNavBar() : null,
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1935),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.dashboard, 'Dashboard', false),
                _buildNavItem(Icons.people, 'Workers', false),
                _buildNavItem(Icons.check_circle, 'Attendance', false),
                _buildNavItem(Icons.list_alt, 'Logs', false),
                _buildNavItem(Icons.more_horiz, 'More', true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    final color = isActive ? const Color(0xFFFF6F00) : Colors.white70;

    return InkWell(
      onTap: () {
        if (label == 'More') {
          _showMoreOptions();
        } else {
          _navigateToPage(label);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFF6F00).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0C1935),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _buildMoreOption(
                Icons.show_chart,
                'Task Progress',
                'Tasks',
                false,
              ),
              _buildMoreOption(Icons.file_copy, 'Reports', 'Reports', false),
              _buildMoreOption(Icons.inventory, 'Inventory', 'Inventory', true),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOption(
    IconData icon,
    String title,
    String page,
    bool isActive,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? const Color(0xFFFF6F00) : Colors.white70,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isActive ? const Color(0xFFFF6F00) : Colors.white,
          fontSize: 14,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        _navigateToPage(page);
      },
    );
  }

  Widget _statusChip(String status) {
    final lower = status.toLowerCase();
    final color = lower == 'available'
        ? Colors.green
        : lower == 'maintenance'
        ? Colors.orange
        : lower == 'returned'
        ? Colors.blue
        : Colors.redAccent;
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
                child: a.tool.photoUrl != null && a.tool.photoUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          a.tool.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.build,
                            size: 36,
                            color: Colors.grey,
                          ),
                        ),
                      )
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
                          onPressed: () => _showToolDetails(a.tool),
                          child: const Text(
                            'View',
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

  void _showUseItemModal(ToolItem tool) {
    final user = AuthService().currentUser;
    final supervisorId = user?['supervisor_id'] ?? user?['user_id'];
    if (supervisorId == null) return;

    showDialog(
      context: context,
      builder: (ctx) => _UseItemModal(
        tool: tool,
        supervisorId: supervisorId,
        accent: accent,
        onSuccess: () {
          _loadItems();
        },
      ),
    );
  }

  Future<void> _returnItem(ToolItem tool) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Return Item'),
        content: Text('Are you sure you want to return "${tool.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Return'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final user = AuthService().currentUser;
      final supervisorId = user?['supervisor_id'] ?? user?['user_id'];
      if (supervisorId == null) return;
      await InventoryService.returnItem(
        itemId: int.parse(tool.id),
        supervisorId: supervisorId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tool.name} returned successfully')),
        );
        _loadItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to return item: $e')));
      }
    }
  }

  void _showToolDetails(ToolItem t) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with close button
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.construction, color: primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Photo section
              if (t.photoUrl != null && t.photoUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    t.photoUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.construction,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.construction,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Details
              const Text(
                'Details',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),

              _detailRow('Category', t.category),
              if (t.serialNumber != null && t.serialNumber!.isNotEmpty)
                _detailRow('Serial No.', t.serialNumber!),
              _detailRow('Quantity', t.quantity.toString()),
              if (t.location != null && t.location!.isNotEmpty)
                _detailRow('Location', t.location!),
              if (t.notes != null && t.notes!.isNotEmpty)
                _detailRow('Notes', t.notes!),
              _detailRow('Status', '', customValue: _statusChip(t.status)),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                  if (t.status == 'Checked Out') ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _returnItem(t);
                      },
                      icon: const Icon(Icons.assignment_return, size: 18),
                      label: const Text('Return'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Widget? customValue}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child:
                customValue ??
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

// ── Use Item Modal ───────────────────────────────────────────────────────────
class _UseItemModal extends StatefulWidget {
  final ToolItem tool;
  final dynamic supervisorId;
  final Color accent;
  final VoidCallback onSuccess;

  const _UseItemModal({
    required this.tool,
    required this.supervisorId,
    required this.accent,
    required this.onSuccess,
  });

  @override
  State<_UseItemModal> createState() => _UseItemModalState();
}

class _UseItemModalState extends State<_UseItemModal> {
  bool _isLoading = false;
  bool _isLoadingData = true;

  List<Map<String, dynamic>> _fieldWorkers = [];

  int? _selectedFieldWorkerId;
  DateTime _checkoutDate = DateTime.now();
  DateTime? _expectedReturnDate;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        InventoryService.getFieldWorkersForSupervisor(
          supervisorId: widget.supervisorId,
        ),
      ]);
      if (mounted) {
        setState(() {
          _fieldWorkers = results[0];
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedFieldWorkerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a field worker')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await InventoryService.checkoutItem(
        itemId: int.parse(widget.tool.id),
        supervisorId: widget.supervisorId is int
            ? widget.supervisorId
            : int.parse(widget.supervisorId.toString()),
        userId: widget.supervisorId,
        fieldWorkerId: _selectedFieldWorkerId,
        expectedReturnDate: _expectedReturnDate != null
            ? '${_expectedReturnDate!.year}-${_expectedReturnDate!.month.toString().padLeft(2, '0')}-${_expectedReturnDate!.day.toString().padLeft(2, '0')}'
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.tool.name} has been checked out')),
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
      }
    }
  }

  Future<void> _pickDate({required bool isCheckout}) async {
    final initial = isCheckout
        ? _checkoutDate
        : (_expectedReturnDate ?? DateTime.now().add(const Duration(days: 7)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isCheckout) {
          _checkoutDate = picked;
        } else {
          _expectedReturnDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: isMobile ? 24 : 40,
      ),
      child: Container(
        width: isMobile ? double.infinity : 520,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.handyman, color: widget.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assign Item',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0C1935),
                          ),
                        ),
                        Text(
                          widget.tool.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: Colors.grey[600],
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // ── Body ──
            Flexible(
              child: _isLoadingData
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Field Worker dropdown
                          const Text(
                            'Assign to Field Worker *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            value: _selectedFieldWorkerId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: 'Select a field worker',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            items: _fieldWorkers.map((fw) {
                              final id = fw['fieldworker_id'] as int;
                              final name =
                                  '${fw['first_name'] ?? ''} ${fw['last_name'] ?? ''}'
                                      .trim();
                              final role = fw['role'] ?? '';
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  '$name${role.isNotEmpty ? ' ($role)' : ''}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: _isLoading
                                ? null
                                : (v) => setState(
                                    () => _selectedFieldWorkerId = v,
                                  ),
                          ),
                          if (_fieldWorkers.isEmpty && !_isLoadingData)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'No field workers found for your projects',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),

                          const SizedBox(height: 16),

                          // Dates row
                          Row(
                            children: [
                              // Checkout date
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Checkout Date',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: _isLoading
                                          ? null
                                          : () => _pickDate(isCheckout: true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF9FAFB),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              dateFormat.format(_checkoutDate),
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Expected return date
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Expected Return',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: _isLoading
                                          ? null
                                          : () => _pickDate(isCheckout: false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF9FAFB),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.event,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _expectedReturnDate != null
                                                  ? dateFormat.format(
                                                      _expectedReturnDate!,
                                                    )
                                                  : 'Select date',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color:
                                                    _expectedReturnDate != null
                                                    ? Colors.black
                                                    : Colors.grey[400],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Notes
                          const Text(
                            'Notes',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _notesController,
                            maxLines: 3,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: 'Additional notes (optional)',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // ── Footer ──
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: isMobile
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: widget.accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Assign Item',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: widget.accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Assign Item',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
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
  final Color primary = const Color(0xFF1396E9);
  final Color neutral = const Color(0xFFF6F8FA);

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

  @override
  Widget build(BuildContext context) {
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
            icon: const Icon(Icons.add, color: Color(0xFF1396E9)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Construction Materials',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_materials.length} items',
                  style: const TextStyle(color: Colors.grey),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.05),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: const [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Material Name',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
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
                            flex: 2,
                            child: Text(
                              'Status',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(width: 100), // for action button
                        ],
                      ),
                    ),

                    // Table body
                    Expanded(
                      child: ListView.builder(
                        itemCount: _materials.length,
                        itemBuilder: (context, i) {
                          final m = _materials[i];
                          final isEven = i.isEven;

                          return InkWell(
                            onTap: () => _showMaterialDetails(m),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isEven
                                    ? Colors.grey.shade50
                                    : Colors.white,
                                border: Border(
                                  bottom: i == _materials.length - 1
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
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
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
                                        Expanded(
                                          child: Text(
                                            m.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Quantity
                                  Expanded(
                                    flex: 2,
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
                                      child: _materialStatusChip(m.status),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // Use button
                                  SizedBox(
                                    width: 100,
                                    child: TextButton.icon(
                                      onPressed: () => _showUseDialog(m),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Use',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
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
