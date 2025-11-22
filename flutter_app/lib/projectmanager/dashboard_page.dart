import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/recent_projects.dart';
import 'widgets/activity_widget.dart';
import 'widgets/task_summary_widget.dart';
import 'widgets/task_today_widget.dart';
import 'widgets/active_workers_widget.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PMDashboardPage(),
    ),
  );
}

class PMDashboardPage extends StatelessWidget {
  const PMDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          // Sidebar stays fixed on the left
          const Sidebar(currentPage: 'Dashboard'),

          // Right area (header fixed, content scrollable)
          Expanded(
            child: Column(
              children: [
                // Header fixed at top
                const DashboardHeader(),

                // Main content area
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Recent Projects
                          const RecentProjects(),
                          const SizedBox(height: 24),

                          // Activity and Task Summary row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Expanded(
                                flex: 2,
                                child: ActivityWidget(),
                              ),
                              SizedBox(width: 24),
                              Expanded(
                                child: TaskSummaryWidget(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Task Today and Active Workers row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Expanded(
                                flex: 2,
                                child: TaskTodayWidget(),
                              ),
                              SizedBox(width: 24),
                              Expanded(
                                child: ActiveWorkersWidget(),
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
          ),
        ],
      ),
    );
  }
}
