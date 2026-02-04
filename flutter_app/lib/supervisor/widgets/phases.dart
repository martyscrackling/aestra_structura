import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/app_config.dart';

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

  Future<List<Map<String, dynamic>>> _fetchPhases() async {
    try {
      final response = await http.get(
        AppConfig.apiUri('phases/?project_id=${widget.projectId}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      print('Error fetching phases: $e');
      return [];
    }
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
