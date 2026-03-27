import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../../services/auth_service.dart';
import '../../services/app_config.dart';
import '../../services/date_utils.dart' as ph_date_utils;

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
  int _sundayCount = 0;
  int _holidayCount = 0;

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
      final response = await http.get(AppConfig.apiUri('regions/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _regions = data.cast<Map<String, dynamic>>();

          // Set default region to Region IX - Zamboanga Peninsula
          final defaultRegion = _regions.firstWhere(
            (r) => r['id'] == 10, // or r['code'] == '090000000'
          );

          if (defaultRegion != null) {
            _selectedRegionId = defaultRegion['id'];
            _fetchProvinces(
              _selectedRegionId!,
            ); // load provinces for default region
          } else {
            _selectedRegionId = 10; // fallback if region not found
          }
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
        AppConfig.apiUri('provinces/?region=$regionId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _provinces = data.cast<Map<String, dynamic>>();
          _cities = [];
          _barangays = [];

          // Set default province (id = 50)
          Map<String, dynamic>? defaultProvince = _provinces.firstWhere(
            (p) => p['id'] == 50, // or p['code'] == '097300000'
          );

          if (defaultProvince != null) {
            _selectedProvinceId = defaultProvince['id'];
            _fetchCities(
              _selectedProvinceId!,
            ); // load cities for default province
          } else {
            _selectedProvinceId = null;
          }
        });
      }
    } catch (e) {
      print('Error fetching provinces: $e');
    }
  }

  Future<void> _fetchCities(int provinceId) async {
    try {
      final response = await http.get(
        AppConfig.apiUri('cities/?province=$provinceId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _cities = data.cast<Map<String, dynamic>>();
          _barangays = [];

          // Set default city (id = 825)
          Map<String, dynamic>? defaultCity = _cities.firstWhere(
            (c) => c['id'] == 825, // or c['code'] == '097302000'
          );

          if (defaultCity != null) {
            _selectedCityId = defaultCity['id'];
            _fetchBarangays(
              _selectedCityId!,
            ); // load barangays for default city
          } else {
            _selectedCityId = null;
          }
        });
      }
    } catch (e) {
      print('Error fetching cities: $e');
    }
  }

  Future<void> _fetchBarangays(int cityId) async {
    try {
      final response = await http.get(
        AppConfig.apiUri('barangays/?city=$cityId'),
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
      final userId = AuthService().currentUser?['user_id'];
      final uri = (userId != null)
          ? AppConfig.apiUri('supervisors/?user_id=$userId')
          : AppConfig.apiUri('supervisors/');
      final response = await http.get(uri);
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
      final userId = AuthService().currentUser?['user_id'];
      final uri = (userId != null)
          ? AppConfig.apiUri('clients/?user_id=$userId')
          : AppConfig.apiUri('clients/');
      final response = await http.get(uri);
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
      setState(() {
        _calculatedEndDate = null;
        _sundayCount = 0;
        _holidayCount = 0;
      });
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
          // Calculate end date excluding Sundays and holidays (working days only)
          final endDate = ph_date_utils.PhilippineDateUtils
              .calculateEndDateExcludingNonWorkingDays(startDate, duration);
          
          // Calculate Sundays and Philippine holidays in the calendar range
          final sundays = ph_date_utils.PhilippineDateUtils.countSundays(startDate, endDate);
          final holidays = ph_date_utils.PhilippineDateUtils.countPhilippineHolidays(startDate, endDate);
          
          setState(() {
            _calculatedEndDate =
                '${endDate.month.toString().padLeft(2, '0')}/${endDate.day.toString().padLeft(2, '0')}/${endDate.year}';
            _sundayCount = sundays;
            _holidayCount = holidays;
          });
        } else {
          setState(() {
            _calculatedEndDate = null;
            _sundayCount = 0;
            _holidayCount = 0;
          });
        }
      }
    } catch (e) {
      print('Error calculating end date: $e');
      setState(() {
        _calculatedEndDate = null;
        _sundayCount = 0;
        _holidayCount = 0;
      });
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today, // Only allow today or future
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

  MediaType _guessImageMediaType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    if (lower.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    if (lower.endsWith('.gif')) {
      return MediaType('image', 'gif');
    }
    return MediaType('image', 'jpeg');
  }

  Future<String?> _uploadProjectImage(String projectId, int userId) async {
    if (_selectedImage == null) {
      print('❌ No image selected');
      return null;
    }

    try {
      // Always upload to backend. Saving into Flutter assets at runtime is not reliable.
      final uri = AppConfig.apiUri(
        'projects/$projectId/upload_image/?user_id=$userId',
      );
      final request = http.MultipartRequest('POST', uri);

      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            await _selectedImage!.readAsBytes(),
            filename: _selectedImage!.name,
            contentType: _guessImageMediaType(_selectedImage!.name),
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('image', _selectedImage!.path),
        );
      }

      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final respData = jsonDecode(respStr);
        final url = respData['url'] as String?;
        print('✓ Image uploaded: $url');
        return url;
      }

      final errorBody = await response.stream.bytesToString();
      final message =
          'Image upload failed (${response.statusCode}). $errorBody';
      print('❌ $message');
      throw Exception(message);
    } catch (e) {
      print('❌ Error uploading image: $e');
      rethrow;
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
              AppConfig.apiUri('projects/'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 30));

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

        // Step 3: Upload image if selected
        String? uploadedImageUrl;
        bool imageUploadFailed = false;
        if (_selectedImage != null) {
          print('🚀 Step 2: Uploading image...');
          try {
            uploadedImageUrl = await _uploadProjectImage(
              projectId.toString(),
              userId,
            );
            if (uploadedImageUrl != null) {
              print('✅ Image uploaded to: $uploadedImageUrl');
            }
          } catch (e) {
            imageUploadFailed = true;
            print('⚠️ Project created, but image upload failed.');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Project created, but image failed: $e'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
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
                    if (_selectedImage != null)
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          color: const Color(0xFFD1FAE5),
                        ),
                        child: ClipOval(
                          child: kIsWeb
                              ? Image.network(
                                  _selectedImage!.path,
                                  fit: BoxFit.cover,
                                  width: 80,
                                  height: 80,
                                )
                              : Image.file(
                                  File(_selectedImage!.path),
                                  fit: BoxFit.cover,
                                  width: 80,
                                  height: 80,
                                ),
                        ),
                      )
                    else
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
                    Text(
                      imageUploadFailed
                          ? 'Project Added (No Image)'
                          : 'New Project Added',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      imageUploadFailed
                          ? '${_nameController.text} was created, but the image was not uploaded.'
                          : '${_nameController.text} has been successfully created.',
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;

    // Reusable form fields column (used in both mobile and desktop layouts)
    Widget formFields = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            labelText: 'Project Name',
            labelStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0C1935), width: 2),
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
            labelText: 'Project Description (Optional)',
            labelStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0C1935), width: 2),
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
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Region',
                  labelStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF0C1935),
                      width: 2,
                    ),
                  ),
                ),
                items: _regions.map((region) {
                  return DropdownMenuItem<int>(
                    value: region['id'] as int,
                    child: Text(
                      region['name'] as String,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
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
            labelText: 'Province',
            labelStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0C1935), width: 2),
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
            labelText: 'City',
            labelStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0C1935), width: 2),
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
            labelText: 'Barangay',
            labelStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0C1935), width: 2),
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
            labelText: 'Street Address (Optional)',
            labelStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0C1935), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Project Type
        DropdownButtonFormField<String>(
          value: _selectedProjectType,
          decoration: InputDecoration(
            labelText: 'Project Type',
            labelStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0C1935), width: 2),
            ),
          ),
          items: _projectTypes.map((String type) {
            return DropdownMenuItem<String>(value: type, child: Text(type));
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
                      labelText: 'Start Date',
                      labelStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      suffixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF0C1935),
                          width: 2,
                        ),
                      ),
                    ),
                    onTap: () => _selectDate(context, _startDateController),
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
                      labelText: 'Duration (Days)',
                      labelStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      suffixIcon: const Icon(Icons.timer_outlined, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF0C1935),
                          width: 2,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_note,
                            size: 16,
                            color: Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Sundays: $_sundayCount',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.celebration,
                            size: 16,
                            color: Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Holidays: $_holidayCount',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  labelText: 'Client',
                  labelStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF0C1935),
                      width: 2,
                    ),
                  ),
                ),
                items: (() {
                  final filteredClients = _clients
                      .where(
                        (client) =>
                            (client['client_id'] as int?) != null &&
                            (client['client_id'] as int) > 0,
                      )
                      .toList();

                  // Sort alphabetically by name
                  filteredClients.sort((a, b) {
                    final nameA =
                        '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'
                            .trim()
                            .toLowerCase();
                    final nameB =
                        '${b['first_name'] ?? ''} ${b['last_name'] ?? ''}'
                            .trim()
                            .toLowerCase();
                    return nameA.compareTo(nameB);
                  });

                  return filteredClients.map((client) {
                    final clientId = client['client_id'] as int;
                    final firstName = client['first_name'] as String? ?? '';
                    final lastName = client['last_name'] as String? ?? '';
                    final displayName = '$firstName $lastName'.trim();
                    return DropdownMenuItem<int>(
                      value: clientId,
                      child: Text(
                        displayName.isEmpty ? 'Unknown' : displayName,
                      ),
                    );
                  }).toList();
                })(),
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
                  labelText: 'Supervisor',
                  labelStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF0C1935),
                      width: 2,
                    ),
                  ),
                ),
                items: (() {
                  final filteredSupervisors = _supervisors
                      .where(
                        (supervisor) =>
                            (supervisor['supervisor_id'] as int?) != null &&
                            (supervisor['supervisor_id'] as int) > 0,
                      )
                      .toList();

                  // Sort alphabetically by name
                  filteredSupervisors.sort((a, b) {
                    final nameA =
                        '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'
                            .trim()
                            .toLowerCase();
                    final nameB =
                        '${b['first_name'] ?? ''} ${b['last_name'] ?? ''}'
                            .trim()
                            .toLowerCase();
                    return nameA.compareTo(nameB);
                  });

                  return filteredSupervisors.map((supervisor) {
                    final supervisorId = supervisor['supervisor_id'] as int;
                    final firstName = supervisor['first_name'] as String? ?? '';
                    final lastName = supervisor['last_name'] as String? ?? '';
                    final displayName = '$firstName $lastName'.trim();
                    return DropdownMenuItem<int>(
                      value: supervisorId,
                      child: Text(
                        displayName.isEmpty ? 'Unknown' : displayName,
                      ),
                    );
                  }).toList();
                })(),
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
            labelText: 'Project Budget',
            labelStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0C1935), width: 2),
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
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: isMobile ? 24 : 40,
      ),
      child: Container(
        width: isMobile ? double.infinity : 700,
        constraints: BoxConstraints(
          maxHeight: isMobile ? screenHeight * 0.9 : 650,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Text(
                    'Create a Project',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0C1935),
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
              child: isMobile
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Image on top for mobile
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _selectedImage == null
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.image_outlined,
                                          size: 40,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Upload photo',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    )
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: kIsWeb
                                          ? Image.network(
                                              _selectedImage!.path,
                                              fit: BoxFit.cover,
                                              width: 120,
                                              height: 120,
                                            )
                                          : Image.file(
                                              File(_selectedImage!.path),
                                              fit: BoxFit.cover,
                                              width: 120,
                                              height: 120,
                                            ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Form(key: _formKey, child: formFields),
                        ],
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left side - Image (Desktop)
                        Container(
                          width: 240,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: 192,
                                  height: 280,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: _selectedImage == null
                                      ? Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.image_outlined,
                                              size: 60,
                                              color: Colors.grey[400],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Click to upload photo',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        )
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: kIsWeb
                                              ? Image.network(
                                                  _selectedImage!.path,
                                                  fit: BoxFit.cover,
                                                  width: 192,
                                                  height: 280,
                                                )
                                              : Image.file(
                                                  File(_selectedImage!.path),
                                                  fit: BoxFit.cover,
                                                  width: 192,
                                                  height: 280,
                                                ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Divider
                        Container(width: 1, color: const Color(0xFFE5E7EB)),

                        // Right side - Form (Desktop)
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Form(key: _formKey, child: formFields),
                          ),
                        ),
                      ],
                    ),
            ),

            // Footer Buttons
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: isMobile
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
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
                                    'Create Project',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
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
                      ],
                    )
                  : Row(
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
                                    'Create Project',
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
