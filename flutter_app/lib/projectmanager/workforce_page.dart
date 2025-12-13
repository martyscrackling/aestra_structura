import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'modals/add_worker_modal.dart';
import 'worker_profile_page.dart';
import 'all_supervisors.dart';

class WorkforcePage extends StatefulWidget {
  const WorkforcePage({super.key});

  @override
  State<WorkforcePage> createState() => _WorkforcePageState();
}

class _WorkforcePageState extends State<WorkforcePage> {
  List<WorkerGroup> _groups = [];
  bool _isLoading = true;
  String? _error;

  static final List<WorkerStat> _workerStats = [
    WorkerStat(
      label: 'Supervisor',
      icon: Icons.supervised_user_circle_outlined,
      count: 32,
    ),
    WorkerStat(label: 'Painter', icon: Icons.format_paint_outlined, count: 32),
    WorkerStat(
      label: 'Electrician',
      icon: Icons.electrical_services_outlined,
      count: 32,
    ),
    WorkerStat(label: 'Mason', icon: Icons.grass, count: 32),
  ];

  @override
  void initState() {
    super.initState();
    _fetchWorkerGroups();
  }

  Future<void> _fetchWorkerGroups() async {
    try {
      // Fetch active supervisors
      final supervisorResponse = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/supervisors/'),
      );

      List<WorkerInfo> activeSupervisors = [];

      if (supervisorResponse.statusCode == 200) {
        final List<dynamic> supervisors = jsonDecode(supervisorResponse.body);
        activeSupervisors = supervisors
            .where((supervisor) => supervisor['status'] == 'active')
            .map((supervisor) {
              return WorkerInfo(
                name: '${supervisor['first_name']} ${supervisor['last_name']}',
                email: supervisor['email'] ?? 'N/A',
                phone: supervisor['phone_number'] ?? 'N/A',
                role: 'Supervisor',
                avatarUrl: 'https://randomuser.me/api/portraits/men/1.jpg',
              );
            })
            .toList();
      }

      setState(() {
        _groups = [
          WorkerGroup(title: 'Active Supervisors', workers: activeSupervisors),
          WorkerGroup(
            title: 'Active Mason',
            workers: _buildSampleWorkers(role: 'Mason'),
          ),
          WorkerGroup(
            title: 'Active Painter',
            workers: _buildSampleWorkers(role: 'Painter'),
          ),
          WorkerGroup(
            title: 'Active Electrician',
            workers: _buildSampleWorkers(role: 'Electrician'),
          ),
        ];
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching worker groups: $e');
      setState(() {
        _error = 'Error loading supervisors: $e';
        _isLoading = false;
      });
    }
  }

  static List<WorkerInfo> _buildSampleWorkers({String role = 'Supervisor'}) {
    return List.generate(
      6,
      (index) => WorkerInfo(
        name: 'Khalid Mohammad Ali',
        email: 'khalid@gmail.com',
        phone: '092645115471',
        role: role,
        avatarUrl: 'https://randomuser.me/api/portraits/men/1.jpg',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          const Sidebar(currentPage: 'Workforce'),
          Expanded(
            child: Column(
              children: [
                const DashboardHeader(title: 'Workforce'),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFFF7A18),
                          ),
                        )
                      : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTotals(),
                              const SizedBox(height: 24),
                              ..._groups.map(
                                (group) => Padding(
                                  padding: const EdgeInsets.only(bottom: 32),
                                  child: WorkerGroupSection(group: group),
                                ),
                              ),
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

  Widget _buildTotals() {
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
          children: _workerStats
              .map(
                (stat) => Container(
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
                      Icon(stat.icon, color: const Color(0xFFFF7A18), size: 32),
                      const SizedBox(height: 12),
                      Text(
                        stat.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0C1935),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${stat.count}',
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

class WorkerGroupSection extends StatelessWidget {
  const WorkerGroupSection({super.key, required this.group});

  final WorkerGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              group.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0C1935),
              ),
            ),
            const Spacer(),
            // Add new button
            SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AddWorkerModal(
                      workerType: group.title.replaceAll('Active ', ''),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A18),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text(
                  'Add new',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Search button
            SizedBox(
              height: 36,
              width: 200,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Filter button
            SizedBox(
              height: 36,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.tune, size: 16, color: Color(0xFF0C1935)),
                    SizedBox(width: 6),
                    Text(
                      'All',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: Color(0xFF0C1935),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnCount = constraints.maxWidth > 1300
                ? 4
                : constraints.maxWidth > 1000
                ? 3
                : constraints.maxWidth > 700
                ? 2
                : 1;
            final cardWidth =
                (constraints.maxWidth - (columnCount - 1) * 16) / columnCount;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: group.workers
                  .map(
                    (worker) => SizedBox(
                      width: cardWidth,
                      child: WorkerProfileCard(worker: worker),
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
              onPressed: () {
                // Navigate to all supervisors page only if this is the Active Supervisors group
                if (group.title == 'Active Supervisors') {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const WorkforceSupervisorsPage(),
                      transitionDuration: Duration.zero,
                    ),
                  );
                }
              },
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

class WorkerProfileCard extends StatelessWidget {
  const WorkerProfileCard({super.key, required this.worker});

  final WorkerInfo worker;

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
            radius: 28,
            backgroundImage: NetworkImage(worker.avatarUrl),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  worker.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0C1935),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  worker.email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  worker.phone,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 32,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF7A18),
                side: const BorderSide(color: Color(0xFFFFE0D3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        WorkerProfilePage(worker: worker),
                    transitionDuration: Duration.zero,
                  ),
                );
              },
              child: const Text(
                'View profile',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkerStat {
  const WorkerStat({
    required this.label,
    required this.icon,
    required this.count,
  });

  final String label;
  final IconData icon;
  final int count;
}

class WorkerGroup {
  const WorkerGroup({required this.title, required this.workers});

  final String title;
  final List<WorkerInfo> workers;
}

class WorkerInfo {
  const WorkerInfo({
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.avatarUrl,
  });

  final String name;
  final String email;
  final String phone;
  final String role;
  final String avatarUrl;
}
