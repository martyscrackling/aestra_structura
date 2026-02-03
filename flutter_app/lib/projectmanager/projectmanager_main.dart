import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'projects_page.dart';
import 'clients_page.dart';
import 'workforce_page.dart';
import 'inventory_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';

void main() {
  runApp(const PMApp());
}

class PMApp extends StatelessWidget {
  const PMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/dashboard',
      routes: {
        '/dashboard': (context) => const PMDashboardPage(),
        '/projects': (context) => const ProjectsPage(),
        '/clients': (context) => ClientsPage(),
        '/workforce': (context) => const WorkforcePage(),
        '/inventory': (context) => InventoryPage(),
        '/reports': (context) => ReportsPage(),
        '/settings': (context) => SettingsPage(),
      },
    );
  }
}
