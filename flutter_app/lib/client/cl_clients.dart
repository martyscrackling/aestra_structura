import 'package:flutter/material.dart';
import 'cl_dashboard.dart';

/// Backwards-compatible alias page so existing references to
/// `ClClientsPage` keep working. It simply forwards to `ClDashboardPage`.
class ClClientsPage extends StatelessWidget {
  const ClClientsPage({super.key});

  @override
  Widget build(BuildContext context) => const ClDashboardPage();
}
