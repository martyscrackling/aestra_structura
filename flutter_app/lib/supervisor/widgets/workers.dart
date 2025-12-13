import 'package:flutter/material.dart';

class Workers extends StatelessWidget {
  const Workers({super.key});

  final List<Map<String, dynamic>> workers = const [
    {"role": "Painter", "count": 5, "icon": Icons.format_paint},
    {"role": "Electrician", "count": 3, "icon": Icons.electrical_services},
    {"role": "Plumber", "count": 2, "icon": Icons.plumbing},
    {"role": "Carpenter", "count": 4, "icon": Icons.handyman},
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.transparent, // make the card (container behind boxes) transparent
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Active Workers",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: workers.map(
                (worker) => Container(
                  width: 120, // made box a bit bigger
                  padding: const EdgeInsets.all(16), // increased padding
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 252, 252, 252), // inner boxes keep subtle orange background
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      // subtle shadow to lift the icon box from the background
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        worker["icon"],
                        size: 36, // slightly larger icon
                        color: const Color(0xFFFF6B2C), // icon is orange
                      ),
                      const SizedBox(height: 8),
                      Text(
                        worker["role"],
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        worker["count"].toString(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
