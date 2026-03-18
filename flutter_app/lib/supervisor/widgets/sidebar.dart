import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Import your pages
import '../dashboard_page.dart';
import '../all_projects.dart';
import '../workers_management.dart';
import '../attendance_page.dart';
import '../task_progress.dart';
import '../reports.dart';
import '../inventory.dart';

class Sidebar extends StatefulWidget {
  final String activePage;
  final bool? keepVisible;

  const Sidebar({super.key, this.activePage = "Dashboard", this.keepVisible});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  String? hoveredItem;

  // Navigation function
  void navigateToPage(String label) {
    if (label == widget.activePage) {
      return;
    }

    // Close drawer/sidebar on navigation
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    switch (label) {
      case "Dashboard":
        context.go('/supervisor');
        break;
      case "Projects":
        context.go('/supervisor/projects');
        break;
      case "Worker Management":
        context.go('/supervisor/workers');
        break;
      case "Attendance":
        context.go('/supervisor/attendance');
        break;
      case "Task Progress":
        context.go('/supervisor/task-progress');
        break;
      case "Reports":
        context.go('/supervisor/reports');
        break;
      case "Inventory":
        context.go('/supervisor/inventory');
        break;
      default:
        context.go('/supervisor');
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      {"label": "Dashboard", "icon": Icons.dashboard},
      {"label": "Projects", "icon": Icons.folder_open},
      {"label": "Worker Management", "icon": Icons.people},
      {"label": "Attendance", "icon": Icons.check_circle},
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
      padding: EdgeInsets.symmetric(
        vertical: verticalPadding,
        horizontal: horizontalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo + App Name
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                ),
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
                  padding: const EdgeInsets.symmetric(
                    vertical: tileVerticalPadding,
                  ),
                  child: MouseRegion(
                    onEnter: (_) =>
                        setState(() => hoveredItem = item["label"] as String),
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                        ),
                        leading: Icon(
                          item["icon"] as IconData,
                          color: isActive
                              ? const Color(0xFF1396E9)
                              : Colors.white70,
                          size: iconSize,
                        ),
                        title: Text(
                          item["label"] as String,
                          style: TextStyle(
                            color: isActive
                                ? const Color(0xFF1396E9)
                                : Colors.white70,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w400,
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
                  color: hoveredItem == "Settings"
                      ? Colors.white10
                      : Colors.transparent,
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
