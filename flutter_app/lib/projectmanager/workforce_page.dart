import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/responsive_page_layout.dart';
import 'modals/select_modal.dart';
import 'modals/add_worker_modal.dart';
import 'modals/add_fieldworker_modal.dart';
import 'worker_profile_page.dart';
import '../services/app_config.dart';

class WorkforcePage extends StatefulWidget {
  const WorkforcePage({super.key});

  @override
  State<WorkforcePage> createState() => _WorkforcePageState();
}

class _WorkforcePageState extends State<WorkforcePage> {
  List<WorkerGroup> _groups = [];
  bool _isLoading = true;
  String? _error;
  late int _projectId;
  String _searchQuery = '';
  String _filterType = 'All'; // All, Supervisor, Field Worker

  @override
  void initState() {
    super.initState();
    _fetchWorkerGroups();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get project_id from route arguments, default to 18 if not available
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _projectId = args?['project_id'] ?? 18;
  }

  Future<void> _fetchWorkerGroups() async {
    try {
      // Fetch supervisors
      final supervisorResponse = await http.get(
        AppConfig.apiUri('supervisors/'),
      );

      // Fetch field workers
      final fieldWorkerResponse = await http.get(
        AppConfig.apiUri('field-workers/'),
      );

      List<WorkerInfo> allWorkers = [];

      // Process supervisors
      if (supervisorResponse.statusCode == 200) {
        final List<dynamic> supervisors = jsonDecode(supervisorResponse.body);
        allWorkers.addAll(
          supervisors.map((supervisor) {
            return WorkerInfo(
              name: '${supervisor['first_name']} ${supervisor['last_name']}',
              email: supervisor['email'] ?? 'N/A',
              phone: supervisor['phone_number'] ?? 'N/A',
              role: supervisor['role'] ?? 'Supervisor',
              avatarUrl: 'https://randomuser.me/api/portraits/men/1.jpg',
              type: 'Supervisor',
            );
          }).toList(),
        );
      }

      // Process field workers
      if (fieldWorkerResponse.statusCode == 200) {
        final List<dynamic> fieldWorkers = jsonDecode(fieldWorkerResponse.body);
        allWorkers.addAll(
          fieldWorkers.map((fieldWorker) {
            return WorkerInfo(
              name: '${fieldWorker['first_name']} ${fieldWorker['last_name']}',
              email: 'N/A',
              phone: fieldWorker['phone_number'] ?? 'N/A',
              role: fieldWorker['role'] ?? 'Unknown',
              avatarUrl: 'https://randomuser.me/api/portraits/men/1.jpg',
              type: 'Field Worker',
            );
          }).toList(),
        );
      }

      setState(() {
        _groups = [WorkerGroup(title: 'All Workers', workers: allWorkers)];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading workers: $e';
        _isLoading = false;
      });
    }
  }

  List<WorkerInfo> _getFilteredWorkers() {
    if (_groups.isEmpty) return [];

    List<WorkerInfo> workers = _groups[0].workers;

    // Apply filter by type
    if (_filterType != 'All') {
      workers = workers.where((w) => w.type == _filterType).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      workers = workers.where((w) {
        final query = _searchQuery.toLowerCase();
        return w.name.toLowerCase().contains(query) ||
            w.role.toLowerCase().contains(query) ||
            w.email.toLowerCase().contains(query) ||
            w.phone.contains(query);
      }).toList();
    }

    return workers;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return ResponsivePageLayout(
      currentPage: 'Workforce',
      title: 'Workforce',
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
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                    vertical: isMobile ? 16 : 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTotals(),
                      const SizedBox(height: 24),
                      ..._groups.map(
                        (group) => Padding(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: WorkerGroupSection(
                            group: group,
                            projectId: _projectId,
                            onWorkerAdded: _fetchWorkerGroups,
                            filteredWorkers: _getFilteredWorkers(),
                            searchQuery: _searchQuery,
                            filterType: _filterType,
                            onSearchChanged: (query) {
                              setState(() => _searchQuery = query);
                            },
                            onFilterChanged: (filter) {
                              setState(() => _filterType = filter);
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: isMobile ? 80 : 0),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTotals() {
    // Calculate actual worker counts
    final allWorkers = _groups.isNotEmpty ? _groups[0].workers : [];

    final supervisorCount = allWorkers
        .where((w) => w.type == 'Supervisor')
        .length;
    final painterCount = allWorkers.where((w) => w.role == 'Painter').length;
    final electricianCount = allWorkers
        .where((w) => w.role == 'Electrician')
        .length;
    final masonCount = allWorkers.where((w) => w.role == 'Mason').length;

    final stats = [
      WorkerStat(
        label: 'Supervisor',
        icon: Icons.supervised_user_circle_outlined,
        count: supervisorCount,
      ),
      WorkerStat(
        label: 'Painter',
        icon: Icons.format_paint_outlined,
        count: painterCount,
      ),
      WorkerStat(
        label: 'Electrician',
        icon: Icons.electrical_services_outlined,
        count: electricianCount,
      ),
      WorkerStat(label: 'Mason', icon: Icons.grass, count: masonCount),
    ];

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
          children: stats
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
  const WorkerGroupSection({
    super.key,
    required this.group,
    required this.projectId,
    required this.onWorkerAdded,
    required this.filteredWorkers,
    required this.searchQuery,
    required this.filterType,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  final WorkerGroup group;
  final int projectId;
  final VoidCallback onWorkerAdded;
  final List<WorkerInfo> filteredWorkers;
  final String searchQuery;
  final String filterType;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;

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
                onPressed: () async {
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) => const SelectWorkerTypeModal(),
                  );

                  if (result != null) {
                    dynamic modalResult;
                    if (result == 'supervisor') {
                      modalResult = await showDialog(
                        context: context,
                        builder: (context) =>
                            const AddWorkerModal(workerType: 'Supervisor'),
                      );
                    } else if (result == 'fieldworker') {
                      modalResult = await showDialog(
                        context: context,
                        builder: (context) => AddFieldWorkerModal(
                          workerType: 'Field Worker',
                          projectId: projectId,
                        ),
                      );
                    }

                    if (modalResult == true) {
                      onWorkerAdded();
                    }
                  }
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
                onChanged: onSearchChanged,
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
              child: PopupMenuButton<String>(
                onSelected: onFilterChanged,
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(value: 'All', child: Text('All')),
                  const PopupMenuItem<String>(
                    value: 'Supervisor',
                    child: Text('Supervisor'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'Field Worker',
                    child: Text('Field Worker'),
                  ),
                ],
                child: OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.tune,
                        size: 16,
                        color: Color(0xFF0C1935),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        filterType,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0C1935),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: Color(0xFF0C1935),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (filteredWorkers.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        searchQuery.isNotEmpty || filterType != 'All'
                            ? 'No workers found'
                            : 'No workers yet added',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

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
              children: filteredWorkers
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
      ],
    );
  }
}

class WorkerProfileCard extends StatelessWidget {
  const WorkerProfileCard({super.key, required this.worker});

  final WorkerInfo worker;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Container(
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
                  Row(
                    children: [
                      Text(
                        worker.role,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF7A18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: worker.type == 'Supervisor'
                              ? const Color(0xFFE0E7FF)
                              : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          worker.type,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: worker.type == 'Supervisor'
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (worker.email != 'N/A') ...[
                    Text(
                      worker.email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
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
    this.type = 'Supervisor',
  });

  final String name;
  final String email;
  final String phone;
  final String role;
  final String avatarUrl;
  final String type; // 'Supervisor' or 'Field Worker'
}
