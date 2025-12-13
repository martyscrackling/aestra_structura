import 'package:flutter/material.dart';
import 'dashboard_page.dart'; // Import your dashboard widget

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: true,
      home: const SupervisorDashboardPage(), // Your dashboard widget
    );
  }
}
