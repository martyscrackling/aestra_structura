import 'package:flutter/material.dart';
import 'dashboard_page.dart';

void main() {
  runApp(const PMApp());
}

class PMApp extends StatelessWidget {
  const PMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const PMDashboardPage(),
    );
  }
}
