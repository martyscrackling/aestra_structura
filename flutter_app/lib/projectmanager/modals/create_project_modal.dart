import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../../services/auth_service.dart';

class CreateProjectModal extends StatefulWidget {
  const CreateProjectModal({super.key});

  @override
  State<CreateProjectModal> createState() => _CreateProjectModalState();
}

class _CreateProjectModalState extends State<CreateProjectModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _streetController = TextEditingController();
  final _startDateController = TextEditingController();
  final _durationController = TextEditingController();
  final _budgetController = TextEditingController();
  bool _isSubmitting = false;
  String? _calculatedEndDate;

  // Address hierarchy state
  int? _selectedRegionId;
  int? _selectedProvinceId;
  int? _selectedCityId;
  int? _selectedBarangayId;

  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _barangays = [];
  List<Map<String, dynamic>> _supervisors = [];
  List<Map<String, dynamic>> _clients = [];

  bool _isLoadingRegions = false;
  bool _isLoadingSupervisors = false;
  bool _isLoadingClients = false;

  String? _selectedProjectType;
  int? _selectedClientId; // Store client_id instead of name
  int? _selectedSupervisorId; // Store supervisor_id instead of name
  XFile? _selectedImage;

  final List<String> _projectTypes = [
    'Residential',
    'Commercial',
    'Infrastructure',
    'Industrial',
  ];

  @override
  void initState() {
    super.initState();
    _fetchRegions();
    _fetchSupervisors();
    _fetchClients();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _streetController.dispose();
    _startDateController.dispose();
    _durationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _fetchRegions() async {
    try {
      setState(() => _isLoadingRegions = true);
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/regions/'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _regions = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('Error fetching regions: $e');
    } finally {
      setState(() => _isLoadingRegions = false);
    }
  }

  Future<void> _fetchProvinces(int regionId) async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/provinces/?region=$regionId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _provinces = data.cast<Map<String, dynamic>>();
          _selectedProvinceId = null;
          _cities = [];
          _barangays = [];
        });
      }
    } catch (e) {
      print('Error fetching provinces: $e');
    }
  }

  Future<void> _fetchCities(int provinceId) async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/cities/?province=$provinceId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _cities = data.cast<Map<String, dynamic>>();
          _selectedCityId = null;
          _barangays = [];
        });
      }
    } catch (e) {
      print('Error fetching cities: $e');
    }
  }

  Future<void> _fetchBarangays(int cityId) async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/barangays/?city=$cityId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _barangays = data.cast<Map<String, dynamic>>();
          _selectedBarangayId = null;
        });
      }
    } catch (e) {
      print('Error fetching barangays: $e');
    }
  }

  Future<void> _fetchSupervisors() async {
    try {
      setState(() => _isLoadingSupervisors = true);
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/supervisors/'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print(
          '📋 Supervisors API Response: ${data.isNotEmpty ? data[0] : 'empty'}',
        );
        setState(() {
          _supervisors = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('Error fetching supervisors: $e');
    } finally {
      setState(() => _isLoadingSupervisors = false);
    }
  }

  Future<void> _fetchClients() async {
    try {
      setState(() => _isLoadingClients = true);
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/clients/'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print(
          '📋 Clients API Response: ${data.isNotEmpty ? data[0] : 'empty'}',
        );
        setState(() {
          _clients = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('Error fetching clients: $e');
    } finally {
      setState(() => _isLoadingClients = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
        print('✅ Image selected: ${image.name}');
      } else {
        print('ℹ️ Image picker cancelled');
      }
    } catch (e) {
      print('❌ Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _calculateEndDate() {
    if (_startDateController.text.isEmpty || _durationController.text.isEmpty) {
      setState(() => _calculatedEndDate = null);
      return;
    }

    try {
      // Parse the start date from MM/DD/YYYY format
      final parts = _startDateController.text.split('/');
      if (parts.length == 3) {
        final month = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final startDate = DateTime(year, month, day);

        final duration = int.tryParse(_durationController.text) ?? 0;
        if (duration > 0) {
          final endDate = startDate.add(Duration(days: duration));
          setState(() {
            _calculatedEndDate =
                '${endDate.month.toString().padLeft(2, '0')}/${endDate.day.toString().padLeft(2, '0')}/${endDate.year}';
          });
        } else {
          setState(() => _calculatedEndDate = null);
        }
      }
    } catch (e) {
      print('Error calculating end date: $e');
      setState(() => _calculatedEndDate = null);
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        controller.text =
            '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
      });
      // Recalculate end date when start date changes
      _calculateEndDate();
    }
  }

  String _convertDateFormat(String dateStr) {
    // Convert MM/DD/YYYY to YYYY-MM-DD
    if (dateStr.isEmpty) return '';
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final month = parts[0].padLeft(2, '0');
        final day = parts[1].padLeft(2, '0');
        final year = parts[2];
        return '$year-$month-$day';
      }
      return dateStr;
    } catch (e) {
      print('Error converting date: $e');
      return dateStr;
    }
  }

  Future<String?> _saveImageToAssets(String projectId) async {
    if (_selectedImage == null) {
      print('❌ No image selected');
      return null;
    }
    try {
      // Create the full path to assets/images/project_images
      final projectDir = Directory('assets/images/project_images');
      print('📁 Creating directory: ${projectDir.path}');

      if (!projectDir.existsSync()) {
        projectDir.createSync(recursive: true);
      }

      // Create filename using project_id
      final fileName = 'project_$projectId.jpg';
      final filePath = 'assets/images/project_images/$fileName';
      final fullPath = projectDir.path + Platform.pathSeparator + fileName;

      // Copy the selected image file
      final sourceFile = File(_selectedImage!.path);
      print('📸 Source: ${sourceFile.path}');
      print('📍 Destination: $fullPath');

      await sourceFile.copy(fullPath);
      print('✓ Image saved successfully!');

      return filePath;
    } catch (e) {
      print('❌ Error saving image: $e');
      return null;
    }
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        // Get user_id from auth service
        final authService = AuthService();
        final userId = authService.currentUser?['user_id'];

        if (userId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: User not logged in'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isSubmitting = false);
          return;
        }

        // Convert dates to YYYY-MM-DD format
        final startDate = _convertDateFormat(_startDateController.text);
        final endDate = _convertDateFormat(_calculatedEndDate ?? '');

        // Step 1: Create project WITHOUT image path first
        final payload = {
          'project_name': _nameController.text,
          'description': _descriptionController.text,
          'street': _streetController.text,
          'project_type': _selectedProjectType,
          'start_date': startDate,
          'end_date': endDate,
          'duration_days': int.tryParse(_durationController.text) ?? 0,
          'client': _selectedClientId,
          'supervisor': _selectedSupervisorId,
          'budget': double.tryParse(_budgetController.text) ?? 0.0,
          'region': _selectedRegionId,
          'province': _selectedProvinceId,
          'city': _selectedCityId,
          'barangay': _selectedBarangayId,
          'status': 'Planning',
          'project_image': null,
          'user_id': userId,
        };

        print('🚀 Step 1: Creating project without image...');
        print('Payload: ${jsonEncode(payload)}');

        final response = await http
            .post(
              Uri.parse('http://127.0.0.1:8000/api/projects/'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 10));

        print('✓ Response status: ${response.statusCode}');
        print('✓ Response body: ${response.body}');

        if (!mounted) return;

        if (response.statusCode != 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${response.statusCode} - ${response.body}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isSubmitting = false);
          return;
        }

        // Step 2: Parse response and get project_id
        final responseData = jsonDecode(response.body);
        final projectId = responseData['project_id'];
        print('✅ Project created with ID: $projectId');

        // Step 3: Save image if selected
        String? imagePath;
        if (_selectedImage != null) {
          print('🚀 Step 2: Saving image file...');
          imagePath = await _saveImageToAssets(projectId.toString());

          if (imagePath != null) {
            print('✅ Image saved to: $imagePath');

            // Step 4: Update project with image path
            print('🚀 Step 3: Updating project with image path...');
            final updatePayload = {'project_image': imagePath};

            final updateResponse = await http
                .patch(
                  Uri.parse('http://127.0.0.1:8000/api/projects/$projectId/'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(updatePayload),
                )
                .timeout(const Duration(seconds: 10));

            print('✓ Update response status: ${updateResponse.statusCode}');
            print('✓ Update response body: ${updateResponse.body}');
          }
        }

        // Step 5: Show success dialog
        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF059669),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'New Project Added',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_nameController.text} has been successfully created.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A18),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
        setState(() => _isSubmitting = false);
      } catch (e) {
        print('❌ Error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Network error: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 800),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  const Text(
                    'Create a Project',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0C1935),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: Colors.grey[600],
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Project Image Section
                      const Text(
                        'Project\'s Image',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0C1935),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Image format: jpg, jpeg, png and minimum size 300 x 300px',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (_selectedImage != null)
                            Container(
                              width: 100,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(File(_selectedImage!.path)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 100,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.image,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                              ),
                            ),
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blue),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: const [
                                  Icon(
                                    Icons.cloud_upload_outlined,
                                    color: Colors.blue,
                                    size: 28,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'New Image',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Project Information
                      const Text(
                        'Project\'s information',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0C1935),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Project Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Enter Project\'s name',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter project name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Project Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Enter Project Description (Optional)',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
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
                      const SizedBox(height: 12),

                      // Address - Cascading Dropdowns
                      const Text(
                        'Project Address',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0C1935),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Region Dropdown
                      _isLoadingRegions
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<int>(
                              value: _selectedRegionId,
                              decoration: InputDecoration(
                                hintText: 'Select Region',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF9FAFB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                              ),
                              items: _regions.map((region) {
                                return DropdownMenuItem<int>(
                                  value: region['id'] as int,
                                  child: Text(region['name'] as String),
                                );
                              }).toList(),
                              onChanged: (int? value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedRegionId = value;
                                  });
                                  _fetchProvinces(value);
                                }
                              },
                            ),
                      const SizedBox(height: 12),

                      // Province Dropdown
                      DropdownButtonFormField<int>(
                        value: _selectedProvinceId,
                        decoration: InputDecoration(
                          hintText: 'Select Province',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        items: _provinces.map((province) {
                          return DropdownMenuItem<int>(
                            value: province['id'] as int,
                            child: Text(province['name'] as String),
                          );
                        }).toList(),
                        onChanged: (int? value) {
                          if (value != null) {
                            setState(() {
                              _selectedProvinceId = value;
                            });
                            _fetchCities(value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // City Dropdown
                      DropdownButtonFormField<int>(
                        value: _selectedCityId,
                        decoration: InputDecoration(
                          hintText: 'Select City',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        items: _cities.map((city) {
                          return DropdownMenuItem<int>(
                            value: city['id'] as int,
                            child: Text(city['name'] as String),
                          );
                        }).toList(),
                        onChanged: (int? value) {
                          if (value != null) {
                            setState(() {
                              _selectedCityId = value;
                            });
                            _fetchBarangays(value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Barangay Dropdown
                      DropdownButtonFormField<int>(
                        value: _selectedBarangayId,
                        decoration: InputDecoration(
                          hintText: 'Select Barangay',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        items: _barangays.map((barangay) {
                          return DropdownMenuItem<int>(
                            value: barangay['id'] as int,
                            child: Text(barangay['name'] as String),
                          );
                        }).toList(),
                        onChanged: (int? value) {
                          setState(() {
                            _selectedBarangayId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Street Address
                      TextFormField(
                        controller: _streetController,
                        decoration: InputDecoration(
                          hintText: 'Enter Street Address (Optional)',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
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
                      const SizedBox(height: 12),

                      // Project Type
                      DropdownButtonFormField<String>(
                        value: _selectedProjectType,
                        decoration: InputDecoration(
                          hintText: 'Project type',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        items: _projectTypes.map((String type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedProjectType = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select project type';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Start Date and End Date
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Start Date',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0C1935),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _startDateController,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    hintText: 'September 28, 2025',
                                    hintStyle: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[400],
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF9FAFB),
                                    suffixIcon: const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                  ),
                                  onTap: () => _selectDate(
                                    context,
                                    _startDateController,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Duration (Days)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0C1935),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _durationController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Enter days',
                                    hintStyle: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[400],
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF9FAFB),
                                    suffixIcon: const Icon(
                                      Icons.timer_outlined,
                                      size: 18,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                  ),
                                  onChanged: (value) => _calculateEndDate(),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    if (int.tryParse(value) == null ||
                                        int.parse(value) <= 0) {
                                      return 'Enter valid days';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Show calculated end date
                      if (_calculatedEndDate != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.event_available,
                                size: 18,
                                color: Color(0xFF2E7D32),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Expected End Date: $_calculatedEndDate',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Client
                      _isLoadingClients
                          ? const CircularProgressIndicator()
                          : DropdownButtonFormField<int>(
                              value: _selectedClientId,
                              decoration: InputDecoration(
                                hintText: 'Select client',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF9FAFB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                              ),
                              items: _clients
                                  .where(
                                    (client) =>
                                        (client['client_id'] as int?) != null &&
                                        (client['client_id'] as int) > 0,
                                  )
                                  .map((client) {
                                    final clientId = client['client_id'] as int;
                                    final firstName =
                                        client['first_name'] as String? ?? '';
                                    final lastName =
                                        client['last_name'] as String? ?? '';
                                    final displayName = '$firstName $lastName'
                                        .trim();
                                    return DropdownMenuItem<int>(
                                      value: clientId,
                                      child: Text(
                                        displayName.isEmpty
                                            ? 'Unknown'
                                            : displayName,
                                      ),
                                    );
                                  })
                                  .toList(),
                              onChanged: (int? newValue) {
                                setState(() {
                                  _selectedClientId = newValue;
                                });
                              },
                            ),
                      const SizedBox(height: 12),

                      // Supervisor in-charge
                      _isLoadingSupervisors
                          ? const CircularProgressIndicator()
                          : DropdownButtonFormField<int>(
                              value: _selectedSupervisorId,
                              decoration: InputDecoration(
                                hintText: 'Select supervisor',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF9FAFB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                              ),
                              items: _supervisors
                                  .where(
                                    (supervisor) =>
                                        (supervisor['supervisor_id'] as int?) !=
                                            null &&
                                        (supervisor['supervisor_id'] as int) >
                                            0,
                                  )
                                  .map((supervisor) {
                                    final supervisorId =
                                        supervisor['supervisor_id'] as int;
                                    final firstName =
                                        supervisor['first_name'] as String? ??
                                        '';
                                    final lastName =
                                        supervisor['last_name'] as String? ??
                                        '';
                                    final displayName = '$firstName $lastName'
                                        .trim();
                                    return DropdownMenuItem<int>(
                                      value: supervisorId,
                                      child: Text(
                                        displayName.isEmpty
                                            ? 'Unknown'
                                            : displayName,
                                      ),
                                    );
                                  })
                                  .toList(),
                              onChanged: (int? newValue) {
                                setState(() {
                                  _selectedSupervisorId = newValue;
                                });
                              },
                            ),
                      const SizedBox(height: 12),

                      // Budget
                      TextFormField(
                        controller: _budgetController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Enter Project Budget',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          prefixText: '₱ ',
                          prefixStyle: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF0C1935),
                            fontWeight: FontWeight.w600,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter project budget';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFFFF7A18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Next',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
