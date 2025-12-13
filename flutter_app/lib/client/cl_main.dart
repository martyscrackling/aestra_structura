import 'package:flutter/material.dart';
import 'cl_dashboard.dart';

void main() {
  runApp(const ClApp());
}

class ClApp extends StatelessWidget {
  const ClApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const ClDashboardPage(),
    );
  }
}
