import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  static final List<WorkerSummary> _summaries = [
    WorkerSummary(label: 'Mason', icon: Icons.grass, count: 32),
    WorkerSummary(label: 'Painter', icon: Icons.format_paint_outlined, count: 32),
    WorkerSummary(label: 'Electrician', icon: Icons.electrical_services_outlined, count: 32),
    WorkerSummary(label: 'Supervisor', icon: Icons.supervised_user_circle_outlined, count: 32),
  ];

  static final List<SupervisorInfo> _supervisors = List.generate(
    6,
    (index) => SupervisorInfo(
      name: 'Khalid Mohammad Ali',
      email: 'khalid@gmail.com',
      phone: '092645115471',
      avatarUrl: 'https://randomuser.me/api/portraits/men/${index + 30}.jpg',
    ),
  );

  static final List<SiteLog> _recentLogs = [
    SiteLog(
      title: 'Exterior wall priming completed for Tower B, Level 3-4',
      workerCount: 10,
      date: '02-19-2025',
      attachments: '2 Photos',
      status: 'On track',
    ),
    SiteLog(
      title: 'Roofing Outside Balcony',
      workerCount: 6,
      date: '02-19-2025',
      attachments: '2 Photos',
      status: 'Review',
    ),
    SiteLog(
      title: 'Plastering Comfort Room',
      workerCount: 2,
      date: '02-19-2025',
      attachments: '2 Photos',
      status: 'Pending',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          const Sidebar(currentPage: 'Reports'),
          Expanded(
            child: Column(
              children: [
                const DashboardHeader(title: 'Reports'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TotalsSection(summaries: _summaries),
                        const SizedBox(height: 24),
                        _SupervisorsSection(supervisors: _supervisors),
                        const SizedBox(height: 24),
                        RecentLogs(logs: _recentLogs),
                      ],
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

class _TotalsSection extends StatelessWidget {
  const _TotalsSection({required this.summaries});

  final List<WorkerSummary> summaries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Total Active workers',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0C1935),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: summaries
              .map(
                (summary) => Container(
                  width: 150,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(summary.icon, color: const Color(0xFFFF7A18), size: 32),
                      const SizedBox(height: 12),
                      Text(
                        summary.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0C1935),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${summary.count}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0C1935),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _SupervisorsSection extends StatelessWidget {
  const _SupervisorsSection({required this.supervisors});

  final List<SupervisorInfo> supervisors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supervisors',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0C1935),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnCount = constraints.maxWidth > 1200
                ? 4
                : constraints.maxWidth > 900
                    ? 3
                    : constraints.maxWidth > 620
                        ? 2
                        : 1;
            final cardWidth = (constraints.maxWidth - (columnCount - 1) * 16) / columnCount;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: supervisors
                  .map(
                    (supervisor) => SizedBox(
                      width: cardWidth,
                      child: SupervisorCard(info: supervisor),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 180,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFFBEDE4),
                foregroundColor: const Color(0xFF0C1935),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {},
              child: const Text(
                'View all',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SupervisorCard extends StatelessWidget {
  const SupervisorCard({super.key, required this.info});

  final SupervisorInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: NetworkImage(info.avatarUrl),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0C1935),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info.email,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 2),
                Text(
                  info.phone,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              onPressed: () {},
              child: const Text(
                'View',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RecentLogs extends StatelessWidget {
  const RecentLogs({super.key, required this.logs});

  final List<SiteLog> logs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Logs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0C1935),
            ),
          ),
          const SizedBox(height: 16),
          ...logs.map(
            (log) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      log.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Worker: ${log.workerCount}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      log.date,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      log.attachments,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: log.status == 'On track'
                          ? const Color(0xFFE8F8F0)
                          : log.status == 'Review'
                              ? const Color(0xFFFFF5E6)
                              : const Color(0xFFFFEEF0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      log.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: log.status == 'On track'
                            ? const Color(0xFF10B981)
                            : log.status == 'Review'
                                ? const Color(0xFFFF7A18)
                                : const Color(0xFFF43F5E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0C1935),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'View',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkerSummary {
  const WorkerSummary({
    required this.label,
    required this.icon,
    required this.count,
  });

  final String label;
  final IconData icon;
  final int count;
}

class SupervisorInfo {
  const SupervisorInfo({
    required this.name,
    required this.email,
    required this.phone,
    required this.avatarUrl,
  });

  final String name;
  final String email;
  final String phone;
  final String avatarUrl;
}

class SiteLog {
  const SiteLog({
    required this.title,
    required this.workerCount,
    required this.date,
    required this.attachments,
    required this.status,
  });

  final String title;
  final int workerCount;
  final String date;
  final String attachments;
  final String status;
}
