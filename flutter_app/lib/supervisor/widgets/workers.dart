import 'package:flutter/material.dart';
import '../../services/supervisor_dashboard_data_service.dart';

class Workers extends StatefulWidget {
  final int projectId;

  const Workers({super.key, required this.projectId});

  @override
  State<Workers> createState() => _WorkersState();
}

class _WorkersState extends State<Workers> {
  late Future<List<Map<String, dynamic>>> _workersFuture;

  @override
  void initState() {
    super.initState();
    _workersFuture = _fetchWorkers();
  }

  @override
  void didUpdateWidget(covariant Workers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      setState(() {
        _workersFuture = _fetchWorkers();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchWorkers() async {
    return SupervisorDashboardDataService.fetchWorkersForProject(
      widget.projectId,
    );
  }

  IconData _workerIcon() => Icons.engineering_outlined;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _workersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            color: Colors.transparent,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: const CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Card(
            color: Colors.transparent,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: const Text('No workers assigned'),
            ),
          );
        }

        final workers = snapshot.data!;

        return Card(
          color: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Active Workers (${workers.length})",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: workers.map((worker) {
                    final firstName = worker['first_name'] ?? '';
                    final lastName = worker['last_name'] ?? '';
                    final role = worker['role'] ?? 'Worker';

                    return Container(
                      width: 120,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 252, 252, 252),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            spreadRadius: 0,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _workerIcon(),
                            size: 32,
                            color: const Color.fromARGB(255, 243, 146, 1),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            role,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$firstName $lastName',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
