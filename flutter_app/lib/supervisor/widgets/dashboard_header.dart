import 'package:flutter/material.dart';

class DashboardHeader extends StatefulWidget {
  const DashboardHeader({super.key});

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader> {
  bool hasNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Left side - Dashboard title
          const Text(
            "Dashboard",
            style: TextStyle(
              color: Color(0xFF0C1935),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),

          // Right side - Notification bell + AESTRA
          Row(
            children: [
              // Notification bell with badge
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    // TODO: Implement notification functionality
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

              // AESTRA logo + text (clickable dropdown)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'switch') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Switch Account clicked')),
                    );
                  } else if (value == 'logout') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logout clicked')),
                    );
                  }
                },
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
          ),
        ],
      ),
    );
  }
}