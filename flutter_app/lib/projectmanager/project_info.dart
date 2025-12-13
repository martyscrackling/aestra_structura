import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';

class ProjectDetailsPage extends StatefulWidget {
  final String projectTitle;
  final String projectLocation;
  final String projectImage;
  final double progress;
  final String? budget;
  final int projectId;

  const ProjectDetailsPage({
    super.key,
    required this.projectTitle,
    required this.projectLocation,
    required this.projectImage,
    required this.progress,
    this.budget,
    required this.projectId,
  });

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  Map<String, dynamic>? _clientInfo;
  Map<String, dynamic>? _supervisorInfo;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProjectDetails();
  }

  Future<void> _fetchProjectDetails() async {
    try {
      // First fetch project details to get client_id and supervisor_id
      final projectResponse = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/projects/${widget.projectId}/'),
      );

      if (projectResponse.statusCode != 200) {
        setState(() {
          _error = 'Failed to load project details';
          _isLoading = false;
        });
        return;
      }

      final projectData = jsonDecode(projectResponse.body);
      final clientId = projectData['client_id'];
      final supervisorId = projectData['supervisor_id'];

      print('🔍 Project ID: ${widget.projectId}');
      print('🔍 Client ID: $clientId');
      print('🔍 Supervisor ID: $supervisorId');

      // Fetch client information
      if (clientId != null) {
        try {
          final clientResponse = await http.get(
            Uri.parse('http://127.0.0.1:8000/api/clients/$clientId/'),
          );
          if (clientResponse.statusCode == 200) {
            setState(() {
              _clientInfo = jsonDecode(clientResponse.body);
              print('✅ Client info fetched: ${_clientInfo?['email']}');
            });
          }
        } catch (e) {
          print('⚠️ Error fetching client: $e');
        }
      }

      // Fetch supervisor information
      if (supervisorId != null) {
        try {
          final supervisorResponse = await http.get(
            Uri.parse('http://127.0.0.1:8000/api/supervisors/$supervisorId/'),
          );
          if (supervisorResponse.statusCode == 200) {
            setState(() {
              _supervisorInfo = jsonDecode(supervisorResponse.body);
              print('✅ Supervisor info fetched: ${_supervisorInfo?['email']}');
            });
          }
        } catch (e) {
          print('⚠️ Error fetching supervisor: $e');
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _error = 'Error loading project details: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        body: Row(
          children: [
            const Sidebar(currentPage: 'Projects'),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        body: Row(
          children: [
            const Sidebar(currentPage: 'Projects'),
            Expanded(child: Center(child: Text('Error: $_error'))),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          const Sidebar(currentPage: 'Projects'),
          Expanded(
            child: Column(
              children: [
                const DashboardHeader(title: 'Project Details'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Banner Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildProjectImage(widget.projectImage),
                        ),

                        const SizedBox(height: 24),

                        // Project Title + Edit icon
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                widget.projectTitle,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const Icon(Icons.edit, size: 20),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Location
                        Text(
                          widget.projectLocation,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 25),

                        // Progress bar number
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            "${(widget.progress * 100).round()}%",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[400],
                            ),
                          ),
                        ),

                        // Progress bar
                        LinearProgressIndicator(
                          value: widget.progress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(20),
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.red.shade400,
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Client & Supervisor Cards
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_clientInfo != null)
                              _infoCard(
                                title: "Client:",
                                name:
                                    '${_clientInfo!['first_name']} ${_clientInfo!['last_name']}',
                                email: _clientInfo!['email'] ?? 'N/A',
                                phone: _clientInfo!['phone_number'] ?? 'N/A',
                              )
                            else
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text('No client assigned'),
                                  ),
                                ),
                              ),
                            if (_supervisorInfo != null)
                              _infoCard(
                                title: "Supervisor-in charge:",
                                name:
                                    '${_supervisorInfo!['first_name']} ${_supervisorInfo!['last_name']}',
                                email: _supervisorInfo!['email'] ?? 'N/A',
                                phone:
                                    _supervisorInfo!['phone_number'] ?? 'N/A',
                              )
                            else
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text('No supervisor assigned'),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Manage Workforce Button
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {},
                            child: const Text(
                              "Manage Workforce",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        const Divider(),

                        const SizedBox(height: 24),

                        // Project Plan Title
                        const Text(
                          "Project Plan",
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // No plans message
                        Center(
                          child: Column(
                            children: [
                              Text(
                                "No plans yet",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 26,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  "Add now",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
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

  Widget _buildProjectImage(String imagePath) {
    try {
      // Check if it's an asset path
      if (imagePath.startsWith('assets/')) {
        return Image.asset(
          imagePath,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        );
      }

      return _buildPlaceholder();
    } catch (e) {
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 220,
      width: double.infinity,
      color: Colors.grey[300],
      child: const Center(child: Icon(Icons.image_not_supported, size: 40)),
    );
  }

  Widget _infoCard({
    required String title,
    required String name,
    required String email,
    required String phone,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: const AssetImage(
                    "assets/images/profile.jpg",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        phone,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.bottomRight,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  side: const BorderSide(color: Colors.orangeAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "View Profile",
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
