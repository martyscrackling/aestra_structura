import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';

class WorkerManagementPage extends StatefulWidget {
  const WorkerManagementPage({super.key});

  @override
  State<WorkerManagementPage> createState() => _WorkerManagementPageState();
}

class _WorkerManagementPageState extends State<WorkerManagementPage> {
  final List<Map<String, dynamic>> allWorkers = [
    {
      "name": "John Doe",
      "role": "Painter",
      "status": "Active",
      "address": "123 Main St, Divisoria, Zamboanga City",
      "phone": "0917-123-4567",
      "dateHired": "2022-05-01",
      "shift": "8:00 AM - 5:00 PM",
      "payrate": "₱500/day"
    },
    {
      "name": "Jane Smith",
      "role": "Electrician",
      "status": "Inactive",
      "address": "456 Oak St, Divisoria, Zamboanga City",
      "phone": "0917-987-6543",
      "dateHired": "2023-01-10",
      "shift": "9:00 AM - 6:00 PM",
      "payrate": "₱550/day"
    },
    {
      "name": "Bob Johnson",
      "role": "Plumber",
      "status": "Active",
      "address": "789 Pine St, Divisoria, Zamboanga City",
      "phone": "0917-555-1212",
      "dateHired": "2021-09-15",
      "shift": "8:00 AM - 5:00 PM",
      "payrate": "₱600/day"
    },
    {
      "name": "Alice Brown",
      "role": "Carpenter",
      "status": "Active",
      "address": "321 Maple St, Divisoria, Zamboanga City",
      "phone": "0917-111-2222",
      "dateHired": "2020-11-20",
      "shift": "7:00 AM - 4:00 PM",
      "payrate": "₱520/day"
    },
  ];

  String searchQuery = '';
  String selectedRole = 'All';
  String sortBy = 'Name A-Z';

  final List<String> roles = ['All', 'Painter', 'Electrician', 'Plumber', 'Carpenter'];
  final List<String> sortOptions = ['Name A-Z', 'Name Z-A', 'Recently Hired'];

  List<Map<String, dynamic>> get filteredWorkers {
    final filtered = allWorkers.where((worker) {
      final matchesSearch =
          worker['name'].toLowerCase().contains(searchQuery.toLowerCase());
      final matchesRole = selectedRole == 'All' || worker['role'] == selectedRole;
      return matchesSearch && matchesRole;
    }).toList();

    if (sortBy == 'Name A-Z') {
      filtered.sort((a, b) => a['name'].compareTo(b['name']));
    } else if (sortBy == 'Name Z-A') {
      filtered.sort((a, b) => b['name'].compareTo(a['name']));
    } else if (sortBy == 'Recently Hired') {
      filtered.sort((a, b) => b['dateHired'].compareTo(a['dateHired']));
    }
    return filtered;
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "Active":
        return Colors.green;
      case "Inactive":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Painter':
        return const Color(0xFFFF6B2C);
      case 'Electrician':
        return const Color(0xFF1396E9);
      case 'Plumber':
        return const Color(0xFF8E44AD);
      case 'Carpenter':
        return const Color(0xFF16A085);
      default:
        return Colors.blueGrey;
    }
  }

  // ---------------------------
  // Worker detail modal (keeps previous functionality)
  // ---------------------------
  void _showWorkerDetailModal(BuildContext context, Map<String, dynamic> worker) {
    showDialog(
      context: context,
      builder: (context) {
        final roleColor = _roleColor(worker["role"]);
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                              decoration: BoxDecoration(color: roleColor.withOpacity(0.95), borderRadius: BorderRadius.circular(6)),
                            ),
                            const SizedBox(width: 12),
                            const Text("Worker Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
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
                            child: Icon(Icons.person, size: 56, color: roleColor),
                          ),
                          const SizedBox(height: 14),
                          Text(worker["name"], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: roleColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                            child: Text(worker["role"], style: TextStyle(color: roleColor, fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Details
                    const Text("Personal Information", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _buildDetailRow("Phone", worker["phone"]),
                    _buildDetailRow("Address", worker["address"]),
                    _buildDetailRow("Date Hired", worker["dateHired"]),
                    const SizedBox(height: 12),
                    const Text("Work Details", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _buildDetailRow("Shift Schedule", worker["shift"]),
                    _buildDetailRow("Payrate", worker["payrate"]),
                    _buildDetailRowWithStatus("Status", worker["status"], getStatusColor(worker["status"])),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('QR Code for ${worker["name"]} downloaded!')));
                            },
                            icon: const Icon(Icons.qr_code),
                            label: const Text("Download QR"),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: Color(0xFF1396E9))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check),
                          label: const Text("Close"),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1396E9), padding: const EdgeInsets.symmetric(vertical: 14)),
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
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      ]),
    );
  }

  Widget _buildDetailRowWithStatus(String label, String value, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600, fontSize: 13)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Text(value, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12))),
      ]),
    );
  }

  bool hasNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          const Sidebar(activePage: "Worker Management"),
          Expanded(
            child: Column(
              children: [
                // White header with blue left accent (keeps Notification bell & AESTRA)
                const WorkersHeader(),

                const SizedBox(height: 8),

                // Search & filter creative card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          // Search
                          Expanded(
                            flex: 3,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search workers by name, phone or role',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onChanged: (v) => setState(() => searchQuery = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // role chips
                          Expanded(
                            flex: 4,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: roles.map((r) {
                                  final sel = selectedRole == r;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(r, style: TextStyle(color: sel ? Colors.white : Colors.black87)),
                                      selected: sel,
                                      selectedColor: const Color(0xFF1396E9),
                                      backgroundColor: Colors.grey[100],
                                      onSelected: (_) => setState(() => selectedRole = r),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // sort dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                            child: DropdownButton<String>(
                              value: sortBy,
                              underline: const SizedBox(),
                              items: sortOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => setState(() => sortBy = v ?? sortBy),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Add button removed (managed by PM/backend)
                          const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Workers list (creative cards)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: filteredWorkers.isEmpty
                        ? Center(child: Text('No workers found', style: TextStyle(color: Colors.grey[700])))
                        : ListView.builder(
                            itemCount: filteredWorkers.length,
                            itemBuilder: (context, index) {
                              final worker = filteredWorkers[index];
                              final initials = worker['name'].toString().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join();
                              final roleColor = _roleColor(worker['role']);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    // accent bar
                                    Container(width: 6, height: 120, decoration: BoxDecoration(color: roleColor.withOpacity(0.18), borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)))),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Card(
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              CircleAvatar(radius: 36, backgroundColor: roleColor.withOpacity(0.16), child: Text(initials, style: TextStyle(color: roleColor, fontSize: 18, fontWeight: FontWeight.w800))),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                  Row(children: [
                                                    Expanded(child: Text(worker['name'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                                                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Text(worker['role'], style: const TextStyle(fontSize: 12, color: Colors.grey))),
                                                  ]),
                                                  const SizedBox(height: 6),
                                                  Text(worker['address'], style: TextStyle(color: Colors.grey[700], fontSize: 12), overflow: TextOverflow.ellipsis),
                                                  const SizedBox(height: 8),
                                                  Row(children: [
                                                    Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                                                    const SizedBox(width: 6),
                                                    Text('Hired ${worker["dateHired"]}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                                    const SizedBox(width: 12),
                                                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: getStatusColor(worker['status']).withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text(worker['status'], style: TextStyle(color: getStatusColor(worker['status']), fontWeight: FontWeight.w700, fontSize: 12))),
                                                  ]),
                                                ]),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(children: [
                                                IconButton(icon: const Icon(Icons.remove_red_eye_outlined), color: Colors.blueGrey, onPressed: () => _showWorkerDetailModal(context, worker), tooltip: 'View'),
                                                PopupMenuButton<String>(onSelected: (v) { if (v == 'toggle') { setState(() { worker['status'] = worker['status'] == 'Active' ? 'Inactive' : 'Active'; }); }}, itemBuilder: (_) => [PopupMenuItem(value: 'toggle', child: Text(worker['status'] == 'Active' ? 'Set Inactive' : 'Set Active')), const PopupMenuItem(value: 'remove', child: Text('Remove (demo)'))], child: const Icon(Icons.more_vert)),
                                              ]),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
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
}

// ---------------------------
// Header
// ---------------------------
class WorkersHeader extends StatefulWidget {
  const WorkersHeader({super.key});

  @override
  State<WorkersHeader> createState() => _WorkersHeaderState();
}

class _WorkersHeaderState extends State<WorkersHeader> {
  bool hasNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // keep header white
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // slim blue line in the left corner
          Container(width: 4, height: 56, decoration: BoxDecoration(color: const Color(0xFF1396E9), borderRadius: BorderRadius.circular(6))),
          const SizedBox(width: 12),
          // Title + subtitle (no Super Highway text)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Workers",
                style: TextStyle(
                  color: Color(0xFF0C1935),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Manage your workforce",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Right side - Notifications & AESTRA
          Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    setState(() => hasNotifications = false);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications opened (demo)')));
                  },
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.notifications_outlined,
                            color: Color(0xFF0C1935), size: 24),
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
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'switch',
                    height: 48,
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz, size: 18, color: Color(0xFF0C1935)),
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
                        Icon(Icons.logout, size: 18, color: Color(0xFFFF6B6B)),
                        SizedBox(width: 12),
                        Text('Logout', style: TextStyle(color: Color(0xFFFF6B6B))),
                      ],
                    ),
                  ),
                ],
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                  fontWeight: FontWeight.w700),
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
          ),
        ],
      ),
    );
  }
}
