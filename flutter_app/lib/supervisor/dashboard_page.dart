import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/active_project.dart';
import 'widgets/tasks.dart'; 
import 'widgets/workers.dart';
import 'widgets/calendar_panel.dart';

class SupervisorDashboardPage extends StatelessWidget {
  const SupervisorDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          // Sidebar stays fixed on the left
         const Sidebar(activePage: "Dashboard"),

          // Right area (header fixed, content scrollable)
          Expanded(
            child: Column(
              children: [
                // Header fixed at top of right area
                const DashboardHeader(),

                // Scrollable content below header while sidebar stays put
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Main content area (left/middle)
                              Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const ActiveProject(),
                                      const SizedBox(height: 20),
                                       const Tasks(),
                                        const SizedBox(height: 20),
                                        const Workers(),    
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                ),
                              ),

                              // Right-side calendar panel
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    children: [
                                      const CalendarPanel(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}