import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Sidebar extends StatefulWidget {
  final String currentPage;

  const Sidebar({super.key, this.currentPage = 'Dashboard'});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  String? hoveredItem;

  void _navigateToPage(BuildContext context, String label) {
    switch (label) {
      case 'Dashboard':
        context.go('/dashboard');
        break;
      case 'Projects':
        context.go('/projects');
        break;
      case 'Workforce':
        context.go('/workforce');
        break;
      case 'Clients':
        context.go('/clients');
        break;
      case 'Reports':
        context.go('/reports');
        break;
      case 'Inventory':
        context.go('/inventory');
        break;
      case 'Settings':
        context.go('/settings');
        break;
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define menu items with labels and icons
    final menuItems = [
      {"label": "Dashboard", "icon": Icons.dashboard},
      {"label": "Projects", "icon": Icons.folder},
      {"label": "Workforce", "icon": Icons.people},
      {"label": "Clients", "icon": Icons.person},
      {"label": "Inventory", "icon": Icons.inventory_2_outlined},
      {"label": "Reports", "icon": Icons.insert_chart},
    ];

    // more compact sizes
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
          // Logo placeholder + app name
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

          // Scrollable menu
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: menuItems.map((item) {
                bool isActive = item["label"] == widget.currentPage;
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
                        onTap: () {
                          _navigateToPage(context, item["label"] as String);
                        },
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Divider and settings pinned at bottom
          const Divider(color: Colors.white12),
          Align(
            alignment: Alignment.centerLeft,
            child: MouseRegion(
              onEnter: (_) => setState(() => hoveredItem = "Settings"),
              onExit: (_) => setState(() => hoveredItem = null),
              child: GestureDetector(
                onTap: () => _navigateToPage(context, 'Settings'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: widget.currentPage == 'Settings'
                        ? const Color(0xFFE8F3FF)
                        : hoveredItem == "Settings"
                        ? Colors.white10
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.settings,
                        color: widget.currentPage == 'Settings'
                            ? const Color(0xFF1396E9)
                            : Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Settings',
                        style: TextStyle(
                          color: widget.currentPage == 'Settings'
                              ? const Color(0xFF1396E9)
                              : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
    );
  }
}
