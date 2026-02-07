import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/app_config.dart';
import 'widgets/sidebar.dart';
import 'dashboard_page.dart';
import 'attendance_page.dart';
import 'daily_logs.dart';
import 'task_progress.dart';
import 'reports.dart';
import 'inventory.dart';

class WorkerManagementPage extends StatefulWidget {
  final bool initialSidebarVisible;

  const WorkerManagementPage({super.key, this.initialSidebarVisible = false});

  @override
  State<WorkerManagementPage> createState() => _WorkerManagementPageState();
}

class _WorkerManagementPageState extends State<WorkerManagementPage> {
  late bool _isSidebarVisible;
  late Future<List<Map<String, dynamic>>> _workersFuture;

  @override
  void initState() {
    super.initState();
    _isSidebarVisible = widget.initialSidebarVisible;
    _workersFuture = _fetchFieldWorkers();
  }

  Future<List<Map<String, dynamic>>> _fetchFieldWorkers() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final projectId = authService.currentUser?['project_id'];

      print('=== Fetching Field Workers ===');
      print('Supervisor project_id: $projectId');

      if (projectId == null) {
        print('❌ No project assigned to supervisor');
        return [];
      }

      final url = AppConfig.apiUri('field-workers/?project_id=$projectId');
      print('📡 API URL: $url');

      final response = await http.get(url);

      print('📊 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('✅ Found ${data.length} field workers');
        return data.cast<Map<String, dynamic>>();
      } else {
        print('❌ Failed to fetch field workers: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching field workers: $e');
      return [];
    }
  }

  void _navigateToPage(String page) {
    Widget destination;
    switch (page) {
      case 'Dashboard':
        destination = const SupervisorDashboardPage(
          initialSidebarVisible: false,
        );
        break;
      case 'Workers':
        return; // Already on workers page
      case 'Attendance':
        destination = const AttendancePage(initialSidebarVisible: false);
        break;
      case 'Logs':
        destination = const DailyLogsPage(initialSidebarVisible: false);
        break;
      case 'Tasks':
        destination = const TaskProgressPage(initialSidebarVisible: false);
        break;
      case 'Reports':
        destination = const ReportsPage(initialSidebarVisible: false);
        break;
      case 'Inventory':
        destination = const InventoryPage(initialSidebarVisible: false);
        break;
      default:
        return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  String searchQuery = '';
  String selectedRole = 'All';
  String sortBy = 'Name A-Z';

  final List<String> roles = [
    'All',
    'Mason',
    'Painter',
    'Electrician',
    'Carpenter',
  ];
  final List<String> sortOptions = ['Name A-Z', 'Name Z-A', 'Recently Hired'];

  List<Map<String, dynamic>> _filterAndSortWorkers(
    List<Map<String, dynamic>> allWorkers,
  ) {
    final filtered = allWorkers.where((worker) {
      final fullName = '${worker['first_name']} ${worker['last_name']}'
          .toLowerCase();
      final matchesSearch = fullName.contains(searchQuery.toLowerCase());
      final matchesRole =
          selectedRole == 'All' || worker['role'] == selectedRole;
      return matchesSearch && matchesRole;
    }).toList();

    if (sortBy == 'Name A-Z') {
      filtered.sort((a, b) {
        final nameA = '${a['first_name']} ${a['last_name']}';
        final nameB = '${b['first_name']} ${b['last_name']}';
        return nameA.compareTo(nameB);
      });
    } else if (sortBy == 'Name Z-A') {
      filtered.sort((a, b) {
        final nameA = '${a['first_name']} ${a['last_name']}';
        final nameB = '${b['first_name']} ${b['last_name']}';
        return nameB.compareTo(nameA);
      });
    } else if (sortBy == 'Recently Hired') {
      filtered.sort((a, b) {
        final dateA = a['created_at'] ?? '';
        final dateB = b['created_at'] ?? '';
        return dateB.compareTo(dateA);
      });
    }
    return filtered;
  }

  Color getStatusColor(String status) {
    // Field workers don't have status in DB, default to Active
    return Colors.green;
  }

  String _getWorkerName(Map<String, dynamic> worker) {
    final firstName = worker['first_name'] ?? '';
    final lastName = worker['last_name'] ?? '';
    return '$firstName $lastName'.trim();
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatPayrate(dynamic payrate) {
    if (payrate == null) return 'Not set';
    return '₱${payrate}/day';
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Painter':
        return const Color(0xFFFF6F00);
      case 'Electrician':
        return const Color(0xFF9E9E9E);
      case 'Plumber':
        return const Color(0xFF757575);
      case 'Carpenter':
        return const Color(0xFFFF8F00);
      default:
        return Colors.blueGrey;
    }
  }

  // ---------------------------
  // Worker detail modal (keeps previous functionality)
  // ---------------------------
  void _showWorkerDetailModal(
    BuildContext context,
    Map<String, dynamic> worker,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final roleColor = _roleColor(worker["role"]);
        final workerName = _getWorkerName(worker);
        final phoneNumber = worker['phone_number'] ?? 'N/A';
        final birthdate = _formatDate(worker['birthdate']);
        final payrate = _formatPayrate(worker['payrate']);
        final dateHired = _formatDate(worker['created_at']);
        final sssId = worker['sss_id'] ?? 'N/A';
        final philhealthId = worker['philhealth_id'] ?? 'N/A';
        final pagibigId = worker['pagibig_id'] ?? 'N/A';

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with role accent
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 48,
                              decoration: BoxDecoration(
                                color: roleColor.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              "Worker Profile",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Profile
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.person,
                              size: 56,
                              color: roleColor,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            workerName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              worker["role"] ?? 'Worker',
                              style: TextStyle(
                                color: roleColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Details
                    const Text(
                      "Personal Information",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow("Phone", phoneNumber),
                    _buildDetailRow("Birthdate", birthdate),
                    _buildDetailRow("SSS ID", sssId),
                    _buildDetailRow("PhilHealth ID", philhealthId),
                    _buildDetailRow("Pag-IBIG ID", pagibigId),
                    const SizedBox(height: 12),
                    const Text(
                      "Work Details",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow("Date Hired", dateHired),
                    _buildDetailRow("Payrate", payrate),
                    _buildDetailRowWithStatus(
                      "Status",
                      "Active",
                      getStatusColor("Active"),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'QR Code for $workerName downloaded!',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.qr_code),
                            label: const Text("Download QR"),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFF1396E9)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check),
                          label: const Text("Close"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1396E9),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithStatus(
    String label,
    String value,
    Color statusColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool hasNotifications = true;

  Widget _buildHeaderCell(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: Color(0xFF0C1935),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isTablet = screenWidth > 600 && screenWidth <= 1024;
    final isMobile = screenWidth <= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Stack(
        children: [
          Row(
            children: [
              if (_isSidebarVisible && isDesktop)
                Sidebar(
                  activePage: "Worker Management",
                  keepVisible: _isSidebarVisible,
                ),
              Expanded(
                child: Column(
                  children: [
                    // White header with blue left accent (keeps Notification bell & AESTRA)
                    WorkersHeader(
                      onMenuPressed: () => setState(
                        () => _isSidebarVisible = !_isSidebarVisible,
                      ),
                      isMobile: isMobile,
                    ),

                    // Scrollable content area
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _workersFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final allWorkers = snapshot.data ?? [];
                          final filteredWorkers = _filterAndSortWorkers(
                            allWorkers,
                          );

                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                SizedBox(height: isMobile ? 4 : 8),

                                // Search & filter creative card - Responsive
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 12 : 20,
                                  ),
                                  child: Material(
                                    elevation: 4,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: EdgeInsets.all(
                                        isMobile ? 6 : 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: isMobile
                                          ? Row(
                                              children: [
                                                // Search on mobile (takes most space)
                                                Expanded(
                                                  child: TextField(
                                                    decoration: InputDecoration(
                                                      hintText: 'Search...',
                                                      hintStyle:
                                                          const TextStyle(
                                                            fontSize: 11,
                                                          ),
                                                      prefixIcon: const Icon(
                                                        Icons.search,
                                                        size: 16,
                                                      ),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        borderSide:
                                                            BorderSide.none,
                                                      ),
                                                      filled: true,
                                                      fillColor:
                                                          Colors.grey[50],
                                                      contentPadding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 6,
                                                            horizontal: 8,
                                                          ),
                                                      isDense: true,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                    onChanged: (v) => setState(
                                                      () => searchQuery = v,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                // Role filter dropdown (compact)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: DropdownButton<String>(
                                                    value: selectedRole,
                                                    underline: const SizedBox(),
                                                    isDense: true,
                                                    icon: const Icon(
                                                      Icons.filter_list,
                                                      size: 16,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.black87,
                                                    ),
                                                    items: roles
                                                        .map(
                                                          (
                                                            r,
                                                          ) => DropdownMenuItem(
                                                            value: r,
                                                            child: Text(
                                                              r,
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                  ),
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                    onChanged: (v) => setState(
                                                      () => selectedRole =
                                                          v ?? 'All',
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                // Sort dropdown (compact)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: DropdownButton<String>(
                                                    value: sortBy,
                                                    underline: const SizedBox(),
                                                    isDense: true,
                                                    icon: const Icon(
                                                      Icons.sort,
                                                      size: 16,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.black87,
                                                    ),
                                                    items: sortOptions
                                                        .map(
                                                          (
                                                            s,
                                                          ) => DropdownMenuItem(
                                                            value: s,
                                                            child: Text(
                                                              s,
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                  ),
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                    onChanged: (v) => setState(
                                                      () =>
                                                          sortBy = v ?? sortBy,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              children: [
                                                // Search on tablet/desktop
                                                Expanded(
                                                  flex: isTablet ? 4 : 3,
                                                  child: TextField(
                                                    decoration: InputDecoration(
                                                      hintText:
                                                          'Search workers by name, phone or role',
                                                      prefixIcon: const Icon(
                                                        Icons.search,
                                                      ),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        borderSide:
                                                            BorderSide.none,
                                                      ),
                                                      filled: true,
                                                      fillColor:
                                                          Colors.grey[50],
                                                      contentPadding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 12,
                                                          ),
                                                    ),
                                                    onChanged: (v) => setState(
                                                      () => searchQuery = v,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                // Role filter dropdown on tablet/desktop
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: DropdownButton<String>(
                                                    value: selectedRole,
                                                    underline: const SizedBox(),
                                                    hint: const Text(
                                                      'Filter by role',
                                                    ),
                                                    items: roles
                                                        .map(
                                                          (r) =>
                                                              DropdownMenuItem(
                                                                value: r,
                                                                child: Text(r),
                                                              ),
                                                        )
                                                        .toList(),
                                                    onChanged: (v) => setState(
                                                      () => selectedRole =
                                                          v ?? 'All',
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                // sort dropdown
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: DropdownButton<String>(
                                                    value: sortBy,
                                                    underline: const SizedBox(),
                                                    items: sortOptions
                                                        .map(
                                                          (s) =>
                                                              DropdownMenuItem(
                                                                value: s,
                                                                child: Text(s),
                                                              ),
                                                        )
                                                        .toList(),
                                                    onChanged: (v) => setState(
                                                      () =>
                                                          sortBy = v ?? sortBy,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: isMobile ? 8 : 12),

                                // Workers list - Responsive: Cards on mobile, table on desktop
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 12 : 20,
                                  ),
                                  child: filteredWorkers.isEmpty
                                      ? SizedBox(
                                          height: 200,
                                          child: Center(
                                            child: Text(
                                              'No workers found',
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ),
                                        )
                                      : isMobile
                                      ? _buildMobileWorkersList(filteredWorkers)
                                      : _buildDesktopWorkersTable(
                                          isTablet,
                                          filteredWorkers,
                                        ),
                                ),
                                SizedBox(height: isMobile ? 8 : 12),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Overlay sidebar for tablet only
          if (_isSidebarVisible && isTablet)
            GestureDetector(
              onTap: () => setState(() => _isSidebarVisible = false),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          if (_isSidebarVisible && isTablet)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Sidebar(
                activePage: "Worker Management",
                keepVisible: _isSidebarVisible,
              ),
            ),
        ],
      ),
      // Bottom navigation bar for mobile only
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
                _buildNavItem(Icons.people, 'Workers', true),
                _buildNavItem(Icons.check_circle, 'Attendance', false),
                _buildNavItem(Icons.list_alt, 'Logs', false),
                _buildNavItem(Icons.more_horiz, 'More', false),
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
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.3,
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
              _buildMoreOption(Icons.show_chart, 'Task Progress', 'Tasks'),
              _buildMoreOption(Icons.file_copy, 'Reports', 'Reports'),
              _buildMoreOption(Icons.inventory, 'Inventory', 'Inventory'),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOption(IconData icon, String title, String page) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        _navigateToPage(page);
      },
    );
  }

  // Mobile card-based list view
  Widget _buildMobileWorkersList(List<Map<String, dynamic>> filteredWorkers) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredWorkers.length,
      itemBuilder: (context, index) {
        final worker = filteredWorkers[index];
        final roleColor = _roleColor(worker['role']);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showWorkerDetailModal(context, worker),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Avatar + Name + Status
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: roleColor.withOpacity(0.12),
                        child: Text(
                          _getWorkerName(worker).isNotEmpty
                              ? _getWorkerName(worker)[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: roleColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getWorkerName(worker),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: roleColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                worker['role'] ?? 'Worker',
                                style: TextStyle(
                                  color: roleColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: getStatusColor('Active').withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: getStatusColor('Active'),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Active',
                              style: TextStyle(
                                color: getStatusColor('Active'),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // Details rows
                  _buildMobileDetailRow(
                    Icons.phone,
                    worker['phone_number'] ?? 'N/A',
                  ),
                  const SizedBox(height: 6),
                  _buildMobileDetailRow(
                    Icons.calendar_today,
                    _formatDate(worker['created_at']),
                  ),
                  const SizedBox(height: 10),
                  // Action button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showWorkerDetailModal(context, worker),
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF6F00),
                        side: const BorderSide(color: Color(0xFFFF6F00)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileDetailRow(IconData icon, String text, {int maxLines = 1}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
            overflow: TextOverflow.ellipsis,
            maxLines: maxLines,
          ),
        ),
      ],
    );
  }

  // Desktop/Tablet table view
  Widget _buildDesktopWorkersTable(
    bool isTablet,
    List<Map<String, dynamic>> filteredWorkers,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Table header
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFF6F00).withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 12 : 16,
              vertical: isTablet ? 12 : 14,
            ),
            child: Row(
              children: [
                _buildHeaderCell('Name', flex: 3),
                _buildHeaderCell('Role', flex: 2),
                if (!isTablet) _buildHeaderCell('Phone', flex: 2),
                _buildHeaderCell('Date Hired', flex: 2),
                _buildHeaderCell('Status', flex: 2),
                _buildHeaderCell('Actions', flex: 1),
              ],
            ),
          ),
          const Divider(height: 1),
          // Table body
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredWorkers.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final worker = filteredWorkers[index];
              final roleColor = _roleColor(worker['role']);
              return InkWell(
                onTap: () => _showWorkerDetailModal(context, worker),
                hoverColor: const Color(0xFFFF6F00).withOpacity(0.03),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 12 : 16,
                    vertical: isTablet ? 10 : 12,
                  ),
                  child: Row(
                    children: [
                      // Name column
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: isTablet ? 16 : 20,
                              backgroundColor: roleColor.withOpacity(0.12),
                              child: Text(
                                _getWorkerName(worker).isNotEmpty
                                    ? _getWorkerName(worker)[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: roleColor,
                                  fontSize: isTablet ? 12 : 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(width: isTablet ? 8 : 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getWorkerName(worker),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: isTablet ? 13 : 14,
                                    ),
                                  ),
                                  if (!isTablet)
                                    Text(
                                      worker['role'] ?? 'Worker',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Role column
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 8 : 10,
                            vertical: isTablet ? 4 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            worker['role'] ?? 'Worker',
                            style: TextStyle(
                              color: roleColor,
                              fontWeight: FontWeight.w600,
                              fontSize: isTablet ? 11 : 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      // Phone column (hide on tablet)
                      if (!isTablet)
                        Expanded(
                          flex: 2,
                          child: Text(
                            worker['phone_number'] ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      // Date Hired column
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: isTablet ? 12 : 14,
                              color: Colors.grey[500],
                            ),
                            SizedBox(width: isTablet ? 4 : 6),
                            Expanded(
                              child: Text(
                                _formatDate(worker['created_at']),
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: isTablet ? 11 : 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status column
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 8 : 10,
                            vertical: isTablet ? 4 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: getStatusColor('Active').withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: isTablet ? 6 : 8,
                                height: isTablet ? 6 : 8,
                                decoration: BoxDecoration(
                                  color: getStatusColor('Active'),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: isTablet ? 4 : 6),
                              Flexible(
                                child: Text(
                                  'Active',
                                  style: TextStyle(
                                    color: getStatusColor('Active'),
                                    fontWeight: FontWeight.w700,
                                    fontSize: isTablet ? 11 : 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Actions column
                      Expanded(
                        flex: 1,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.remove_red_eye_outlined,
                                size: isTablet ? 18 : 20,
                              ),
                              color: const Color(0xFF1396E9),
                              onPressed: () =>
                                  _showWorkerDetailModal(context, worker),
                              tooltip: 'View Details',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            if (!isTablet) const SizedBox(width: 8),
                            if (!isTablet)
                              PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'toggle') {
                                    setState(() {
                                      worker['status'] =
                                          worker['status'] == 'Active'
                                          ? 'Inactive'
                                          : 'Active';
                                    });
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Text(
                                      worker['status'] == 'Active'
                                          ? 'Set Inactive'
                                          : 'Set Active',
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Remove (demo)'),
                                  ),
                                ],
                                icon: const Icon(Icons.more_vert, size: 20),
                                padding: EdgeInsets.zero,
                              ),
                          ],
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
    );
  }
}

// ---------------------------
// Header
// ---------------------------
class WorkersHeader extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  final bool isMobile;
  const WorkersHeader({super.key, this.onMenuPressed, this.isMobile = false});

  @override
  State<WorkersHeader> createState() => _WorkersHeaderState();
}

class _WorkersHeaderState extends State<WorkersHeader> {
  bool hasNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // keep header white
      padding: EdgeInsets.symmetric(
        horizontal: widget.isMobile ? 12 : 24,
        vertical: widget.isMobile ? 12 : 16,
      ),
      child: Row(
        children: [
          // Hamburger menu button (hidden on mobile)
          if (!widget.isMobile) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF0C1935), size: 24),
              onPressed: widget.onMenuPressed,
              tooltip: 'Menu',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ],
          // slim blue line in the left corner
          Container(
            width: widget.isMobile ? 3 : 4,
            height: widget.isMobile ? 40 : 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6F00),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          SizedBox(width: widget.isMobile ? 8 : 12),
          // Title + subtitle (no Super Highway text)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Workers",
                  style: TextStyle(
                    color: const Color(0xFF0C1935),
                    fontSize: widget.isMobile ? 16 : 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!widget.isMobile) const SizedBox(height: 4),
                if (!widget.isMobile)
                  const Text(
                    "Manage your workforce",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
          ),
          // Right side - Notifications & AESTRA (simplified on mobile)
          if (!widget.isMobile)
            Row(
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => hasNotifications = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notifications opened (demo)'),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Color(0xFF0C1935),
                            size: 24,
                          ),
                        ),
                        if (hasNotifications)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B6B),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                PopupMenuButton<String>(
                  onSelected: (value) {},
                  offset: const Offset(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'switch',
                          height: 48,
                          child: Row(
                            children: [
                              Icon(
                                Icons.swap_horiz,
                                size: 18,
                                color: Color(0xFF0C1935),
                              ),
                              SizedBox(width: 12),
                              Text('Switch Account'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(height: 1),
                        const PopupMenuItem<String>(
                          value: 'logout',
                          height: 48,
                          child: Row(
                            children: [
                              Icon(
                                Icons.logout,
                                size: 18,
                                color: Color(0xFFFF6B6B),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Logout',
                                style: TextStyle(color: Color(0xFFFF6B6B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8D5F2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                "A",
                                style: TextStyle(
                                  color: Color(0xFFB088D9),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "AESTRA",
                                style: TextStyle(
                                  color: Color(0xFF0C1935),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                "Supervisor",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            // Mobile: Just show notification icon
            IconButton(
              icon: Stack(
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xFF0C1935),
                    size: 22,
                  ),
                  if (hasNotifications)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                setState(() => hasNotifications = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications opened (demo)')),
                );
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
