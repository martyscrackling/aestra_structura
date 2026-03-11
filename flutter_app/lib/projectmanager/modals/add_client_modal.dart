import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/subscription_helper.dart';

class AddClientModal extends StatefulWidget {
  const AddClientModal({super.key});

  @override
  State<AddClientModal> createState() => _AddClientModalState();
}

class _AddClientModalState extends State<AddClientModal> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _generatedEmailController = TextEditingController();
  final _passwordController = TextEditingController();

  int? _selectedRegionId;
  int? _selectedProvinceId;
  int? _selectedCityId;
  int? _selectedBarangayId;

  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _barangays = [];

  bool _isLoadingRegions = false;

  Uint8List? _selectedImageBytes;
  String? _selectedImageFilename;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _passwordController.text = 'PASSWORD';
    _fetchRegions();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneNumberController.dispose();
    _birthdateController.dispose();
    _generatedEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageFilename = image.name;
      });
    }
  }

  Future<void> _fetchRegions() async {
    try {
      setState(() => _isLoadingRegions = true);
      final response = await http.get(AppConfig.apiUri('regions/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final regions = data.cast<Map<String, dynamic>>();

        final regionIndex = regions.indexWhere((r) => r['id'] == 10);
        final regionId = regionIndex >= 0
            ? (regions[regionIndex]['id'] as int?)
            : null;

        setState(() {
          _regions = regions;
          _selectedRegionId = regionId;
        });

        if (regionId != null) {
          await _fetchProvinces(regionId);
        }
      }
    } catch (e) {
      debugPrint('Error fetching regions: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingRegions = false);
      }
    }
  }

  Future<void> _fetchProvinces(int regionId) async {
    try {
      final response = await http.get(
        AppConfig.apiUri('provinces/?region=$regionId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final provinces = data.cast<Map<String, dynamic>>();

        final provinceIndex = provinces.indexWhere((p) => p['id'] == 50);
        final provinceId = provinceIndex >= 0
            ? (provinces[provinceIndex]['id'] as int?)
            : null;

        setState(() {
          _provinces = provinces;
          _selectedProvinceId = provinceId;
          _cities = [];
          _selectedCityId = null;
          _barangays = [];
          _selectedBarangayId = null;
        });

        if (provinceId != null) {
          await _fetchCities(provinceId);
        }
      }
    } catch (e) {
      debugPrint('Error fetching provinces: $e');
    }
  }

  Future<void> _fetchCities(int provinceId) async {
    try {
      final response = await http.get(
        AppConfig.apiUri('cities/?province=$provinceId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final cities = data.cast<Map<String, dynamic>>();

        final cityIndex = cities.indexWhere((c) => c['id'] == 825);
        final cityId = cityIndex >= 0
            ? (cities[cityIndex]['id'] as int?)
            : null;

        setState(() {
          _cities = cities;
          _selectedCityId = cityId;
          _barangays = [];
          _selectedBarangayId = null;
        });

        if (cityId != null) {
          await _fetchBarangays(cityId);
        }
      }
    } catch (e) {
      debugPrint('Error fetching cities: $e');
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
      debugPrint('Error fetching barangays: $e');
    }
  }

  Future<void> _uploadClientPhoto({
    required int clientId,
    required int pmUserId,
  }) async {
    if (_selectedImageBytes == null) return;

    final uri = AppConfig.apiUri(
      'clients/$clientId/upload-photo/?user_id=$pmUserId',
    );

    final request = http.MultipartRequest('POST', uri);
    request.headers['X-User-Id'] = pmUserId.toString();
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        _selectedImageBytes!,
        filename: _selectedImageFilename ?? 'client_photo.jpg',
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    debugPrint('Upload photo status: ${response.statusCode}');
    debugPrint('Upload photo body: ${response.body}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Failed to upload photo';
      try {
        final errorData = jsonDecode(response.body);
        message =
            errorData['detail'] ??
            errorData['error'] ??
            errorData.toString() ??
            message;
      } catch (_) {
        // ignore
      }
      throw Exception(message);
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    IconData? suffixIcon,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          onChanged: onChanged,
          onTap: onTap,
          decoration: InputDecoration(
            labelText: hintText,
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(suffixIcon, color: Colors.grey[400], size: 18),
                  )
                : null,
          ),
          validator: validator,
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final currentUserId = AuthService().currentUser?['user_id'];
        final pmUserId = currentUserId is int
            ? currentUserId
            : int.tryParse(currentUserId?.toString() ?? '');

        if (pmUserId == null) {
          throw Exception('Missing current user_id');
        }

        final clientData = {
          'invited_by_email': AuthService().currentUser?['email'],
          'invited_by_name':
              '${AuthService().currentUser?['first_name'] ?? ''} ${AuthService().currentUser?['last_name'] ?? ''}'
                  .trim(),
          'first_name': _firstNameController.text.trim(),
          'middle_name': _middleNameController.text.trim().isEmpty
              ? null
              : _middleNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'email': _generatedEmailController.text.trim(),
          'password_hash': _passwordController.text
              .trim(), // Include password for hashing
          'phone_number': _phoneNumberController.text.trim(),
          'birthdate': _birthdateController.text.trim().isEmpty
              ? null
              : _birthdateController.text.trim(),
          'region': _selectedRegionId,
          'province': _selectedProvinceId,
          'city': _selectedCityId,
          'barangay': _selectedBarangayId,
        };

        debugPrint('Sending client data: $clientData');

        final response = await http.post(
          AppConfig.apiUri('clients/'),
          headers: {
            'Content-Type': 'application/json',
            'X-User-Id': pmUserId.toString(),
          },
          body: jsonEncode(clientData),
        );

        debugPrint('Response status: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');

        if (!mounted) return;

        // Check for subscription expiry first
        if (SubscriptionHelper.handleResponse(context, response)) {
          setState(() {
            _isLoading = false;
          });
          return;
        }

        if (response.statusCode == 201 || response.statusCode == 200) {
          int? clientId;
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic>) {
              final rawId = decoded['client_id'];
              clientId = rawId is int
                  ? rawId
                  : int.tryParse(rawId?.toString() ?? '');
            }
          } catch (_) {
            // ignore
          }

          String successMessage = 'Client added successfully!';

          if (_selectedImageBytes != null && clientId != null) {
            try {
              await _uploadClientPhoto(clientId: clientId, pmUserId: pmUserId);
            } catch (e) {
              successMessage =
                  'Client added, but photo upload failed: ${e.toString()}';
            }
          }

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(successMessage)));
          Navigator.of(context).pop();
        } else {
          try {
            final errorData = jsonDecode(response.body);
            final errorMessage =
                errorData['detail'] ??
                errorData['error'] ??
                errorData.toString() ??
                'Failed to add client';
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: $errorMessage')));
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: Failed to add client')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;

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
                    'Add a client',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20,
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
                                image: _selectedImageBytes != null
                                    ? DecorationImage(
                                        image: MemoryImage(
                                          _selectedImageBytes!,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _selectedImageBytes == null
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.person_outline,
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
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Form for mobile
                          const Text(
                            'Personal Information',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0C1935),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // First Name
                                _buildTextField(
                                  controller: _firstNameController,
                                  hintText: 'First Name',
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Middle Name
                                _buildTextField(
                                  controller: _middleNameController,
                                  hintText: 'Middle Name (Optional)',
                                ),
                                const SizedBox(height: 12),

                                // Last Name
                                _buildTextField(
                                  controller: _lastNameController,
                                  hintText: 'Last Name',
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Generated Account Email
                                _buildTextField(
                                  controller: _generatedEmailController,
                                  hintText: 'Email (Gmail)',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Generated Password
                                _buildTextField(
                                  controller: _passwordController,
                                  hintText: 'Password (Default)',
                                  readOnly: true,
                                ),
                                const SizedBox(height: 12),

                                // Phone Number
                                _buildTextField(
                                  controller: _phoneNumberController,
                                  hintText: 'Phone Number',
                                  keyboardType: TextInputType.phone,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Birthdate
                                _buildTextField(
                                  controller: _birthdateController,
                                  hintText: 'Birthdate (Optional)',
                                  readOnly: true,
                                  suffixIcon: Icons.calendar_today_outlined,
                                  onTap: () => _selectDate(
                                    context,
                                    _birthdateController,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                const Text(
                                  'Address',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0C1935),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                _isLoadingRegions
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : DropdownButtonFormField<int>(
                                        value: _selectedRegionId,
                                        decoration: InputDecoration(
                                          labelText: 'Region',
                                          labelStyle: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFFF9FAFB),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey[300]!,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey[300]!,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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

                                DropdownButtonFormField<int>(
                                  value: _selectedProvinceId,
                                  decoration: InputDecoration(
                                    labelText: 'Province',
                                    labelStyle: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
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
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF0C1935),
                                        width: 2,
                                      ),
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

                                DropdownButtonFormField<int>(
                                  value: _selectedCityId,
                                  decoration: InputDecoration(
                                    labelText: 'City',
                                    labelStyle: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
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
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF0C1935),
                                        width: 2,
                                      ),
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

                                DropdownButtonFormField<int>(
                                  value: _selectedBarangayId,
                                  decoration: InputDecoration(
                                    labelText: 'Barangay',
                                    labelStyle: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
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
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF0C1935),
                                        width: 2,
                                      ),
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left side - Image (Desktop)
                        Container(
                          width: 280,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: 200,
                                  height: 280,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                    image: _selectedImageBytes != null
                                        ? DecorationImage(
                                            image: MemoryImage(
                                              _selectedImageBytes!,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _selectedImageBytes == null
                                      ? Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.person_outline,
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
                                      : null,
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
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Personal Information',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0C1935),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // First Name
                                  _buildTextField(
                                    controller: _firstNameController,
                                    hintText: 'First Name',
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Middle Name
                                  _buildTextField(
                                    controller: _middleNameController,
                                    hintText: 'Middle Name (Optional)',
                                  ),
                                  const SizedBox(height: 16),

                                  // Last Name
                                  _buildTextField(
                                    controller: _lastNameController,
                                    hintText: 'Last Name',
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Generated Account Email
                                  _buildTextField(
                                    controller: _generatedEmailController,
                                    hintText: 'Email (Gmail)',
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Generated Password
                                  _buildTextField(
                                    controller: _passwordController,
                                    hintText: 'Password (Default)',
                                    readOnly: true,
                                  ),
                                  const SizedBox(height: 16),

                                  // Phone Number
                                  _buildTextField(
                                    controller: _phoneNumberController,
                                    hintText: 'Phone Number',
                                    keyboardType: TextInputType.phone,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Birthdate
                                  _buildTextField(
                                    controller: _birthdateController,
                                    hintText: 'Birthdate (Optional)',
                                    readOnly: true,
                                    suffixIcon: Icons.calendar_today_outlined,
                                    onTap: () => _selectDate(
                                      context,
                                      _birthdateController,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  const Text(
                                    'Address',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0C1935),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  _isLoadingRegions
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : DropdownButtonFormField<int>(
                                          value: _selectedRegionId,
                                          decoration: InputDecoration(
                                            labelText: 'Region',
                                            labelStyle: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                            filled: true,
                                            fillColor: const Color(0xFFF9FAFB),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: Colors.grey[300]!,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: Colors.grey[300]!,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                  const SizedBox(height: 16),

                                  DropdownButtonFormField<int>(
                                    value: _selectedProvinceId,
                                    decoration: InputDecoration(
                                      labelText: 'Province',
                                      labelStyle: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
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
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF0C1935),
                                          width: 2,
                                        ),
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
                                  const SizedBox(height: 16),

                                  DropdownButtonFormField<int>(
                                    value: _selectedCityId,
                                    decoration: InputDecoration(
                                      labelText: 'City',
                                      labelStyle: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
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
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF0C1935),
                                          width: 2,
                                        ),
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
                                  const SizedBox(height: 16),

                                  DropdownButtonFormField<int>(
                                    value: _selectedBarangayId,
                                    decoration: InputDecoration(
                                      labelText: 'Barangay',
                                      labelStyle: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
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
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF0C1935),
                                          width: 2,
                                        ),
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
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
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
                            onPressed: _isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: const Color(0xFFFF7A18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
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
                                    'Add Client',
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
                            onPressed: _isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: const Color(0xFFFF7A18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
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
                                    'Add Client',
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
