import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'modals/add_worker_modal.dart';

class WorkforceSupervisorsPage extends StatefulWidget {
  const WorkforceSupervisorsPage({super.key});

  @override
  State<WorkforceSupervisorsPage> createState() =>
      _WorkforceSupervisorsPageState();
}

class _WorkforceSupervisorsPageState extends State<WorkforceSupervisorsPage> {
  List<SupervisorInfo> _supervisors = [];
  List<SupervisorInfo> _filteredSupervisors = [];
  bool _isLoading = true;
  String? _error;
  String _filterValue = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchSupervisors();
  }

  Future<void> _fetchSupervisors() async {
    try {
      print('Fetching supervisors from API...');
      final response = await http
          .get(
            Uri.parse('http://127.0.0.1:8000/api/supervisors/'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Request timed out');
            },
          );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> supervisors = jsonDecode(response.body);
        print('Fetched ${supervisors.length} supervisors');

        final List<SupervisorInfo> supervisorList = supervisors.map((
          supervisor,
        ) {
          final firstName = supervisor['first_name']?.toString().trim() ?? '';
          final lastName = supervisor['last_name']?.toString().trim() ?? '';
          print('Processing supervisor: $firstName $lastName');

          return SupervisorInfo(
            supervisorId: supervisor['supervisor_id'] ?? 0,
            firstName: firstName,
            lastName: lastName,
            email: supervisor['email']?.toString().trim() ?? 'N/A',
            phoneNumber: supervisor['phone_number']?.toString().trim() ?? 'N/A',
            status: supervisor['status']?.toString().trim() ?? 'active',
          );
        }).toList();

        print('Created ${supervisorList.length} SupervisorInfo objects');
        setState(() {
          _supervisors = supervisorList;
          _applyFiltersAndSearch();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error =
              'Failed to load supervisors: ${response.statusCode}\n${response.body}';
          _isLoading = false;
        });
      }
    } on TimeoutException catch (e) {
      print('Timeout error: $e');
      setState(() {
        _error = 'Request timed out. Is the server running?';
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching supervisors: $e');
      setState(() {
        _error = 'Error loading supervisors: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFiltersAndSearch() {
    _filteredSupervisors = _supervisors.where((supervisor) {
      // Filter by status
      bool statusMatch =
          _filterValue == 'All' ||
          ((_filterValue == 'Active' && supervisor.status == 'active') ||
              (_filterValue == 'Inactive' && supervisor.status != 'active'));

      // Filter by search query
      bool searchMatch =
          _searchQuery.isEmpty ||
          supervisor.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          supervisor.email.toLowerCase().contains(_searchQuery.toLowerCase());

      return statusMatch && searchMatch;
    }).toList();
  }

  void _onFilterChanged(String? value) {
    if (value != null) {
      setState(() {
        _filterValue = value;
        _applyFiltersAndSearch();
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFiltersAndSearch();
    });
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
                const DashboardHeader(title: 'Supervisors'),
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
                            horizontal: 30,
                            vertical: 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Back icon
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back),
                              ),
                              const SizedBox(height: 10),

                              // Title
                              const Text(
                                "All Supervisors",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Divider(),
                              const SizedBox(height: 16),

                              // Top row: Add new + Search + Filter
                              Row(
                                children: [
                                  const SizedBox(width: 20),

                                  // Search bar
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.search,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: TextField(
                                              onChanged: _onSearchChanged,
                                              decoration: const InputDecoration(
                                                hintText: "Search...",
                                                border: InputBorder.none,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Add new
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) =>
                                            const AddWorkerModal(
                                              workerType: 'Supervisor',
                                            ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.add,
                                      color: Colors.orange,
                                    ),
                                    label: const Text(
                                      "Add new",
                                      style: TextStyle(color: Colors.orange),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Colors.orange,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 20),

                                  // Filter dropdown
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _filterValue,
                                        items: const [
                                          DropdownMenuItem(
                                            value: "All",
                                            child: Text("All"),
                                          ),
                                          DropdownMenuItem(
                                            value: "Active",
                                            child: Text("Active"),
                                          ),
                                          DropdownMenuItem(
                                            value: "Inactive",
                                            child: Text("Inactive"),
                                          ),
                                        ],
                                        onChanged: _onFilterChanged,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 30),

                              // GRID OF SUPERVISORS
                              _filteredSupervisors.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 48,
                                        ),
                                        child: Text(
                                          'No supervisors found',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    )
                                  : LayoutBuilder(
                                      builder: (context, constraints) {
                                        int crossAxisCount = 3;

                                        if (constraints.maxWidth < 1100)
                                          crossAxisCount = 2;
                                        if (constraints.maxWidth < 700)
                                          crossAxisCount = 1;

                                        return GridView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: crossAxisCount,
                                                crossAxisSpacing: 20,
                                                mainAxisSpacing: 20,
                                                childAspectRatio: 2.8,
                                              ),
                                          itemCount:
                                              _filteredSupervisors.length,
                                          itemBuilder: (context, index) {
                                            return _supervisorCard(
                                              _filteredSupervisors[index],
                                            );
                                          },
                                        );
                                      },
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

  // ------------------------------------------------------
  // SUPERVISOR CARD WIDGET
  // ------------------------------------------------------
  Widget _supervisorCard(SupervisorInfo supervisor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: Image.asset(
              'assets/images/user.png',
              width: 55,
              height: 55,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(Icons.person, color: Colors.grey),
                );
              },
            ),
          ),

          const SizedBox(width: 14),

          // Info text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  supervisor.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  supervisor.email,
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  supervisor.phoneNumber,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // View profile button
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              side: const BorderSide(color: Colors.orange),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'View profile',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}

// SupervisorInfo class to hold supervisor data
class SupervisorInfo {
  final int supervisorId;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String status;

  SupervisorInfo({
    required this.supervisorId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.status,
  });

  String get name => '$firstName $lastName';
}
