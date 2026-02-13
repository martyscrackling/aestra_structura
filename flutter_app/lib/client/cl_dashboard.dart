import 'package:flutter/material.dart';
import 'widgets/top_controls.dart';
import 'widgets/projects_grid.dart';
import 'models/project_item.dart';
import 'widgets/dashboard_header.dart';
import '../services/client_dashboard_service.dart';

class ClDashboardPage extends StatefulWidget {
  const ClDashboardPage({super.key});

  @override
  State<ClDashboardPage> createState() => _ClDashboardPageState();
}

class _ClDashboardPageState extends State<ClDashboardPage> {
  final _service = ClientDashboardService();
  late Future<List<ProjectItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ProjectItem>> _load() async {
    final cards = await _service.fetchClientProjects();
    return cards
        .map(
          (p) => ProjectItem(
            projectId: p.projectId,
            title: p.title,
            location: p.location,
            progress: p.progress,
            startDate: p.startDate,
            endDate: p.endDate,
            tasksCompleted: p.tasksCompleted,
            totalTasks: p.totalTasks,
            imageUrl: p.imageUrl,
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Column(
        children: [
          const ClientDashboardHeader(title: 'Projects'),
          Expanded(
            child: FutureBuilder<List<ProjectItem>>(
              future: _future,
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <ProjectItem>[];

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _future = _load();
                    });
                    await _future;
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 24,
                      vertical: isMobile ? 16 : 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TopControls(),
                        SizedBox(height: isMobile ? 16 : 18),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Center(child: CircularProgressIndicator())
                        else if (snapshot.hasError)
                          const Text(
                            'Unable to load projects.',
                            style: TextStyle(color: Color(0xFF6B7280)),
                          )
                        else
                          ProjectsGrid(items: items),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
