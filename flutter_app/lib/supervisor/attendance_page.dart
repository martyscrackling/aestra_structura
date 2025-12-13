import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final Color primary = const Color(0xFF1396E9);
  final Color primaryLight = const Color(0xFFEAF6FF);
  final Color neutral = const Color(0xFFF4F6F9);

  // Updated records: include checkIn/checkOut/status
  final List<Map<String, String>> attendanceRecords = [
    {
      "name": "John Doe",
      "role": "Mason",
      "date": "2025-11-18",
      "checkIn": "07:30 AM",
      "checkOut": "05:00 PM",
      "status": "On Site",
    },
    {
      "name": "Jane Smith",
      "role": "Welder",
      "date": "2025-11-18",
      "checkIn": "08:00 AM",
      "checkOut": "12:00 PM",
      "status": "On Break",
    },
    {
      "name": "Bob Johnson",
      "role": "Electrician",
      "date": "2025-11-18",
      "checkIn": "07:45 AM",
      "checkOut": "—",
      "status": "On Site",
    },
    {
      "name": "Alice Brown",
      "role": "Carpenter",
      "date": "2025-11-18",
      "checkIn": "—",
      "checkOut": "—",
      "status": "On Break",
    },
  ];

  DateTime selectedDate = DateTime.now();
  String searchQuery = '';
  String statusFilter = 'All';
  String roleFilter = 'All';
  bool hasNotifications = true;

  List<Map<String, String>> get filteredRecords {
    return attendanceRecords.where((r) {
      final matchesSearch = searchQuery.isEmpty || r['name']!.toLowerCase().contains(searchQuery.toLowerCase()) || r['role']!.toLowerCase().contains(searchQuery.toLowerCase());
      final matchesStatus = statusFilter == 'All' || r['status'] == statusFilter;
      final matchesRole = roleFilter == 'All' || r['role'] == roleFilter;
      return matchesSearch && matchesStatus && matchesRole;
    }).toList();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'On Site':
        return const Color(0xFF6CBA63);
      case 'On Break':
        return const Color(0xFFFFC900);
      default:
        return Colors.grey;
    }
  }

  // ----------------------
  // UI BUILD
  // ----------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: neutral,
      body: Row(
        children: [
          const Sidebar(activePage: "Attendance"),
          Expanded(
            child: Column(
              children: [
                // White header with slim blue line on the left (keeps Notification bell & AESTRA)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(width: 4, height: 56, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(6))),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Attendance', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0C1935))),
                          const SizedBox(height: 4),
                          Text('Weekly overview • ${selectedDate.year}-${selectedDate.month.toString().padLeft(2,'0')}-${selectedDate.day.toString().padLeft(2,'0')}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                        ],
                      ),
                      const Spacer(),

                      // Notification bell
                      Stack(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() => hasNotifications = false);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications opened (demo)')));
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.notifications_outlined, color: Color(0xFF0C1935)),
                            ),
                          ),
                          if (hasNotifications)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFFFF6B6B), borderRadius: BorderRadius.circular(6))),
                            ),
                        ],
                      ),

                      const SizedBox(width: 12),

                      // AESTRA account (switch/logout)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'switch') {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Switch account (demo)')));
                          } else if (value == 'logout') {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logout (demo)')));
                          }
                        },
                        offset: const Offset(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(value: 'switch', height: 48, child: Row(children: [Icon(Icons.swap_horiz, size: 18, color: Color(0xFF0C1935)), SizedBox(width: 12), Text('Switch Account')])),
                          const PopupMenuDivider(height: 1),
                          const PopupMenuItem<String>(value: 'logout', height: 48, child: Row(children: [Icon(Icons.logout, size: 18, color: Color(0xFFFF6B6B)), SizedBox(width: 12), Text('Logout', style: TextStyle(color: Color(0xFFFF6B6B)))])),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFE8D5F2), borderRadius: BorderRadius.circular(8)), child: const Center(child: Text("A", style: TextStyle(color: Color(0xFFB088D9), fontSize: 18, fontWeight: FontWeight.w700)))),
                              const SizedBox(width: 10),
                              const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text("AESTRA", style: TextStyle(color: Color(0xFF0C1935), fontSize: 13, fontWeight: FontWeight.w700)), Text("Supervisor", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w400))]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Search, filters and KPI row in a creative card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Search box
                      Expanded(
                        flex: 3,
                        child: Material(
                          elevation: 3,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                const Icon(Icons.search, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(hintText: 'Search by name or role', border: InputBorder.none),
                                    onChanged: (v) => setState(() => searchQuery = v),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                VerticalDivider(color: Colors.grey.shade200),
                                const SizedBox(width: 8),
                                // quick date picker
                                GestureDetector(
                                  onTap: () async {
                                    final DateTime? picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                                    if (picked != null) setState(() => selectedDate = picked);
                                  },
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today, color: primary),
                                      const SizedBox(width: 6),
                                      Text('${selectedDate.year}-${selectedDate.month.toString().padLeft(2,'0')}-${selectedDate.day.toString().padLeft(2,'0')}', style: TextStyle(color: Colors.grey[800])),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Status filter chips
                      Expanded(
                        flex: 2,
                        child: Wrap(
                          spacing: 8,
                          children: ['All', 'On Site', 'On Break'].map((s) {
                            final sel = statusFilter == s;
                            return ChoiceChip(
                              label: Text(s, style: TextStyle(color: sel ? Colors.white : Colors.black87)),
                              selected: sel,
                              selectedColor: primary,
                              backgroundColor: Colors.grey[100],
                              onSelected: (_) => setState(() => statusFilter = s),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Actions: QR Scan, Manual Entry, Cash Advance, Export
                      Row(
                        children: [
                          // QR Scanner
                          Tooltip(
                            message: 'Scan QR',
                            child: InkWell(
                              onTap: _showQRScannerDialog,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]),
                                child: const Icon(Icons.qr_code_scanner, color: Color(0xFF1396E9)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Manual attendance
                          Tooltip(
                            message: 'Manual Entry',
                            child: InkWell(
                              onTap: _showManualAttendanceDialog,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]),
                                child: const Icon(Icons.edit_calendar, color: Color(0xFF16A085)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Cash advance
                          Tooltip(
                            message: 'Cash Advance',
                            child: InkWell(
                              onTap: _showCashAdvanceDialog,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]),
                                child: const Icon(Icons.request_page, color: Color(0xFFFFA726)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Export
                          Container(
                            decoration: BoxDecoration(gradient: LinearGradient(colors: [primary, primary.withOpacity(0.85)]), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,4))]),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export (demo)'))),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(children: const [Icon(Icons.download, color: Colors.white), SizedBox(width: 8), Text('Export', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))]),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Stats cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _statCard('Workers Present', '${attendanceRecords.where((r) => r['status'] == 'On Site').length}', Icons.group, Colors.blueAccent),
                      const SizedBox(width: 12),
                      _statCard('On Break', '${attendanceRecords.where((r) => r['status'] == 'On Break').length}', Icons.coffee, Colors.orangeAccent),
                      const SizedBox(width: 12),
                      _statCard('Total Entries', '${attendanceRecords.length}', Icons.receipt_long, Colors.green),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Creative attendance list (cards with alternating accents)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: filteredRecords.isEmpty
                        ? Center(child: Text('No records', style: TextStyle(color: Colors.grey[700])))
                        : ListView.builder(
                            itemCount: filteredRecords.length,
                            itemBuilder: (context, index) {
                              final r = filteredRecords[index];
                              final initials = r['name']!.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join();
                              final accent = index.isEven ? Colors.indigo.shade50 : Colors.teal.shade50;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(10)),
                                          child: Center(child: Text(initials, style: TextStyle(color: index.isEven ? Colors.indigo : Colors.teal, fontWeight: FontWeight.w800))),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Row(children: [
                                              Expanded(child: Text(r['name']!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                                              const SizedBox(width: 8),
                                              Text(r['role']!, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
                                            ]),
                                            const SizedBox(height: 6),
                                            Row(children: [
                                              Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                                              const SizedBox(width: 6),
                                              Text(r['date']!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                              const SizedBox(width: 12),
                                              Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                                              const SizedBox(width: 6),
                                              Text('${r['checkIn']} • ${r['checkOut']}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                            ]),
                                          ]),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(color: _statusColor(r['status']!).withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                                              child: Text(r['status']!, style: TextStyle(color: _statusColor(r['status']!), fontWeight: FontWeight.w700)),
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: Color(0xFF1396E9)),
                                                  onPressed: () => _showEditAttendanceDialog(r),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                                PopupMenuButton<String>(
                                                  onSelected: (v) {
                                                    if (v == 'remove') {
                                                      setState(() {
                                                        attendanceRecords.removeAt(index);
                                                      });
                                                    }
                                                  },
                                                  itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Remove (demo)'))],
                                                  child: const Icon(Icons.more_vert),
                                                )
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // small stat card
  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,4))]),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            ]),
          ],
        ),
      ),
    );
  }

  // ---------- DIALOGS (kept from previous implementation, unchanged) ----------
  void _showQRScannerDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(0),
        content: Container(
          width: 400,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade50, Colors.indigo.shade50])),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, Colors.blue.shade700], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.qr_code_2, color: Colors.white, size: 28)),
                    const SizedBox(width: 12),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('QR Code Scanner', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)), SizedBox(height: 4), Text('Scan worker attendance', style: TextStyle(color: Colors.white70, fontSize: 12))])),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(width: 220, height: 220, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: primary, width: 2), boxShadow: [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 16, spreadRadius: 4)], color: Colors.white), child: Center(child: Icon(Icons.qr_code_2, size: 80, color: Colors.blue.shade300))),
                    const SizedBox(height: 20),
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)), child: Column(children: [Row(children: [Icon(Icons.info, color: Colors.blue.shade600, size: 18), const SizedBox(width: 8), Expanded(child: Text('Position the QR code within the frame', style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w500)))]), const SizedBox(height: 8), Row(children: [Icon(Icons.check_circle, color: Colors.blue.shade600, size: 18), const SizedBox(width: 8), Expanded(child: Text('Ensure proper lighting for better results', style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w500)))])]),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ QR Code scanned successfully!'), backgroundColor: Color(0xFF6CBA63))); }, icon: const Icon(Icons.check_circle, size: 18), label: const Text('Confirm Scan'), style: ElevatedButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualAttendanceDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        String selectedWorker = 'Select Worker';
        String checkInTime = '';
        String checkOutTime = '';
        String manualStatus = 'On Site';

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Manual Attendance Entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Worker', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: DropdownButton<String>(
                  value: selectedWorker,
                  underline: const SizedBox(),
                  isExpanded: true,
                  items: ['Select Worker', ...attendanceRecords.map((r) => r['name']!).toList()].map((w) => DropdownMenuItem<String>(value: w, child: Text(w))).toList(),
                  onChanged: (val) => setState(() => selectedWorker = val!),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: DropdownButton<String>(
                  value: manualStatus,
                  underline: const SizedBox(),
                  isExpanded: true,
                  items: ['On Site', 'On Break'].map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setState(() => manualStatus = val!),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Check In Time', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(decoration: InputDecoration(hintText: '07:30 AM', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true), onChanged: (val) => checkInTime = val),
              const SizedBox(height: 12),
              const Text('Check Out Time', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(decoration: InputDecoration(hintText: '05:00 PM', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true), onChanged: (val) => checkOutTime = val),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (selectedWorker != 'Select Worker') {
                  // update the record if exists, otherwise add
                  final idx = attendanceRecords.indexWhere((r) => r['name'] == selectedWorker);
                  final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                  if (idx >= 0) {
                    setState(() {
                      attendanceRecords[idx]['checkIn'] = checkInTime.isEmpty ? attendanceRecords[idx]['checkIn']! : checkInTime;
                      attendanceRecords[idx]['checkOut'] = checkOutTime.isEmpty ? attendanceRecords[idx]['checkOut']! : checkOutTime;
                      attendanceRecords[idx]['status'] = manualStatus;
                      attendanceRecords[idx]['date'] = dateStr;
                    });
                  } else {
                    setState(() {
                      attendanceRecords.add({
                        'name': selectedWorker,
                        'role': '',
                        'date': dateStr,
                        'checkIn': checkInTime,
                        'checkOut': checkOutTime,
                        'status': manualStatus,
                      });
                    });
                  }
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Manual entry saved for $selectedWorker')));
              },
              style: ElevatedButton.styleFrom(backgroundColor: primary),
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );
  }

  void _showCashAdvanceDialog() {
    String selectedWorker = 'Select Worker';
    String amount = '';
    String deductionPerSalary = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Cash Advance Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Worker', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: DropdownButton<String>(
                  value: selectedWorker,
                  underline: const SizedBox(),
                  isExpanded: true,
                  items: ['Select Worker', ...attendanceRecords.map((r) => r['name']!).toList()].map((w) => DropdownMenuItem<String>(value: w, child: Text(w))).toList(),
                  onChanged: (val) => setState(() => selectedWorker = val!),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Amount (PHP)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Enter advance amount',
                  prefixText: '₱ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) => amount = val,
              ),
              const SizedBox(height: 12),
              const Text('Deduction per salary (PHP)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: 'How much to deduct every salary',
                  prefixText: '₱ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) => deductionPerSalary = val,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange.shade600, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('This amount will be deducted from the worker\'s salary each pay period.', style: TextStyle(fontSize: 12, color: Colors.orange.shade700))),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      selectedWorker == 'Select Worker'
                          ? 'No worker selected'
                          : 'Advance ₱$amount for $selectedWorker submitted — deduct ₱$deductionPerSalary per salary',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726)),
              child: const Text('Approve'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAttendanceDialog(Map<String, String> record) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          String selectedStatus = record["status"]!;
          String selectedDateStr = record["date"]!;
          String checkIn = record['checkIn'] ?? '';
          String checkOut = record['checkOut'] ?? '';

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Edit Attendance'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Worker: ${record["name"]}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 12),
                const Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                  child: DropdownButton<String>(
                    value: selectedStatus,
                    underline: const SizedBox(),
                    isExpanded: true,
                    items: ['On Site', 'On Break'].map((status) => DropdownMenuItem<String>(value: status, child: Text(status))).toList(),
                    onChanged: (val) => setState(() => selectedStatus = val!),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Check In', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(decoration: InputDecoration(hintText: '07:30 AM', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), controller: TextEditingController(text: checkIn), onChanged: (v) => checkIn = v),
                const SizedBox(height: 12),
                const Text('Check Out', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(decoration: InputDecoration(hintText: '05:00 PM', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), controller: TextEditingController(text: checkOut), onChanged: (v) => checkOut = v),
                const SizedBox(height: 12),
                const Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse(selectedDateStr) ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                      builder: (BuildContext context, Widget? child) {
                        return Theme(data: ThemeData.light().copyWith(primaryColor: primary, highlightColor: primary, colorScheme: ColorScheme.light(primary: primary)), child: child!);
                      },
                    );
                    if (picked != null) setState(() => selectedDateStr = picked.toIso8601String().split('T')[0]);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Color(0xFF1396E9)),
                        const SizedBox(width: 8),
                        Text(selectedDateStr, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    record['status'] = selectedStatus;
                    record['checkIn'] = checkIn;
                    record['checkOut'] = checkOut;
                    record['date'] = selectedDateStr;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${record["name"]} attendance updated to $selectedStatus on $selectedDateStr')));
                },
                style: ElevatedButton.styleFrom(backgroundColor: primary),
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }
}
