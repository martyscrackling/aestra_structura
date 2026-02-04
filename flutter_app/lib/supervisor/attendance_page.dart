import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/app_config.dart';
import 'widgets/sidebar.dart';

class AttendancePage extends StatefulWidget {
  final bool initialSidebarVisible;

  const AttendancePage({super.key, this.initialSidebarVisible = false});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final Color primary = const Color(0xFFFF6F00);
  final Color primaryLight = const Color(0xFFFFF3E0);
  final Color neutral = const Color(0xFFF4F6F9);
  late bool _isSidebarVisible;

  late Future<List<Map<String, dynamic>>> _fieldWorkersFuture;
  late Future<List<Map<String, dynamic>>> _attendanceRecordsFuture;

  DateTime selectedDate = DateTime.now();
  String searchQuery = '';
  String statusFilter = 'All';
  String roleFilter = 'All';

  @override
  void initState() {
    super.initState();
    _isSidebarVisible = widget.initialSidebarVisible;
    _fieldWorkersFuture = _fetchFieldWorkers();
    _attendanceRecordsFuture = _fetchAttendanceRecords();
  }

  Future<List<Map<String, dynamic>>> _fetchFieldWorkers() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final projectId = authService.currentUser?['project_id'];

      if (projectId == null) return [];

      final response = await http.get(
        AppConfig.apiUri('field-workers/?project_id=$projectId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching field workers: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAttendanceRecords() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final projectId = authService.currentUser?['project_id'];

      if (projectId == null) return [];

      final dateStr =
          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
      final response = await http.get(
        AppConfig.apiUri(
          'attendance/?project_id=$projectId&attendance_date=$dateStr',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching attendance: $e');
      return [];
    }
  }

  Future<void> _saveAttendance(Map<String, dynamic> attendanceData) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final projectId = authService.currentUser?['project_id'];

      attendanceData['project'] = projectId;
      attendanceData['attendance_date'] =
          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

      // Check if attendance record exists
      final existingRecords = await http.get(
        AppConfig.apiUri(
          'attendance/?field_worker_id=${attendanceData['field_worker']}&attendance_date=${attendanceData['attendance_date']}',
        ),
      );

      if (existingRecords.statusCode == 200) {
        final List<dynamic> data = jsonDecode(existingRecords.body);
        if (data.isNotEmpty) {
          // Update existing
          final attendanceId = data[0]['attendance_id'];
          await http.put(
            AppConfig.apiUri('attendance/$attendanceId/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(attendanceData),
          );
        } else {
          // Create new
          await http.post(
            AppConfig.apiUri('attendance/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(attendanceData),
          );
        }
      }

      // Refresh attendance records
      setState(() {
        _attendanceRecordsFuture = _fetchAttendanceRecords();
      });
    } catch (e) {
      print('Error saving attendance: $e');
    }
  }

  void _navigateToPage(String page) {
    switch (page) {
      case 'Dashboard':
        context.go('/supervisor');
        break;
      case 'Worker Management':
        context.go('/supervisor/workers');
        break;
      case 'Attendance':
        return; // Already on attendance page
      case 'Daily Logs':
        context.go('/supervisor/daily-logs');
        break;
      case 'Task Progress':
        context.go('/supervisor/task-progress');
        break;
      case 'Reports':
        context.go('/supervisor/reports');
        break;
      case 'Inventory':
        context.go('/supervisor/inventory');
        break;
      default:
        return;
    }
  }

  final List<String> roles = [
    'All',
    'Mason',
    'Painter',
    'Electrician',
    'Carpenter',
  ];

  bool hasNotifications = true;

  List<Map<String, dynamic>> _filterAttendance(
    List<Map<String, dynamic>> allAttendance,
    List<Map<String, dynamic>> allWorkers,
  ) {
    final filtered = allAttendance.where((record) {
      final worker = allWorkers.firstWhere(
        (w) => w['fieldworker_id'] == record['field_worker'],
        orElse: () => {},
      );

      final fullName =
          '${worker['first_name'] ?? ''} ${worker['last_name'] ?? ''}'
              .toLowerCase();
      final matchesSearch =
          searchQuery.isEmpty || fullName.contains(searchQuery.toLowerCase());
      final matchesStatus =
          statusFilter == 'All' || record['status'] == statusFilter;
      final matchesRole = roleFilter == 'All' || worker['role'] == roleFilter;

      return matchesSearch && matchesStatus && matchesRole;
    }).toList();

    return filtered;
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'on_site':
        return const Color(0xFF757575);
      case 'on_break':
        return const Color(0xFFFF8F00);
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return 'No date';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '--';
    return time;
  }

  // ----------------------
  // UI BUILD
  // ----------------------
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isMobile =
        screenWidth <= 1024; // Treat tablet like mobile for compact layout

    return Scaffold(
      backgroundColor: neutral,
      body: Stack(
        children: [
          Row(
            children: [
              if (_isSidebarVisible && isDesktop)
                Sidebar(
                  activePage: "Attendance",
                  keepVisible: _isSidebarVisible,
                ),
              Expanded(
                child: Column(
                  children: [
                    // White header with slim blue line on the left (keeps Notification bell & AESTRA)
                    Container(
                      color: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 20,
                        vertical: isMobile ? 12 : 12,
                      ),
                      child: Row(
                        children: [
                          // Hamburger menu button (hidden on mobile)
                          if (!isMobile) ...[
                            IconButton(
                              icon: const Icon(
                                Icons.menu,
                                color: Color(0xFF0C1935),
                                size: 24,
                              ),
                              onPressed: () => setState(
                                () => _isSidebarVisible = !_isSidebarVisible,
                              ),
                              tooltip: 'Menu',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            width: isMobile ? 3 : 4,
                            height: isMobile ? 40 : 56,
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          SizedBox(width: isMobile ? 8 : 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Attendance',
                                  style: TextStyle(
                                    fontSize: isMobile ? 16 : 22,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0C1935),
                                  ),
                                ),
                                if (!isMobile) const SizedBox(height: 4),
                                if (!isMobile)
                                  Text(
                                    'Weekly overview • ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Notification bell and AESTRA
                          if (!isMobile) ...[
                            Stack(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    setState(() => hasNotifications = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Notifications opened (demo)',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_outlined,
                                      color: Color(0xFF0C1935),
                                    ),
                                  ),
                                ),
                                if (hasNotifications)
                                  Positioned(
                                    right: 6,
                                    top: 6,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6B6B),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'switch') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Switch account (demo)'),
                                    ),
                                  );
                                } else if (value == 'logout') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Logout (demo)'),
                                    ),
                                  );
                                }
                              },
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
                                            style: TextStyle(
                                              color: Color(0xFFFF6B6B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                          ] else
                            // Mobile: Just notification icon
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
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              onPressed: () {
                                setState(() => hasNotifications = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Notifications opened (demo)',
                                    ),
                                  ),
                                );
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: isMobile ? 4 : 8),

                    // Search, filters and actions - Responsive
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 20,
                      ),
                      child: Material(
                        elevation: 3,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 6 : 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: isMobile
                              ? Column(
                                  children: [
                                    // Search field on mobile
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            decoration: InputDecoration(
                                              hintText: 'Search...',
                                              hintStyle: const TextStyle(
                                                fontSize: 11,
                                              ),
                                              prefixIcon: const Icon(
                                                Icons.search,
                                                size: 16,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide.none,
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey[50],
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
                                            onChanged: (v) =>
                                                setState(() => searchQuery = v),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        // Date picker icon
                                        GestureDetector(
                                          onTap: () async {
                                            final DateTime? picked =
                                                await showDatePicker(
                                                  context: context,
                                                  initialDate: selectedDate,
                                                  firstDate: DateTime(2000),
                                                  lastDate: DateTime(2100),
                                                );
                                            if (picked != null)
                                              setState(
                                                () => selectedDate = picked,
                                              );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[50],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.calendar_today,
                                              color: primary,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        // Status filter dropdown
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[50],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: DropdownButton<String>(
                                            value: statusFilter,
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
                                            items:
                                                ['All', 'On Site', 'On Break']
                                                    .map(
                                                      (s) => DropdownMenuItem(
                                                        value: s,
                                                        child: Text(
                                                          s,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 11,
                                                              ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                            onChanged: (v) => setState(
                                              () => statusFilter = v ?? 'All',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // Action buttons on mobile (compact row)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: _showActionSelectionDialog,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF1396E9,
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: const [
                                                  Icon(
                                                    Icons.qr_code_scanner,
                                                    color: Color(0xFF1396E9),
                                                    size: 16,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'QR',
                                                    style: TextStyle(
                                                      color: Color(0xFF1396E9),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: InkWell(
                                            onTap: _showManualAttendanceDialog,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF16A085,
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: const [
                                                  Icon(
                                                    Icons.edit_calendar,
                                                    color: Color(0xFF16A085),
                                                    size: 16,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Manual',
                                                    style: TextStyle(
                                                      color: Color(0xFF16A085),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: InkWell(
                                            onTap: _showCashAdvanceDialog,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFFFFA726,
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: const [
                                                  Icon(
                                                    Icons.request_page,
                                                    color: Color(0xFFFFA726),
                                                    size: 16,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Cash',
                                                    style: TextStyle(
                                                      color: Color(0xFFFFA726),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    // Search box on desktop/tablet
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.search,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              decoration: const InputDecoration(
                                                hintText:
                                                    'Search by name or role',
                                                border: InputBorder.none,
                                              ),
                                              onChanged: (v) => setState(
                                                () => searchQuery = v,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          VerticalDivider(
                                            color: Colors.grey.shade200,
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () async {
                                              final DateTime? picked =
                                                  await showDatePicker(
                                                    context: context,
                                                    initialDate: selectedDate,
                                                    firstDate: DateTime(2000),
                                                    lastDate: DateTime(2100),
                                                  );
                                              if (picked != null)
                                                setState(
                                                  () => selectedDate = picked,
                                                );
                                            },
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today,
                                                  color: primary,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                                                  style: TextStyle(
                                                    color: Colors.grey[800],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Status filter chips on desktop/tablet
                                    Expanded(
                                      flex: 2,
                                      child: Wrap(
                                        spacing: 8,
                                        children: ['All', 'On Site', 'On Break']
                                            .map((s) {
                                              final sel = statusFilter == s;
                                              return ChoiceChip(
                                                label: Text(
                                                  s,
                                                  style: TextStyle(
                                                    color: sel
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                                ),
                                                selected: sel,
                                                selectedColor: primary,
                                                backgroundColor:
                                                    Colors.grey[100],
                                                onSelected: (_) => setState(
                                                  () => statusFilter = s,
                                                ),
                                              );
                                            })
                                            .toList(),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Actions on desktop/tablet
                                    Row(
                                      children: [
                                        Tooltip(
                                          message: 'Scan QR',
                                          child: InkWell(
                                            onTap: _showActionSelectionDialog,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black12,
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.qr_code_scanner,
                                                color: Color(0xFF1396E9),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Tooltip(
                                          message: 'Manual Entry',
                                          child: InkWell(
                                            onTap: _showManualAttendanceDialog,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black12,
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.edit_calendar,
                                                color: Color(0xFF16A085),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Tooltip(
                                          message: 'Cash Advance',
                                          child: InkWell(
                                            onTap: _showCashAdvanceDialog,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black12,
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.request_page,
                                                color: Color(0xFFFFA726),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                primary,
                                                primary.withOpacity(0.85),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 8,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              onTap: () =>
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Export (demo)',
                                                      ),
                                                    ),
                                                  ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10,
                                                    ),
                                                child: Row(
                                                  children: const [
                                                    Icon(
                                                      Icons.download,
                                                      color: Colors.white,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Export',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),

                    SizedBox(height: isMobile ? 8 : 16),

                    // Attendance list - Responsive
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 20,
                        ),
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: _attendanceRecordsFuture,
                          builder: (context, attendanceSnapshot) {
                            return FutureBuilder<List<Map<String, dynamic>>>(
                              future: _fieldWorkersFuture,
                              builder: (context, workersSnapshot) {
                                if (attendanceSnapshot.connectionState ==
                                        ConnectionState.waiting ||
                                    workersSnapshot.connectionState ==
                                        ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                final attendanceRecords =
                                    attendanceSnapshot.data ?? [];
                                final fieldWorkers = workersSnapshot.data ?? [];
                                final filteredRecords = _filterAttendance(
                                  attendanceRecords,
                                  fieldWorkers,
                                );

                                if (filteredRecords.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'No records',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  );
                                }

                                return screenWidth <= 600
                                    ? _buildMobileAttendanceList(
                                        filteredRecords,
                                        fieldWorkers,
                                      )
                                    : _buildDesktopAttendanceTable(
                                        filteredRecords,
                                        fieldWorkers,
                                      );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 8 : 12),
                  ],
                ),
              ),
            ],
          ),
          // Overlay sidebar for tablet only
          if (_isSidebarVisible && !isDesktop && !isMobile)
            GestureDetector(
              onTap: () => setState(() => _isSidebarVisible = false),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          if (_isSidebarVisible && !isDesktop && !isMobile)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Sidebar(
                activePage: "Attendance",
                keepVisible: _isSidebarVisible,
              ),
            ),
        ],
      ),
      // Bottom navigation bar for mobile only
      bottomNavigationBar: isMobile ? _buildBottomNavBar() : null,
    );
  }

  Widget _buildDesktopAttendanceTable(
    List<Map<String, dynamic>> filteredRecords,
    List<Map<String, dynamic>> fieldWorkers,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: primary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _buildHeaderCell('Worker', flex: 3),
                _buildHeaderCell('Date', flex: 2),
                _buildHeaderCell('Check In', flex: 2),
                _buildHeaderCell('Check Out', flex: 2),
                _buildHeaderCell('Status', flex: 2),
                _buildHeaderCell('Actions', flex: 1),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: filteredRecords.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final record = filteredRecords[index];
                final worker = fieldWorkers.firstWhere(
                  (w) => w['fieldworker_id'] == record['field_worker'],
                  orElse: () => {'first_name': 'Unknown', 'last_name': ''},
                );
                final workerName =
                    '${worker['first_name']} ${worker['last_name']}';
                final statusColor = _statusColor(record['status'] ?? 'absent');

                return InkWell(
                  onTap: () => _showEditAttendanceDialog(record, worker),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            workerName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(record['attendance_date'] ?? '—'),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(record['check_in_time'] ?? '—'),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(record['check_out_time'] ?? '—'),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              (record['status'] ?? 'absent').replaceAll(
                                '_',
                                ' ',
                              ),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') {
                                _showEditAttendanceDialog(record, worker);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 16),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                            ],
                            icon: const Icon(Icons.more_vert, size: 18),
                            padding: EdgeInsets.zero,
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
                _buildNavItem(Icons.check_circle, 'Attendance', true),
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

  // Mobile card-based list
  Widget _buildMobileAttendanceList(
    List<Map<String, dynamic>> filteredRecords,
    List<Map<String, dynamic>> fieldWorkers,
  ) {
    return ListView.builder(
      itemCount: filteredRecords.length,
      itemBuilder: (context, index) {
        final record = filteredRecords[index];
        final worker = fieldWorkers.firstWhere(
          (w) => w['fieldworker_id'] == record['field_worker'],
          orElse: () => {
            'first_name': 'Unknown',
            'last_name': '',
            'role': 'N/A',
          },
        );
        final workerName = '${worker['first_name']} ${worker['last_name']}';
        final initials = workerName
            .split(' ')
            .map((s) => s.isNotEmpty ? s[0] : '')
            .take(2)
            .join();
        final statusColor = _statusColor(record['status'] ?? 'absent');

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showEditAttendanceDialog(record, worker),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: primary.withOpacity(0.12),
                        child: Text(
                          initials,
                          style: TextStyle(
                            color: primary,
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
                              workerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              worker['role'] ?? 'N/A',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
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
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          (record['status'] ?? 'absent').replaceAll('_', ' '),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // Details rows
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(record['attendance_date'] as String?),
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      ),
                      const Spacer(),
                      Icon(Icons.login, size: 14, color: Colors.green[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(record['check_in_time'] as String?),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.logout, size: 14, color: Colors.red[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(record['check_out_time'] as String?),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Action button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showEditAttendanceDialog(record, worker),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Attendance'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: BorderSide(color: primary),
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

  // small stat card
  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- DIALOGS (kept from previous implementation, unchanged) ----------

  Color _getActionColor(String action) {
    switch (action) {
      case 'Time In':
        return const Color(0xFFFF6F00);
      case 'Time Out':
        return const Color(0xFF757575);
      case 'Break In':
        return const Color(0xFFFF8F00);
      case 'Break Out':
        return const Color(0xFFBDBDBD);
      default:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'Time In':
        return Icons.login;
      case 'Time Out':
        return Icons.logout;
      case 'Break In':
        return Icons.play_arrow;
      case 'Break Out':
        return Icons.pause;
      default:
        return Icons.access_time;
    }
  }

  void _showActionSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(0),
        content: Container(
          width: 380,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade50, Colors.indigo.shade50],
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primary, Colors.blue.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Action',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Choose attendance action to scan',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildActionButton(context, 'Time In'),
                      const SizedBox(height: 12),
                      _buildActionButton(context, 'Time Out'),
                      const SizedBox(height: 12),
                      _buildActionButton(context, 'Break In'),
                      const SizedBox(height: 12),
                      _buildActionButton(context, 'Break Out'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const SizedBox(
                      width: double.infinity,
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String action) {
    final color = _getActionColor(action);
    final icon = _getActionIcon(action);

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _showQRScannerDialog(action);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                action,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  void _showQRScannerDialog(String action) {
    final color = _getActionColor(action);
    final MobileScannerController controller = MobileScannerController();
    bool isScanned = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(0),
        backgroundColor: Colors.transparent,
        content: Container(
          width: 400,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getActionIcon(action),
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              action,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Scan worker QR code',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Camera Scanner
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color, width: 3),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: MobileScanner(
                          controller: controller,
                          onDetect: (capture) {
                            if (!isScanned) {
                              isScanned = true;
                              final List<Barcode> barcodes = capture.barcodes;
                              for (final barcode in barcodes) {
                                final String? code = barcode.rawValue;
                                if (code != null) {
                                  controller.stop();
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '✓ $action recorded for: $code',
                                      ),
                                      backgroundColor: color,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                  // Here you would typically save the attendance record
                                  break;
                                }
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info,
                                  color: Colors.blue.shade600,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Position the QR code within the frame',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.blue.shade600,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Camera will scan automatically',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
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
                ),
                // Cancel button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        controller.stop();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      // Ensure controller is disposed when dialog closes
      controller.dispose();
    });
  }

  void _showManualAttendanceDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          String? selectedWorkerId;
          String checkInTime = '';
          String checkOutTime = '';
          String selectedStatus = 'on_site';

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text('Add Attendance'),
            content: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchFieldWorkers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.isEmpty)
                  return const Text('No workers found');

                final workers = snapshot.data!;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Worker',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: selectedWorkerId,
                        hint: const Text('Select worker'),
                        underline: const SizedBox(),
                        isExpanded: true,
                        items: workers
                            .map(
                              (w) => DropdownMenuItem<String>(
                                value: w['field_worker_id'].toString(),
                                child: Text(
                                  '${w['first_name']} ${w['last_name']} - ${w['role']}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => selectedWorkerId = val),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: selectedStatus,
                        underline: const SizedBox(),
                        isExpanded: true,
                        items: ['on_site', 'on_break', 'absent']
                            .map(
                              (status) => DropdownMenuItem<String>(
                                value: status,
                                child: Text(status.replaceAll('_', ' ')),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => selectedStatus = val!),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Check In',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: '07:30',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (v) => checkInTime = v,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Check Out',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: '17:00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (v) => checkOutTime = v,
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedWorkerId != null
                    ? () {
                        final attendanceData = {
                          'field_worker': int.parse(selectedWorkerId!),
                          'status': selectedStatus,
                          'check_in_time': checkInTime.isNotEmpty
                              ? checkInTime
                              : null,
                          'check_out_time': checkOutTime.isNotEmpty
                              ? checkOutTime
                              : null,
                        };
                        _saveAttendance(attendanceData);
                        Navigator.pop(context);
                      }
                    : null,
                style: ElevatedButton.styleFrom(backgroundColor: primary),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCashAdvanceDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          String? selectedWorkerId;
          String amount = '';
          String deductionPerSalary = '';

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text('Cash Advance Request'),
            content: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchFieldWorkers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.isEmpty)
                  return const Text('No workers found');

                final workers = snapshot.data!;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Worker',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: selectedWorkerId,
                        hint: const Text('Select worker'),
                        underline: const SizedBox(),
                        isExpanded: true,
                        items: workers
                            .map(
                              (w) => DropdownMenuItem<String>(
                                value: w['field_worker_id'].toString(),
                                child: Text(
                                  '${w['first_name']} ${w['last_name']} - ${w['role']}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => selectedWorkerId = val),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Amount (PHP)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Enter advance amount',
                        prefixText: '₱ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => amount = val,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Deduction per salary (PHP)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'How much to deduct every salary',
                        prefixText: '₱ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => deductionPerSalary = val,
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed:
                    selectedWorkerId != null &&
                        amount.isNotEmpty &&
                        deductionPerSalary.isNotEmpty
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cash advance request submitted'),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    : null,
                style: ElevatedButton.styleFrom(backgroundColor: primary),
                child: const Text('Submit Request'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditAttendanceDialog(
    Map<String, dynamic> record,
    Map<String, dynamic> worker,
  ) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) {
          String selectedStatus = record["status"] ?? 'absent';
          String checkIn = record['check_in_time'] ?? '';
          String checkOut = record['check_out_time'] ?? '';

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text('Edit Attendance'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Worker: ${worker['first_name']} ${worker['last_name']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: selectedStatus,
                    underline: const SizedBox(),
                    isExpanded: true,
                    items: ['on_site', 'on_break', 'absent']
                        .map(
                          (status) => DropdownMenuItem<String>(
                            value: status,
                            child: Text(status.replaceAll('_', ' ')),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        dialogSetState(() => selectedStatus = val!),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Check In',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    hintText: '07:30',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (v) => checkIn = v,
                  controller: TextEditingController(text: checkIn),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Check Out',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    hintText: '17:00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (v) => checkOut = v,
                  controller: TextEditingController(text: checkOut),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final attendanceData = {
                    'field_worker': record['field_worker'],
                    'status': selectedStatus,
                    'check_in_time': checkIn.isNotEmpty ? checkIn : null,
                    'check_out_time': checkOut.isNotEmpty ? checkOut : null,
                  };
                  _saveAttendance(attendanceData);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: primary),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
