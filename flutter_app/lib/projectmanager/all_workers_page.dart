import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/responsive_page_layout.dart';
import '../services/app_config.dart';
import '../services/auth_service.dart';

class AllWorkersPage extends StatefulWidget {
  final int projectId;
  final String projectTitle;
  final bool useResponsiveLayout;

  const AllWorkersPage({
    super.key,
    required this.projectId,
    required this.projectTitle,
    this.useResponsiveLayout = true,
  });

  @override
  State<AllWorkersPage> createState() => _AllWorkersPageState();
}

class _AllWorkersPageState extends State<AllWorkersPage> {
  List<Map<String, dynamic>> _workers = [];
  List<Map<String, dynamic>> _supervisors = [];
  bool _isLoading = true;
  String? _error;

  String? _resolveMediaUrl(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();
    if (value.isEmpty || value == 'null') return null;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final base = Uri.parse(AppConfig.apiBaseUrl);
    final origin = Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
    );

    if (value.startsWith('/')) {
      return origin.resolve(value).toString();
    }
    if (value.startsWith('media/')) {
      return origin.resolve('/$value').toString();
    }
    if (value.startsWith('fieldworker_images/')) {
      return origin.resolve('/media/$value').toString();
    }

    return origin.resolve('/media/$value').toString();
  }

  Widget _buildProfileAvatar({
    required double radius,
    required String? photoUrl,
  }) {
    final size = radius * 2;
    final url = (photoUrl ?? '').trim();

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person_outline,
          color: Colors.grey[500],
          size: radius,
        ),
      );
    }

    if (url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[200],
        child: Icon(
          Icons.person_outline,
          color: Colors.grey[500],
          size: radius,
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return fallback();
          },
          errorBuilder: (context, error, stackTrace) {
            return fallback();
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchProjectWorkers();
  }

  Future<void> _fetchProjectWorkers() async {
    try {
      final authUser = AuthService().currentUser;
      final userId = authUser?['user_id'];

      print('🔍 Fetching project details for project: ${widget.projectId}');

      // First, try to fetch supervisors linked to this project via project_id
      try {
        final supervisorsUrl = userId != null
            ? 'supervisors/?project_id=${widget.projectId}&user_id=$userId'
            : 'supervisors/?project_id=${widget.projectId}';

        print('🔍 Fetching supervisors with project filter: $supervisorsUrl');
        final supervisorsResponse = await http.get(
          AppConfig.apiUri(supervisorsUrl),
        );

        if (supervisorsResponse.statusCode == 200) {
          final decodedResponse = jsonDecode(supervisorsResponse.body);
          List<dynamic> supervisorsList = [];

          if (decodedResponse is List) {
            supervisorsList = decodedResponse;
          } else if (decodedResponse is Map &&
              decodedResponse['results'] != null) {
            supervisorsList = decodedResponse['results'] as List<dynamic>;
          } else if (decodedResponse is Map &&
              decodedResponse['data'] != null) {
            supervisorsList = decodedResponse['data'] as List<dynamic>;
          }

          if (supervisorsList.isNotEmpty) {
            setState(() {
              _supervisors = supervisorsList.cast<Map<String, dynamic>>();
            });
            print(
              '✅ Loaded ${_supervisors.length} supervisor(s) from project_id filter',
            );
          }
        }
      } catch (e) {
        print('⚠️ Error fetching supervisors by project_id: $e');
      }

      // Fallback: Fetch project details to get supervisor from project object
      print('🔍 Fetching project details for backup supervisor data');
      final candidateProjectUrls = <String>[
        if (userId != null) 'projects/${widget.projectId}/?user_id=$userId',
        'projects/${widget.projectId}/',
      ];

      http.Response? projectResponse;
      for (final url in candidateProjectUrls) {
        try {
          final response = await http.get(AppConfig.apiUri(url));
          if (response.statusCode == 200) {
            projectResponse = response;
            break;
          }
          print(
            '❌ Project fetch failed (${response.statusCode}) for URL: $url',
          );
        } catch (e) {
          print('⚠️ Error fetching project from $url: $e');
        }
      }

      if (projectResponse != null && projectResponse.statusCode == 200) {
        try {
          final projectData =
              jsonDecode(projectResponse.body) as Map<String, dynamic>;

          // Only use project supervisor data if we haven't already fetched supervisors
          if (_supervisors.isEmpty) {
            // Check if supervisors are in project data as a list
            if (projectData['supervisors'] is List) {
              setState(() {
                _supervisors = (projectData['supervisors'] as List<dynamic>)
                    .cast<Map<String, dynamic>>();
              });
              print(
                '✅ Supervisors found in project data: ${_supervisors.length} supervisor(s)',
              );
            } else if (projectData['supervisor'] is Map) {
              // Single supervisor as a map
              setState(() {
                _supervisors = [
                  projectData['supervisor'] as Map<String, dynamic>,
                ];
              });
              print(
                '✅ Supervisor found in project data: ${_supervisors.first['first_name']} ${_supervisors.first['last_name']}',
              );
            } else if (projectData['supervisor'] is int) {
              // Supervisor is just an ID, fetch full supervisor details
              final supervisorId = projectData['supervisor'] as int;
              print(
                '🔍 Supervisor is stored as ID: $supervisorId, fetching full details...',
              );

              try {
                final supervisorUrl = userId != null
                    ? 'supervisors/$supervisorId/?user_id=$userId'
                    : 'supervisors/$supervisorId/';

                final supervisorResponse = await http.get(
                  AppConfig.apiUri(supervisorUrl),
                );
                if (supervisorResponse.statusCode == 200) {
                  final supervisorData =
                      jsonDecode(supervisorResponse.body)
                          as Map<String, dynamic>;
                  setState(() {
                    _supervisors = [supervisorData];
                  });
                  print(
                    '✅ Supervisor details fetched: ${_supervisors.first['first_name']} ${_supervisors.first['last_name']}',
                  );
                } else {
                  print(
                    '❌ Failed to fetch supervisor details: ${supervisorResponse.statusCode}',
                  );
                }
              } catch (e) {
                print('⚠️ Error fetching supervisor details: $e');
              }
            } else {
              print('ℹ️ No supervisors found in project data');
            }
          }
        } catch (e) {
          print('⚠️ Error parsing supervisors from project data: $e');
        }
      } else {
        print('❌ Could not fetch project details to get backup supervisors');
      }

      print(
        '🔍 Fetching phases with subtasks for project: ${widget.projectId}',
      );

      // Fetch phases to get subtasks
      final phasesUrl = userId != null
          ? 'phases/?project_id=${widget.projectId}&user_id=$userId'
          : 'phases/?project_id=${widget.projectId}';

      print('🔍 Phases URL: $phasesUrl');
      final phasesResponse = await http.get(AppConfig.apiUri(phasesUrl));

      print('📊 Phases Response Status: ${phasesResponse.statusCode}');
      print(
        '📊 Phases Response Body: ${phasesResponse.body.substring(0, phasesResponse.body.length > 500 ? 500 : phasesResponse.body.length)}...',
      );

      if (phasesResponse.statusCode != 200) {
        setState(() {
          _error = 'Failed to load phases';
          _isLoading = false;
        });
        return;
      }

      // Parse phases response
      final decodedPhases = jsonDecode(phasesResponse.body);
      List<dynamic> phasesList = [];

      if (decodedPhases is List) {
        phasesList = decodedPhases;
      } else if (decodedPhases is Map && decodedPhases['results'] != null) {
        phasesList = decodedPhases['results'] as List<dynamic>;
      } else if (decodedPhases is Map && decodedPhases['data'] != null) {
        phasesList = decodedPhases['data'] as List<dynamic>;
      }

      print('📊 Total phases: ${phasesList.length}');

      final Map<int, Map<String, dynamic>> workersMap = {};

      // Go through each phase and its subtasks
      for (var phase in phasesList) {
        try {
          final phaseMap = phase as Map<String, dynamic>;
          final phaseId = phaseMap['phase_id'] ?? phaseMap['id'];
          final phaseName = phaseMap['phase_name'] ?? 'Unknown';

          print('🔍 Processing Phase: $phaseName (ID: $phaseId)');

          // Get subtasks for this phase
          final subtasksUrl = userId != null
              ? 'subtasks/?phase_id=$phaseId&user_id=$userId'
              : 'subtasks/?phase_id=$phaseId';

          print('  🔍 Fetching subtasks from: $subtasksUrl');
          final subtasksResponse = await http.get(
            AppConfig.apiUri(subtasksUrl),
          );

          if (subtasksResponse.statusCode == 200) {
            final decodedSubtasks = jsonDecode(subtasksResponse.body);
            List<dynamic> subtasksList = [];

            if (decodedSubtasks is List) {
              subtasksList = decodedSubtasks;
            } else if (decodedSubtasks is Map &&
                decodedSubtasks['results'] != null) {
              subtasksList = decodedSubtasks['results'] as List<dynamic>;
            } else if (decodedSubtasks is Map &&
                decodedSubtasks['data'] != null) {
              subtasksList = decodedSubtasks['data'] as List<dynamic>;
            }

            print('  📊 Subtasks found: ${subtasksList.length}');

            // For each subtask, get assigned workers
            for (var subtask in subtasksList) {
              try {
                final subtaskMap = subtask as Map<String, dynamic>;
                final subtaskId = subtaskMap['subtask_id'] ?? subtaskMap['id'];
                final subtaskTitle = subtaskMap['title'] ?? 'Unknown';

                print('    🔍 Subtask: $subtaskTitle (ID: $subtaskId)');

                // Try multiple endpoints to get worker assignments
                final List<String> assignmentUrls = [
                  'subtask-field-workers/?subtask_id=$subtaskId',
                  'subtask-assignments/?subtask_id=$subtaskId',
                  'field-workers/?subtask_id=$subtaskId',
                ];

                for (final assignUrl in assignmentUrls) {
                  print('      🔍 Trying: $assignUrl');

                  try {
                    final assignResponse = await http.get(
                      AppConfig.apiUri(assignUrl),
                    );

                    if (assignResponse.statusCode == 200) {
                      print('      ✅ Success with: $assignUrl');
                      final decodedAssigns = jsonDecode(assignResponse.body);
                      List<dynamic> assignmentsList = [];

                      if (decodedAssigns is List) {
                        assignmentsList = decodedAssigns;
                      } else if (decodedAssigns is Map &&
                          decodedAssigns['results'] != null) {
                        assignmentsList =
                            decodedAssigns['results'] as List<dynamic>;
                      } else if (decodedAssigns is Map &&
                          decodedAssigns['data'] != null) {
                        assignmentsList =
                            decodedAssigns['data'] as List<dynamic>;
                      }

                      print(
                        '      📊 Assignments found: ${assignmentsList.length}',
                      );

                      // Process each assignment
                      for (var assignment in assignmentsList) {
                        final assignMap = assignment as Map<String, dynamic>;

                        // Try to get worker data directly or by ID
                        Map<String, dynamic>? workerData;
                        int? workerId;

                        // Check if worker data is embedded in assignment
                        if (assignMap['field_worker'] is Map) {
                          workerData =
                              assignMap['field_worker'] as Map<String, dynamic>;
                          workerId =
                              workerData['id'] ?? workerData['fieldworker_id'];
                        } else if (assignMap['field_worker'] is int) {
                          workerId = assignMap['field_worker'] as int;
                        }

                        // If we have worker data, add it
                        if (workerData != null && workerId != null) {
                          workersMap[workerId] = workerData;
                          print(
                            '        ✅ Worker found in assignment: ${workerData['first_name']} ${workerData['last_name']}',
                          );
                        } else if (workerId != null) {
                          // Fetch full worker details
                          try {
                            final workerUrl = userId != null
                                ? 'field-workers/$workerId/?user_id=$userId'
                                : 'field-workers/$workerId/';

                            print(
                              '        🔍 Fetching worker details from: $workerUrl',
                            );
                            final workerResp = await http.get(
                              AppConfig.apiUri(workerUrl),
                            );

                            if (workerResp.statusCode == 200) {
                              final workerInfo =
                                  jsonDecode(workerResp.body)
                                      as Map<String, dynamic>;
                              workersMap[workerId] = workerInfo;
                              print(
                                '        ✅ Worker loaded: ${workerInfo['first_name']} ${workerInfo['last_name']}',
                              );
                            }
                          } catch (e) {
                            print(
                              '        ⚠️ Error fetching worker $workerId: $e',
                            );
                          }
                        }
                      }

                      break; // Found working endpoint, exit loop
                    }
                  } catch (e) {
                    print('      ⚠️ Error with $assignUrl: $e');
                  }
                }
              } catch (e) {
                print('    ⚠️ Error processing subtask: $e');
              }
            }
          } else {
            print(
              '  ❌ Failed to fetch subtasks: ${subtasksResponse.statusCode}',
            );
          }
        } catch (e) {
          print('🔍 Error processing phase: $e');
        }
      }

      setState(() {
        _workers = workersMap.values.toList();
        _isLoading = false;
      });

      print('✅ Loaded ${_workers.length} unique workers');
    } catch (e) {
      print('❌ ERROR: $e');
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  String _getFullName(Map<String, dynamic> worker) {
    final firstName = worker['first_name'] ?? '';
    final lastName = worker['last_name'] ?? '';
    return '$firstName $lastName'.trim();
  }

  void _showExistingSupervisorsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Select Supervisor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a supervisor to add to this project',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchAllSupervisors(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Error: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final allSupervisors = snapshot.data ?? [];

                      // Filter out already assigned supervisors
                      final assignedSupervisorIds = _supervisors
                          .map((sup) => sup['id'] ?? sup['supervisor_id'])
                          .toSet();
                      final supervisors = allSupervisors
                          .where(
                            (sup) => !assignedSupervisorIds.contains(
                              sup['id'] ?? sup['supervisor_id'],
                            ),
                          )
                          .toList();

                      if (supervisors.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No other supervisors available',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: supervisors.length,
                        itemBuilder: (context, index) {
                          final supervisor = supervisors[index];
                          final firstName =
                              supervisor['first_name'] ?? 'Unknown';
                          final lastName = supervisor['last_name'] ?? '';
                          final fullName = '$firstName $lastName'.trim();
                          final phone = supervisor['phone_number'] ?? 'N/A';
                          final photoUrl = _resolveMediaUrl(
                            supervisor['photo'],
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              leading: _buildProfileAvatar(
                                radius: 20,
                                photoUrl: photoUrl,
                              ),
                              title: Text(
                                fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              subtitle: Text(phone),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _assignSupervisorToProject(supervisor);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2196F3),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text(
                                  'Add',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAllSupervisors() async {
    try {
      final authUser = AuthService().currentUser;
      final userId = authUser?['user_id'];

      print('🔍 Fetching all supervisors...');

      final supervisorsUrl = userId != null
          ? 'supervisors/?user_id=$userId'
          : 'supervisors/';

      final response = await http.get(AppConfig.apiUri(supervisorsUrl));

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        List<dynamic> supervisorsList = [];

        if (decodedResponse is List) {
          supervisorsList = decodedResponse;
        } else if (decodedResponse is Map &&
            decodedResponse['results'] != null) {
          supervisorsList = decodedResponse['results'] as List<dynamic>;
        } else if (decodedResponse is Map && decodedResponse['data'] != null) {
          supervisorsList = decodedResponse['data'] as List<dynamic>;
        }

        print('✅ Fetched ${supervisorsList.length} supervisors');

        return supervisorsList.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load supervisors: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching supervisors: $e');
      throw Exception('Error: $e');
    }
  }

  Future<void> _assignSupervisorToProject(
    Map<String, dynamic> supervisor,
  ) async {
    try {
      final authUser = AuthService().currentUser;
      final userId = authUser?['user_id'];
      final supervisorId = supervisor['id'] ?? supervisor['supervisor_id'];
      final supervisorName =
          '${supervisor['first_name']} ${supervisor['last_name']}'.trim();

      print(
        '🔍 Assigning supervisor $supervisorName (ID: $supervisorId) to project ${widget.projectId}...',
      );

      // Prepare request body with all necessary data
      final requestBody = jsonEncode({
        'supervisor_id': supervisorId,
        'project_id': widget.projectId,
        if (userId != null) 'user_id': userId,
      });

      print('  📤 Request body: $requestBody');

      // Try multiple endpoint formats
      final candidateUrls = <String>[
        if (userId != null)
          'projects/${widget.projectId}/add-supervisor/?user_id=$userId',
        'projects/${widget.projectId}/add-supervisor/',
        if (userId != null)
          'project-supervisors/?project_id=${widget.projectId}&supervisor_id=$supervisorId&user_id=$userId',
        'project-supervisors/?project_id=${widget.projectId}&supervisor_id=$supervisorId',
        if (userId != null)
          'supervisors/$supervisorId/assign-to-project/?user_id=$userId',
        'supervisors/$supervisorId/assign-to-project/',
      ];

      http.Response? response;
      bool success = false;
      String successUrl = '';

      for (final url in candidateUrls) {
        try {
          print('  🔍 Trying endpoint: $url');
          final attemptResponse = await http.post(
            AppConfig.apiUri(url),
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          );

          print('  📊 Response: ${attemptResponse.statusCode}');
          print('  📊 Response Body: ${attemptResponse.body}');

          if (attemptResponse.statusCode == 200 ||
              attemptResponse.statusCode == 201) {
            response = attemptResponse;
            success = true;
            successUrl = url;
            print('  ✅ Success with endpoint: $url');
            break;
          }
        } catch (e) {
          print('  ⚠️ Endpoint failed: $e');
        }
      }

      if (success && response != null) {
        print('✅ Supervisor assigned successfully to project on backend');
        print('   Endpoint used: $successUrl');

        // Verify by checking response contains supervisor data with project assignment
        try {
          final responseData = jsonDecode(response.body);
          print('   Response data: $responseData');
        } catch (e) {
          print('   Could not parse response data: $e');
        }

        // Refresh supervisors list from database to verify persistence
        print('🔄 Refreshing supervisors list from database...');
        await _refreshSupervisorsFromDatabase();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $supervisorName assigned to project'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        print('❌ Failed to assign supervisor on all endpoints');
        if (response != null) {
          print('Last response: ${response.body}');
        }

        // Still add to local list for immediate UI feedback
        setState(() {
          if (!_supervisors.any(
            (s) => (s['id'] ?? s['supervisor_id']) == supervisorId,
          )) {
            _supervisors.add(supervisor);
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ $supervisorName added locally (syncing with database...)',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error assigning supervisor: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _refreshSupervisorsFromDatabase() async {
    try {
      final authUser = AuthService().currentUser;
      final userId = authUser?['user_id'];

      print('🔍 Fetching updated supervisors from project...');

      // First, try to fetch supervisors linked to this project via project_id
      try {
        final supervisorsUrl = userId != null
            ? 'supervisors/?project_id=${widget.projectId}&user_id=$userId'
            : 'supervisors/?project_id=${widget.projectId}';

        print(
          '  🔍 Trying to fetch supervisors with project filter: $supervisorsUrl',
        );
        final supervisorsResponse = await http.get(
          AppConfig.apiUri(supervisorsUrl),
        );

        if (supervisorsResponse.statusCode == 200) {
          final decodedResponse = jsonDecode(supervisorsResponse.body);
          List<dynamic> supervisorsList = [];

          if (decodedResponse is List) {
            supervisorsList = decodedResponse;
          } else if (decodedResponse is Map &&
              decodedResponse['results'] != null) {
            supervisorsList = decodedResponse['results'] as List<dynamic>;
          } else if (decodedResponse is Map &&
              decodedResponse['data'] != null) {
            supervisorsList = decodedResponse['data'] as List<dynamic>;
          }

          if (supervisorsList.isNotEmpty) {
            setState(() {
              _supervisors = supervisorsList.cast<Map<String, dynamic>>();
            });
            print(
              '✅ Found ${_supervisors.length} supervisor(s) linked to project via project_id',
            );
            return;
          }
        }
      } catch (e) {
        print('⚠️ Error fetching supervisors by project_id: $e');
      }

      // Fallback: Fetch project details to get supervisor from project object
      print('  🔍 Falling back to fetching supervisor from project object...');
      final candidateProjectUrls = <String>[
        if (userId != null) 'projects/${widget.projectId}/?user_id=$userId',
        'projects/${widget.projectId}/',
      ];

      http.Response? projectResponse;
      for (final url in candidateProjectUrls) {
        try {
          final response = await http.get(AppConfig.apiUri(url));
          if (response.statusCode == 200) {
            projectResponse = response;
            break;
          }
        } catch (e) {
          print('⚠️ Error fetching project from $url: $e');
        }
      }

      if (projectResponse != null && projectResponse.statusCode == 200) {
        try {
          final projectData =
              jsonDecode(projectResponse.body) as Map<String, dynamic>;
          List<Map<String, dynamic>> updatedSupervisors = [];

          // Check if supervisors are in project data as a list
          if (projectData['supervisors'] is List) {
            updatedSupervisors = (projectData['supervisors'] as List<dynamic>)
                .cast<Map<String, dynamic>>();
            print(
              '✅ Found ${updatedSupervisors.length} supervisors in project.supervisors',
            );
          } else if (projectData['supervisor'] is Map) {
            updatedSupervisors = [
              projectData['supervisor'] as Map<String, dynamic>,
            ];
            print('✅ Found 1 supervisor in project.supervisor');
          } else if (projectData['supervisor'] is int) {
            final supervisorId = projectData['supervisor'] as int;
            try {
              final supervisorUrl = userId != null
                  ? 'supervisors/$supervisorId/?user_id=$userId'
                  : 'supervisors/$supervisorId/';
              final supervisorResponse = await http.get(
                AppConfig.apiUri(supervisorUrl),
              );
              if (supervisorResponse.statusCode == 200) {
                final supervisorData =
                    jsonDecode(supervisorResponse.body) as Map<String, dynamic>;
                updatedSupervisors = [supervisorData];
                print('✅ Fetched supervisor details from database');
              }
            } catch (e) {
              print('⚠️ Error fetching supervisor details: $e');
            }
          }

          // Update state with database values
          if (updatedSupervisors.isNotEmpty) {
            setState(() {
              _supervisors = updatedSupervisors;
            });
            print('✅ Supervisors refreshed from project object');
          }
        } catch (e) {
          print('⚠️ Error parsing project data: $e');
        }
      } else {
        print('❌ Could not fetch updated project data');
      }
    } catch (e) {
      print('❌ Error refreshing supervisors: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    final workersContent = SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                color: const Color(0xFF0C1935),
                tooltip: 'Back',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Project Workforce',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      widget.projectTitle,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ],
              ),
            )
          else if (_workers.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No workers assigned to this project',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Supervisor Section
                if (_supervisors.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Project Supervisors',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _showExistingSupervisorsDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Add Supervisor',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      ..._supervisors.map((supervisor) {
                        return _buildSupervisorCard(supervisor);
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Workers Count Badge
                Text(
                  'Project Team',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),

                // Worker count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7A18).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_workers.length} Active Worker${_workers.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF7A18),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Workers List
                Column(
                  children: [
                    ..._workers.map((worker) {
                      return _buildWorkerCard(worker);
                    }),
                  ],
                ),
              ],
            ),

          SizedBox(height: isMobile ? 80 : 32),
        ],
      ),
    );

    if (!widget.useResponsiveLayout) {
      return workersContent;
    }

    return ResponsivePageLayout(
      currentPage: 'Projects',
      title: 'Project Workforce',
      child: workersContent,
    );
  }

  Widget _buildWorkerCard(Map<String, dynamic> worker) {
    final fullName = _getFullName(worker);
    final phone = worker['phone_number'] ?? 'N/A';
    final role = worker['role'] ?? 'Field Worker';
    final photoUrl = _resolveMediaUrl(worker['photo']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          _buildProfileAvatar(radius: 28, photoUrl: photoUrl),
          const SizedBox(width: 12),

          // Worker Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Role Badge (Orange)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A18).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF7A18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Status Badge (Green)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Field Worker',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      phone,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // View Button
          ElevatedButton(
            onPressed: () {
              // TODO: Navigate to worker details
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A18),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'View',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupervisorCard(Map<String, dynamic> supervisor) {
    final fullName = _getFullName(supervisor);
    final phone = supervisor['phone_number'] ?? 'N/A';
    final role = supervisor['role'] ?? 'Supervisor';
    final photoUrl = _resolveMediaUrl(supervisor['photo']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          _buildProfileAvatar(radius: 28, photoUrl: photoUrl),
          const SizedBox(width: 12),

          // Supervisor Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Role Badge (Blue)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Status Badge (Purple)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Supervisor',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      phone,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // View Button
          ElevatedButton(
            onPressed: () {
              // TODO: Navigate to supervisor details
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'View',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
