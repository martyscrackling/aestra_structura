import 'package:flutter/material.dart';
import '../../services/supervisor_dashboard_data_service.dart';

class PhasesWidget extends StatefulWidget {
  final int projectId;

  const PhasesWidget({super.key, required this.projectId});

  @override
  State<PhasesWidget> createState() => _PhasesWidgetState();
}

class _PhasesWidgetState extends State<PhasesWidget> {
  late Future<List<Map<String, dynamic>>> _phasesFuture;

  @override
  void initState() {
    super.initState();
    _phasesFuture = _fetchPhases();
  }

  @override
  void didUpdateWidget(covariant PhasesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      setState(() {
        _phasesFuture = _fetchPhases();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPhases() async {
    return SupervisorDashboardDataService.fetchPhasesForProject(
      widget.projectId,
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color.fromARGB(255, 76, 175, 80);
      case 'in_progress':
        return const Color.fromARGB(255, 255, 152, 0);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _phasesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: const CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: const Text('No phases found'),
          );
        }

        final phases = snapshot.data!;

        // Sort phases by createdAt (oldest first)
        phases.sort((a, b) {
          final aCreated = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
          final bCreated = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
          int cmp = aCreated.compareTo(bCreated);
          if (cmp == 0) {
            return (a['phase_id'] ?? 0).compareTo(b['phase_id'] ?? 0);
          }
          return cmp;
        });

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Project Phases',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E3A44),
                ),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: phases.length,
                itemBuilder: (context, index) {
                  final phase = phases[index];
                  final phaseName = phase['phase_name'] ?? 'Unknown Phase';
                  final status = phase['status'] ?? 'not_started';
                  final daysLeft = phase['days_duration'] ?? 0;

                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(
                        phaseName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Status: ${status.replaceAll('_', ' ')} • Days: $daysLeft',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // TODO: Navigate to phase details with subtasks
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
