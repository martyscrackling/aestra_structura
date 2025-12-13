import 'package:flutter/material.dart';

// Import your pages
import '../dashboard_page.dart';
import '../workers_management.dart';
import '../attendance_page.dart';
import '../daily_logs.dart'; // added import for Daily Logs
import '../task_progress.dart'; // added import for Task Progress
import '../reports.dart'; // added import for Reports
import '../inventory.dart'; // add Inventory page import

class Sidebar extends StatefulWidget {
  final String activePage;

  const Sidebar({
    super.key,
    this.activePage = "Dashboard",
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  String? hoveredItem;

  // Navigation function
  void navigateToPage(String label) {
    Widget page;

    switch (label) {
      case "Dashboard":
        page = const SupervisorDashboardPage();
        break;
      case "Worker Management":
        page = const WorkerManagementPage();
        break;
      case "Attendance":
        page = const AttendancePage();
        break;
      case "Daily Logs":
        page = const DailyLogsPage(); // now navigates to DailyLogsPage
        break;
      case "Task Progress":
        page = const TaskProgressPage();
        break;
      case "Reports":
        page = const ReportsPage();
        break;
      case "Inventory":
        page = const InventoryPage();
        break;
      default:
        page = const SupervisorDashboardPage();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      {"label": "Dashboard", "icon": Icons.dashboard},
      {"label": "Worker Management", "icon": Icons.people},
      {"label": "Attendance", "icon": Icons.check_circle},
      {"label": "Daily Logs", "icon": Icons.list_alt},
      {"label": "Task Progress", "icon": Icons.show_chart},
      {"label": "Reports", "icon": Icons.file_copy},
      {"label": "Inventory", "icon": Icons.inventory},
    ];

    const double sidebarWidth = 190;
    const double iconSize = 16;
    const double fontSize = 12;
    const double tileVerticalPadding = 4;
    const double horizontalPadding = 12;
    const double verticalPadding = 16;

    return Container(
      width: sidebarWidth,
      color: const Color(0xFF0C1935),
      padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo + App Name
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
                child: Image.asset(
                  'assets/images/structuralogo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "STRUCTURA",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Menu List
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: menuItems.map((item) {
                bool isActive = item["label"] == widget.activePage;
                bool isHovered = hoveredItem == item["label"];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: tileVerticalPadding),
                  child: MouseRegion(
                    onEnter: (_) => setState(() => hoveredItem = item["label"] as String),
                    onExit: (_) => setState(() => hoveredItem = null),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFE8F3FF)
                            : isHovered
                                ? Colors.white10
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        dense: true,
                        minVerticalPadding: 0,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                        leading: Icon(
                          item["icon"] as IconData,
                          color: isActive ? const Color(0xFF1396E9) : Colors.white70,
                          size: iconSize,
                        ),
                        title: Text(
                          item["label"] as String,
                          style: TextStyle(
                            color: isActive ? const Color(0xFF1396E9) : Colors.white70,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                            fontSize: fontSize,
                          ),
                        ),
                        onTap: () => navigateToPage(item["label"] as String),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Settings button
          const Divider(color: Colors.white12),
          Align(
            alignment: Alignment.centerLeft,
            child: MouseRegion(
              onEnter: (_) => setState(() => hoveredItem = "Settings"),
              onExit: (_) => setState(() => hoveredItem = null),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: hoveredItem == "Settings" ? Colors.white10 : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  icon: const Icon(Icons.settings, color: Colors.white70),
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
