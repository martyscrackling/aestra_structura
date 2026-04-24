import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';
import 'package:go_router/go_router.dart';
import '../services/inventory_service.dart';
import '../services/auth_service.dart';
import '../services/app_theme_tokens.dart';
import 'package:intl/intl.dart';
import 'widgets/mobile_bottom_nav.dart';
import 'widgets/dashboard_header.dart';

class ToolItem {
  final String id;
  final String name;
  final String category;
  final String itemType;
  final String unitOfMeasure;
  final String status;
  final String? photoUrl;
  final String? serialNumber;
  final int quantity;
  final String? location;
  final String? notes;
  final String projectName;
  final List<Map<String, dynamic>> activeUsages;
  final List<Map<String, dynamic>> units;
  final List<String> unitStatuses;
  final List<Map<String, dynamic>> assignedProjects;

  ToolItem({
    required this.id,
    required this.name,
    required this.category,
    this.itemType = 'Tool',
    this.unitOfMeasure = 'pcs',
    required this.status,
    this.photoUrl,
    this.serialNumber,
    this.quantity = 1,
    this.location,
    this.notes,
    this.projectName = '',
    this.activeUsages = const [],
    this.units = const [],
    this.unitStatuses = const [],
    this.assignedProjects = const [],
  });

  bool get isMaterial => itemType.toLowerCase() == 'material';

  int get totalUnits => isMaterial
      ? quantity
      : (unitStatuses.isNotEmpty ? unitStatuses.length : quantity);

  int get availableUnitsCount {
    if (isMaterial) {
      return quantity;
    }
    if (unitStatuses.isEmpty) {
      return status == 'Available' ? quantity : 0;
    }
    return unitStatuses
        .where((s) => s == 'Available' || s == 'Returned')
        .length;
  }

  bool get hasCheckoutableUnits {
    if (isMaterial) {
      return quantity > 0;
    }
    if (unitStatuses.isNotEmpty) {
      return unitStatuses.any((s) => s == 'Available' || s == 'Returned');
    }
    return status == 'Available';
  }

  factory ToolItem.fromJson(Map<String, dynamic> json) {
    return ToolItem(
      id: json['item_id'].toString(),
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      itemType: (json['item_type'] ?? '').toString(),
      unitOfMeasure: (json['unit_of_measure'] ?? 'pcs').toString(),
      status: json['status'] ?? 'Available',
      photoUrl: json['photo_url'],
      serialNumber: json['serial_number'],
      quantity: json['quantity'] ?? 1,
      location: json['location'],
      notes: json['notes'],
      projectName: (json['project_name'] ?? '').toString(),
      activeUsages:
          (json['active_usages'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      units:
          (json['units'] as List<dynamic>?)
              ?.map((u) => u as Map<String, dynamic>)
              .toList() ??
          [],
      unitStatuses:
          (json['units'] as List<dynamic>?)
              ?.map(
                (u) => (u as Map<String, dynamic>)['status']?.toString() ?? '',
              )
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      assignedProjects:
          (json['assigned_projects'] as List<dynamic>?)
              ?.map((p) => Map<String, dynamic>.from(p as Map))
              .toList() ??
          [],
    );
  }
}

class ActiveUsage {
  final ToolItem tool;
  final String user;
  final String serial;
  final int? unitId;

  ActiveUsage({
    required this.tool,
    required this.user,
    required this.serial,
    this.unitId,
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
  final Color neutral = AppColors.surface;

  List<ToolItem> _items = [];
  List<ActiveUsage> _active = [];
  bool _isLoading = true;

  String _query = '';
  int? _focusItemId;

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
        if (item.isMaterial) continue;
        for (final usage in item.activeUsages) {
          final user = usage['field_worker_name']?.toString().isNotEmpty == true
              ? usage['field_worker_name'].toString()
              : usage['supervisor_name']?.toString() ?? 'Unknown';
          final unitCode = usage['unit_code']?.toString() ?? '';
          final serial = unitCode.isNotEmpty
              ? unitCode
              : (item.serialNumber?.isNotEmpty == true
                    ? item.serialNumber!
                    : 'N/A');
          active.add(
            ActiveUsage(
              tool: item,
              user: user,
              serial: serial,
              unitId: usage['inventory_unit'] is int
                  ? usage['inventory_unit'] as int
                  : int.tryParse(usage['inventory_unit']?.toString() ?? ''),
            ),
          );
        }
      }

      int? focusId;
      if (mounted) {
        final st = GoRouterState.of(context);
        final param =
            st.uri.queryParameters['item_id'] ?? st.uri.queryParameters['item'] ?? '';
        final parsed = int.tryParse(param);
        if (parsed != null) {
          if (items.any((t) => t.id == parsed.toString())) {
            focusId = parsed;
          }
        }
      }
      setState(() {
        _items = items;
        _active = active;
        if (focusId != null) {
          _focusItemId = focusId;
        }
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

  List<ToolItem> get _filteredToolsAndMachines => _filtered
      .where((t) => !t.isMaterial)
      .toList();

  List<ToolItem> get _filteredMaterials => _filtered
      .where((t) => t.isMaterial)
      .toList();

  void _navigateToPage(String page) {
    switch (page) {
      case 'Dashboard':
        context.go('/supervisor');
        break;
      case 'Projects':
        context.go('/supervisor/projects');
        break;
      case 'Workers':
      case 'Worker Management':
        context.go('/supervisor/workers');
        break;
      case 'Attendance':
        context.go('/supervisor/attendance');
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
                    const DashboardHeader(title: 'Inventory'),

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
                                    // Mobile search
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
                                          '${_filteredToolsAndMachines.length} items',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Tools table (PM-style responsive layout)
                                    Card(
                                      color: Colors.white,
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
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topLeft: Radius.circular(
                                                      12,
                                                    ),
                                                    topRight: Radius.circular(
                                                      12,
                                                    ),
                                                  ),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    'Tool/Machine Name',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: isMobile
                                                          ? 12
                                                          : 13,
                                                    ),
                                                  ),
                                                ),
                                                if (!isMobile)
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
                                                if (!isMobile)
                                                  const Expanded(
                                                    flex: 1,
                                                    child: Text(
                                                      'Unit',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
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
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                SizedBox(
                                                  width: isMobile ? 130 : 200,
                                                ), // availability + Use + Return
                                              ],
                                            ),
                                          ),

                                          // Table Body
                                          _filteredToolsAndMachines.isEmpty
                                              ? Padding(
                                                  padding: const EdgeInsets.all(
                                                    24,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      'No tools or machines found',
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
                                                  itemCount:
                                                      _filteredToolsAndMachines
                                                          .length,
                                                  itemBuilder: (context, i) {
                                                    final t =
                                                        _filteredToolsAndMachines[i];
                                                    final isEven = i.isEven;
                                                    return _tableRow(
                                                      t,
                                                      isEven,
                                                      isMobile,
                                                      highlightInbox: int.tryParse(
                                                            t.id,
                                                          ) ==
                                                          _focusItemId,
                                                    );
                                                  },
                                                ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 22),

                                    // Materials section
                                    Row(
                                      children: [
                                        Text(
                                          'All Materials',
                                          style: TextStyle(
                                            fontSize: isMobile ? 14 : 16,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '${_filteredMaterials.length} items',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Card(
                                      color: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isMobile ? 12 : 16,
                                              vertical: isMobile ? 10 : 14,
                                            ),
                                            decoration: BoxDecoration(
                                              color: primary.withOpacity(0.05),
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topLeft: Radius.circular(
                                                      12,
                                                    ),
                                                    topRight: Radius.circular(
                                                      12,
                                                    ),
                                                  ),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    'Material Name',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: isMobile
                                                          ? 12
                                                          : 13,
                                                    ),
                                                  ),
                                                ),
                                                if (!isMobile)
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
                                                if (!isMobile)
                                                  const Expanded(
                                                    flex: 1,
                                                    child: Text(
                                                      'Unit',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          _filteredMaterials.isEmpty
                                              ? Padding(
                                                  padding: const EdgeInsets.all(
                                                    24,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      'No materials found',
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
                                                  itemCount:
                                                      _filteredMaterials.length,
                                                  itemBuilder: (context, i) {
                                                    final t =
                                                        _filteredMaterials[i];
                                                    final isEven = i.isEven;
                                                    return _materialRow(
                                                      t,
                                                      isEven,
                                                      isMobile,
                                                      highlightInbox: int.tryParse(
                                                            t.id,
                                                          ) ==
                                                          _focusItemId,
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
                                                color: Colors.white,
                                                elevation: 1,
                                                margin: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        usage.tool.name,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        usage.tool.category,
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        'Serial: ${usage.serial}',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[700],
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        'Used by: ${usage.user}',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[700],
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          )
                                        : Card(
                                            color: Colors.white,
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
                                                          'Serial',
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
                                                            'No active units currently',
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

                                                          return Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      16,
                                                                  vertical: 12,
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
                                                                          borderRadius:
                                                                              BorderRadius.circular(
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
                                                                          usage
                                                                              .tool
                                                                              .name,
                                                                          style: const TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.w700,
                                                                            fontSize:
                                                                                14,
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
                                                                        color: Colors
                                                                            .grey,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                      ),
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                  ),
                                                                ),

                                                                const SizedBox(
                                                                  width: 12,
                                                                ),

                                                                // Serial
                                                                Expanded(
                                                                  flex: 2,
                                                                  child: Text(
                                                                    usage
                                                                        .serial,
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                    ),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),

                                                                const SizedBox(
                                                                  width: 12,
                                                                ),

                                                                // Users
                                                                Expanded(
                                                                  flex: 2,
                                                                  child: Text(
                                                                    usage.user,
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                    ),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    maxLines: 2,
                                                                  ),
                                                                ),
                                                              ],
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
    return SupervisorMobileBottomNav(
      activeTab: SupervisorMobileTab.more,
      activeMorePage: 'Inventory',
      onSelect: _navigateToPage,
    );
  }

  Widget _tableRow(
    ToolItem t,
    bool isEven,
    bool isMobile, {
    bool highlightInbox = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: isEven ? Colors.grey.shade50 : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          left: highlightInbox
              ? const BorderSide(color: Color(0xFFFF6F00), width: 3)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
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
                          'Units: ${t.totalUnits} • Projects: ${_projectsSummary(t)}',
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
          if (!isMobile)
            Expanded(
              flex: 1,
              child: Text(
                t.totalUnits.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
          SizedBox(
            width: isMobile ? 132 : 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _availabilitySummary(t),
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12,
                    fontWeight: FontWeight.w600,
                    color: t.availableUnitsCount > 0
                        ? const Color(0xFF0C1935)
                        : Colors.redAccent,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: t.hasCheckoutableUnits
                          ? () => _showUseItemModal(t)
                          : null,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Use',
                        style: TextStyle(
                          fontSize: isMobile ? 10 : 12,
                          fontWeight: FontWeight.w600,
                          color: t.hasCheckoutableUnits ? primary : Colors.grey,
                        ),
                      ),
                    ),
                    if (_canShowReturnForTool(t))
                      TextButton(
                        onPressed: () => _returnToolFromTable(t),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Return',
                          style: TextStyle(
                            fontSize: isMobile ? 10 : 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFF7A18),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _materialRow(
    ToolItem t,
    bool isEven,
    bool isMobile, {
    bool highlightInbox = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: isEven ? Colors.grey.shade50 : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          left: highlightInbox
              ? const BorderSide(color: Color(0xFFFF6F00), width: 3)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
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
                              errorBuilder: (_, __, ___) =>
                                  Icon(Icons.inventory_2, color: primary, size: 20),
                            ),
                          )
                        : Icon(Icons.inventory_2, color: primary, size: 20),
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
          if (!isMobile)
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          if (!isMobile)
            Expanded(
              flex: 1,
              child: Text(
                t.totalUnits.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  String _projectsSummary(ToolItem item) {
    final names = <String>{};

    for (final u in item.units) {
      final name = (u['current_project_name'] ?? '').toString().trim();
      if (name.isNotEmpty) names.add(name);
    }

    for (final p in item.assignedProjects) {
      final name = (p['project_name'] ?? '').toString().trim();
      if (name.isNotEmpty) names.add(name);
    }

    if (names.isEmpty && item.projectName.trim().isNotEmpty) {
      names.add(item.projectName.trim());
    }

    if (names.isEmpty) return 'Unassigned';
    if (names.length == 1) return names.first;
    return '${names.length} projects';
  }

  String _availabilitySummary(ToolItem item) {
    final total = item.totalUnits;
    final available = item.availableUnitsCount;

    if (item.isMaterial) {
      if (available <= 0) return 'Out of stock';
      final unit = item.unitOfMeasure.trim().isEmpty
          ? 'pcs'
          : item.unitOfMeasure.trim();
      return '$available $unit';
    }

    if (available <= 0) {
      return 'Unavailable';
    }
    if (total > 0 && available == total) {
      return 'All available';
    }
    if (available == 1) {
      return 'One available';
    }
    if (available == 2) {
      return 'Two available';
    }
    return '$available available';
  }

  int? _currentSupervisorId() {
    final user = AuthService().currentUser;
    final v = user?['supervisor_id'] ?? user?['user_id'];
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  int? _usageSupervisorId(Map<String, dynamic> u) {
    final raw = u['checked_out_by'];
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is Map) {
      final v = raw['supervisor_id'] ?? raw['id'];
      if (v is int) return v;
      return int.tryParse(v.toString());
    }
    return int.tryParse(raw.toString());
  }

  bool _statusIsCheckedOutMap(Map<String, dynamic> u) {
    return (u['status'] ?? '').toString().trim().toLowerCase() ==
        'checked out';
  }

  /// There is a checked-out unit (usage row or unit status) this flow can return.
  bool _canReturnCheckedOutTool(ToolItem t) {
    if (t.isMaterial) return false;
    final sid = _currentSupervisorId();
    if (sid == null) return false;
    for (final u in t.activeUsages) {
      if (!_statusIsCheckedOutMap(u)) continue;
      final cid = _usageSupervisorId(u);
      if (cid == null || cid == sid) return true;
    }
    for (final u in t.units) {
      if (_statusIsCheckedOutMap(u)) {
        // Fallback if usage payload is missing; backend enforces ownership.
        return true;
      }
    }
    return false;
  }

  /// Close an active checkout first; otherwise release an assigned (on-site) unit.
  bool _shouldReturnCheckoutFirst(ToolItem t) {
    if (t.isMaterial) return false;
    final sid = _currentSupervisorId();
    for (final u in t.activeUsages) {
      if (!_statusIsCheckedOutMap(u)) continue;
      final cid = _usageSupervisorId(u);
      if (sid == null) return true;
      if (cid == null || cid == sid) return true;
    }
    for (final u in t.units) {
      if (_statusIsCheckedOutMap(u)) return true;
    }
    return false;
  }

  int? _firstReturnableUnitIdForSupervisor(ToolItem t) {
    final sid = _currentSupervisorId();
    for (final u in t.activeUsages) {
      if (!_statusIsCheckedOutMap(u)) continue;
      final cid = _usageSupervisorId(u);
      if (sid != null && cid != null && cid != sid) continue;
      final iu = u['inventory_unit'];
      if (iu is int) return iu;
      if (iu == null) continue;
      return int.tryParse(iu.toString());
    }
    for (final u in t.units) {
      if (!_statusIsCheckedOutMap(u)) continue;
      final iu = u['unit_id'];
      if (iu is int) return iu;
      return int.tryParse(iu?.toString() ?? '');
    }
    return null;
  }

  bool _unitHasProjectAssignment(Map<String, dynamic> u) {
    if (_statusIsCheckedOutMap(u)) return false;
    final cp = u['current_project'];
    if (cp == null) return false;
    if (cp is int) return cp != 0;
    final s = cp.toString().trim();
    return s.isNotEmpty && s != 'null' && s != '0';
  }

  /// Assigned on a project (on-site) but not checked out — return to PM pool.
  bool _canReleaseAssignedUnit(ToolItem t) {
    if (t.isMaterial) return false;
    for (final u in t.units) {
      if (_unitHasProjectAssignment(u)) return true;
    }
    return false;
  }

  bool _canShowReturnForTool(ToolItem t) {
    return _canReturnCheckedOutTool(t) || _canReleaseAssignedUnit(t);
  }

  int? _firstReleasableAssignedUnitId(ToolItem t) {
    for (final u in t.units) {
      if (!_unitHasProjectAssignment(u)) continue;
      final iu = u['unit_id'];
      if (iu is int) return iu;
      return int.tryParse(iu?.toString() ?? '');
    }
    return null;
  }

  Future<void> _returnToolFromTable(ToolItem t) async {
    final useCheckout = _shouldReturnCheckoutFirst(t);
    final useRelease = !useCheckout && _canReleaseAssignedUnit(t);

    final body = useCheckout
        ? 'This will end your active checkout and return the unit to the project manager.'
        : 'This will send the on-site unit back to the project manager inventory (unassign from the project).';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Return to project manager'),
        content: Text('Return "${t.name}"? $body'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Return'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final supervisorId = _currentSupervisorId();
    if (supervisorId == null) return;

    try {
      if (useCheckout) {
        final unitId = _firstReturnableUnitIdForSupervisor(t);
        await InventoryService.returnItem(
          itemId: int.parse(t.id),
          supervisorId: supervisorId,
          unitId: unitId,
        );
      } else if (useRelease) {
        final unitId = _firstReleasableAssignedUnitId(t);
        if (unitId == null) {
          throw Exception('No unit to return');
        }
        await InventoryService.releaseAssignedUnitToPm(
          itemId: int.parse(t.id),
          supervisorId: supervisorId,
          unitId: unitId,
        );
      } else {
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.name} returned to project manager')),
        );
        await _loadItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Return failed: $e')),
        );
      }
    }
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
  final Map<int, String> _projectNamesById = {};

  int? _selectedFieldWorkerId;
  int? _selectedProjectId;
  int? _selectedUnitId;
  DateTime _checkoutDate = DateTime.now();
  DateTime? _expectedReturnDate;
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> get _availableUnits =>
      widget.tool.units.where((u) {
        final status = u['status']?.toString() ?? '';
        return status == 'Available' || status == 'Returned';
      }).toList();

  @override
  void initState() {
    super.initState();
    if (_availableUnits.isNotEmpty) {
      _selectedUnitId = _availableUnits.first['unit_id'] as int?;
    }
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
        InventoryService.getProjectsForSupervisor(
          supervisorId: widget.supervisorId,
        ),
      ]);
      if (mounted) {
        setState(() {
          _fieldWorkers = results[0];
          final rawProjects = results[1] as List<Map<String, dynamic>>;
          _projectNamesById
            ..clear()
            ..addEntries(
              rawProjects.map((p) {
                final id = _toInt(p['project_id'] ?? p['id']);
                final name = (p['project_name'] ?? p['name'] ?? '')
                    .toString()
                    .trim();
                if (id == null || name.isEmpty) {
                  return null;
                }
                return MapEntry(id, name);
              }).whereType<MapEntry<int, String>>(),
            );
          _syncProjectSelectionForItem();
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

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  Map<String, dynamic>? _workerById(int? workerId) {
    if (workerId == null) return null;
    for (final worker in _fieldWorkers) {
      if (_toInt(worker['fieldworker_id']) == workerId) {
        return worker;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _projectsForWorker(Map<String, dynamic>? worker) {
    if (worker == null) return const [];

    final projectsById = <int, String>{};

    void addProject(dynamic idRaw, dynamic nameRaw) {
      final id = _toInt(idRaw);
      if (id == null) return;
      final name = (nameRaw ?? '').toString().trim();
      final knownProjectName = (_projectNamesById[id] ?? '').trim();
      final existingName = (projectsById[id] ?? '').trim();
      projectsById[id] = name.isNotEmpty
          ? name
          : knownProjectName.isNotEmpty
          ? knownProjectName
          : existingName.isNotEmpty
          ? existingName
          : 'Project #$id';
    }

    final assignedProjects = worker['assigned_projects'];
    if (assignedProjects is List) {
      for (final project in assignedProjects) {
        if (project is Map) {
          final map = Map<String, dynamic>.from(project);
          addProject(
            map['project_id'] ?? map['id'],
            map['project_name'] ?? map['name'],
          );
        }
      }
    }

    addProject(worker['project_id'], worker['project_name']);

    final nestedProject = worker['project'];
    if (nestedProject is Map) {
      final map = Map<String, dynamic>.from(nestedProject);
      addProject(
        map['project_id'] ?? map['id'],
        map['project_name'] ?? map['name'],
      );
    }

    final projects =
        projectsById.entries
            .map(
              (entry) => <String, dynamic>{
                'project_id': entry.key,
                'project_name': entry.value,
              },
            )
            .toList()
          ..sort(
            (a, b) => (a['project_name'] as String).toLowerCase().compareTo(
              (b['project_name'] as String).toLowerCase(),
            ),
          );

    return projects;
  }

  List<Map<String, dynamic>> get _itemProjects {
    final sourceUnits = _availableUnits.isNotEmpty
        ? _availableUnits
        : widget.tool.units;
    final projectsById = <int, String>{};

    for (final unit in sourceUnits) {
      final id = _toInt(unit['current_project'] ?? unit['current_project_id']);
      if (id == null) continue;
      final nameFromUnit = (unit['current_project_name'] ?? '')
          .toString()
          .trim();
      final nameFromMap = (_projectNamesById[id] ?? '').trim();
      projectsById[id] = nameFromUnit.isNotEmpty
          ? nameFromUnit
          : nameFromMap.isNotEmpty
          ? nameFromMap
          : 'Project #$id';
    }

    final projects =
        projectsById.entries
            .map(
              (entry) => <String, dynamic>{
                'project_id': entry.key,
                'project_name': entry.value,
              },
            )
            .toList()
          ..sort(
            (a, b) => (a['project_name'] as String).toLowerCase().compareTo(
              (b['project_name'] as String).toLowerCase(),
            ),
          );

    return projects;
  }

  bool _workerAssignedToProject(Map<String, dynamic> worker, int? projectId) {
    if (projectId == null) return true;
    final workerProjectIds = _projectsForWorker(
      worker,
    ).map((p) => _toInt(p['project_id'])).whereType<int>().toSet();
    return workerProjectIds.contains(projectId);
  }

  List<Map<String, dynamic>> get _filteredFieldWorkers {
    if (_selectedProjectId == null) return _fieldWorkers;
    return _fieldWorkers
        .where((worker) => _workerAssignedToProject(worker, _selectedProjectId))
        .toList();
  }

  List<Map<String, dynamic>> get _projectFilteredUnits {
    if (_selectedProjectId == null) return _availableUnits;
    return _availableUnits.where((u) {
      final unitProjectId = _toInt(
        u['current_project'] ?? u['current_project_id'],
      );
      return unitProjectId == _selectedProjectId;
    }).toList();
  }

  void _syncUnitSelectionForProject() {
    final units = _projectFilteredUnits;
    final unitIds = units
        .map((u) => _toInt(u['unit_id']))
        .whereType<int>()
        .toSet();

    if (_selectedUnitId != null && !unitIds.contains(_selectedUnitId)) {
      _selectedUnitId = null;
    }

    if (_selectedUnitId == null && units.isNotEmpty) {
      _selectedUnitId = _toInt(units.first['unit_id']);
    }
  }

  void _syncProjectSelectionForItem() {
    final projects = _itemProjects;
    final projectIds = projects
        .map((p) => _toInt(p['project_id']))
        .whereType<int>()
        .toSet();

    if (_selectedProjectId != null &&
        !projectIds.contains(_selectedProjectId)) {
      _selectedProjectId = null;
    }

    if (_selectedProjectId == null && projects.isNotEmpty) {
      _selectedProjectId = _toInt(projects.first['project_id']);
    }

    if (_selectedFieldWorkerId != null) {
      final selectedWorker = _workerById(_selectedFieldWorkerId);
      final isSelectedWorkerValid =
          selectedWorker != null &&
          _workerAssignedToProject(selectedWorker, _selectedProjectId);
      if (!isSelectedWorkerValid) {
        _selectedFieldWorkerId = null;
      }
    }

    _syncUnitSelectionForProject();
  }

  void _onFieldWorkerChanged(int? workerId) {
    setState(() {
      _selectedFieldWorkerId = workerId;
    });
  }

  void _onProjectChanged(int? projectId) {
    setState(() {
      _selectedProjectId = projectId;
      _syncProjectSelectionForItem();
    });
  }

  Future<void> _submit() async {
    if (_selectedFieldWorkerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a field worker')),
      );
      return;
    }

    if (_selectedUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a unit to assign')),
      );
      return;
    }

    final itemProjects = _itemProjects;
    if (itemProjects.isNotEmpty && _selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a project first')),
      );
      return;
    }
    final selectedProjectId = _selectedProjectId;

    final checkoutDateOnly = DateTime(
      _checkoutDate.year,
      _checkoutDate.month,
      _checkoutDate.day,
    );
    final expectedDateOnly = _expectedReturnDate == null
        ? null
        : DateTime(
            _expectedReturnDate!.year,
            _expectedReturnDate!.month,
            _expectedReturnDate!.day,
          );
    if (expectedDateOnly != null &&
        expectedDateOnly.isBefore(checkoutDateOnly)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expected return date cannot be before checkout date'),
        ),
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
        unitId: _selectedUnitId,
        projectId: selectedProjectId,
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
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final checkoutDateOnly = DateTime(
      _checkoutDate.year,
      _checkoutDate.month,
      _checkoutDate.day,
    );
    final initial = isCheckout
        ? _checkoutDate
        : (_expectedReturnDate ??
              checkoutDateOnly.add(const Duration(days: 7)));
    final firstDate = isCheckout ? todayOnly : checkoutDateOnly;
    final safeInitial = initial.isBefore(firstDate) ? firstDate : initial;
    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isCheckout) {
          _checkoutDate = picked;
          if (_expectedReturnDate != null &&
              _expectedReturnDate!.isBefore(_checkoutDate)) {
            _expectedReturnDate = _checkoutDate;
          }
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
    final itemProjects = _itemProjects;
    final hasMultipleItemProjects = itemProjects.length > 1;
    final filteredWorkers = _filteredFieldWorkers;
    final projectFilteredUnits = _projectFilteredUnits;

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
                          // Item project selection
                          Text(
                            hasMultipleItemProjects
                                ? 'Select Project for Assignment *'
                                : 'Assigned Project',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (itemProjects.isEmpty)
                            Text(
                              'No project assignment found for this item.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: itemProjects.map((project) {
                                final projectId = _toInt(project['project_id']);
                                final isSelected =
                                    projectId != null &&
                                    projectId == _selectedProjectId;
                                final isSelectable =
                                    hasMultipleItemProjects &&
                                    projectId != null &&
                                    !_isLoading;
                                final badge = AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFE0F2FE)
                                        : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: isSelected
                                          ? widget.accent
                                          : const Color(0xFFD1D5DB),
                                      width: isSelected ? 1.6 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        project['project_name']
                                                    ?.toString()
                                                    .trim()
                                                    .isNotEmpty ==
                                                true
                                            ? project['project_name'].toString()
                                            : 'Project',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          color: isSelected
                                              ? const Color(0xFF0C4A6E)
                                              : const Color(0xFF374151),
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.check_circle,
                                          size: 14,
                                          color: Color(0xFF0284C7),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                                if (!isSelectable) {
                                  return badge;
                                }
                                return InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: () => _onProjectChanged(projectId),
                                  child: badge,
                                );
                              }).toList(),
                            ),
                          if (hasMultipleItemProjects)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Tap a project badge to filter workers for that project.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),

                          const SizedBox(height: 16),

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
                            initialValue: _selectedFieldWorkerId,
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
                            items: filteredWorkers.map((fw) {
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
                                : _onFieldWorkerChanged,
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
                          if (_fieldWorkers.isNotEmpty &&
                              filteredWorkers.isEmpty &&
                              _selectedProjectId != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'No field workers assigned to this project.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),

                          const SizedBox(height: 16),

                          // Unit dropdown
                          const Text(
                            'Select Unit *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedUnitId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: 'Select an available unit',
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
                            items: projectFilteredUnits.map((unit) {
                              final id = unit['unit_id'] as int;
                              final code =
                                  unit['unit_code']?.toString() ?? 'Unit $id';
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  code,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: _isLoading
                                ? null
                                : (v) => setState(() => _selectedUnitId = v),
                          ),
                          if (projectFilteredUnits.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _selectedProjectId == null
                                    ? 'No available units for this item'
                                    : 'No available units for the selected project',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red[700],
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
                color: Colors.white,
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
                        color: Colors.white,
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
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
