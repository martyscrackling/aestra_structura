import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/app_config.dart';
import '../../services/auth_service.dart';

class AddFieldWorkerModal extends StatefulWidget {
  final String workerType;
  final int? projectId;

  const AddFieldWorkerModal({
    super.key,
    required this.workerType,
    this.projectId,
  });

  @override
  State<AddFieldWorkerModal> createState() => _AddFieldWorkerModalState();
}

class _AddFieldWorkerModalState extends State<AddFieldWorkerModal> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _sssIdController = TextEditingController();
  final _philHealthIdController = TextEditingController();
  final _pagIbigIdController = TextEditingController();
  final _payrateController = TextEditingController();
  final _customRoleController = TextEditingController();

  String _selectedRole = 'Mason';
  bool _isCustomRole = false;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isLoading = false;

  // Address hierarchy state
  int? _selectedRegionId;
  int? _selectedProvinceId;
  int? _selectedCityId;
  int? _selectedBarangayId;

  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _barangays = [];

  bool _isLoadingRegions = false;

  @override
  void initState() {
    super.initState();
    _fetchRegions();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneNumberController.dispose();
    _birthdateController.dispose();
    _sssIdController.dispose();
    _philHealthIdController.dispose();
    _pagIbigIdController.dispose();
    _payrateController.dispose();
    _customRoleController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
      });
    }
  }

  Future<void> _uploadFieldWorkerPhoto({
    required int fieldWorkerId,
    required int? currentUserId,
  }) async {
    if (_selectedImageBytes == null || _selectedImage == null) return;

    final query = <String, String>{};
    // If the caller is a Supervisor (no real PM user id available), the backend
    // allows scoping by project_id.
    if (currentUserId == null && widget.projectId != null) {
      query['project_id'] = widget.projectId.toString();
    }

    final uploadUri = AppConfig.apiUri(
      query.isEmpty
          ? 'field-workers/$fieldWorkerId/upload-photo/'
          : 'field-workers/$fieldWorkerId/upload-photo/?${Uri(queryParameters: query).query}',
    );

    final request = http.MultipartRequest('POST', uploadUri);
    if (currentUserId != null) {
      request.headers['X-User-Id'] = currentUserId.toString();
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        _selectedImageBytes!,
        filename: _selectedImage!.name,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200 && response.statusCode != 201) {
      String message = 'Failed to upload photo';
      try {
        final parsed = jsonDecode(response.body);
        message =
            (parsed is Map &&
                (parsed['detail'] != null || parsed['error'] != null))
            ? (parsed['detail'] ?? parsed['error']).toString()
            : message;
      } catch (_) {}
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

  Future<void> _fetchRegions() async {
    try {
      setState(() => _isLoadingRegions = true);
      final response = await http.get(AppConfig.apiUri('regions/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final regions = data.cast<Map<String, dynamic>>();

        int? defaultRegionId;
        final defaultRegionIndex = regions.indexWhere((r) => r['id'] == 10);
        if (defaultRegionIndex >= 0) {
          defaultRegionId = regions[defaultRegionIndex]['id'] as int;
        }

        setState(() {
          _regions = regions;
          _selectedRegionId = defaultRegionId ?? _selectedRegionId;
        });

        if (_selectedRegionId != null) {
          await _fetchProvinces(_selectedRegionId!);
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

        int? defaultProvinceId;
        final defaultProvinceIndex = provinces.indexWhere((p) => p['id'] == 50);
        if (defaultProvinceIndex >= 0) {
          defaultProvinceId = provinces[defaultProvinceIndex]['id'] as int;
        }

        setState(() {
          _provinces = provinces;
          _cities = [];
          _barangays = [];
          _selectedProvinceId = defaultProvinceId;
          _selectedCityId = null;
          _selectedBarangayId = null;
        });

        if (_selectedProvinceId != null) {
          await _fetchCities(_selectedProvinceId!);
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

        int? defaultCityId;
        final defaultCityIndex = cities.indexWhere((c) => c['id'] == 825);
        if (defaultCityIndex >= 0) {
          defaultCityId = cities[defaultCityIndex]['id'] as int;
        }

        setState(() {
          _cities = cities;
          _barangays = [];
          _selectedCityId = defaultCityId;
          _selectedBarangayId = null;
        });

        if (_selectedCityId != null) {
          await _fetchBarangays(_selectedCityId!);
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

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final currentUser = AuthService().currentUser;
        final currentUserType = (currentUser?['type'] ?? '').toString();
        final isRealUser =
            currentUserType.toLowerCase() == 'user' ||
            (currentUserType.isEmpty &&
                currentUser?['supervisor_id'] == null &&
                currentUser?['client_id'] == null);

        final currentUserId = (isRealUser && currentUser != null)
            ? currentUser['user_id']
            : null;

        final fieldWorkerData = {
          if (currentUserId != null) 'user_id': currentUserId,
          if (widget.projectId != null) 'project_id': widget.projectId,
          'first_name': _firstNameController.text.trim(),
          'middle_name': _middleNameController.text.trim().isEmpty
              ? null
              : _middleNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'phone_number': _phoneNumberController.text.trim(),
          'birthdate': _birthdateController.text.trim().isEmpty
              ? null
              : _birthdateController.text.trim(),
          'role': _isCustomRole
              ? _customRoleController.text.trim()
              : _selectedRole,
          'sss_id': _sssIdController.text.trim().isEmpty
              ? null
              : _sssIdController.text.trim(),
          'philhealth_id': _philHealthIdController.text.trim().isEmpty
              ? null
              : _philHealthIdController.text.trim(),
          'pagibig_id': _pagIbigIdController.text.trim().isEmpty
              ? null
              : _pagIbigIdController.text.trim(),
          'payrate': _payrateController.text.trim().isEmpty
              ? null
              : double.tryParse(_payrateController.text.trim()),
          'region': _selectedRegionId,
          'province': _selectedProvinceId,
          'city': _selectedCityId,
          'barangay': _selectedBarangayId,
        };

        debugPrint('Creating field worker: $fieldWorkerData');

        final response = await http.post(
          AppConfig.apiUri('field-workers/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(fieldWorkerData),
        );

        debugPrint('Response status: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');

        if (response.statusCode == 201 || response.statusCode == 200) {
          int? createdFieldWorkerId;
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map) {
              final rawId = decoded['fieldworker_id'] ?? decoded['id'];
              if (rawId is int) {
                createdFieldWorkerId = rawId;
              } else if (rawId != null) {
                createdFieldWorkerId = int.tryParse(rawId.toString());
              }
            }
          } catch (_) {}

          if (createdFieldWorkerId != null && _selectedImage != null) {
            try {
              await _uploadFieldWorkerPhoto(
                fieldWorkerId: createdFieldWorkerId,
                currentUserId: currentUserId,
              );
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Photo upload failed: $e')),
                );
              }
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Field worker added successfully!')),
            );
            Navigator.of(context).pop(true);
          }
        } else {
          try {
            final errorData = jsonDecode(response.body);
            final errorMessage =
                errorData['detail'] ??
                errorData['error'] ??
                errorData.toString() ??
                'Failed to add field worker';
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Error: $errorMessage')));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error: Failed to add field worker'),
                ),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
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
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Text(
                    widget.workerType,
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
                              child: _selectedImage == null
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
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildFormFields(isMobile),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                  child: _selectedImage == null
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
                        Container(width: 1, color: const Color(0xFFE5E7EB)),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _buildFormFields(false),
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
                                    'Add Field Worker',
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
                                    'Add Field Worker',
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

  List<Widget> _buildFormFields(bool isMobile) {
    final spacing = isMobile ? 12.0 : 16.0;
    return [
      const Text(
        'Personal Information',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      SizedBox(height: spacing),

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
      SizedBox(height: spacing),
      _buildTextField(
        controller: _middleNameController,
        hintText: 'Middle Name (Optional)',
      ),
      SizedBox(height: spacing),
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
      SizedBox(height: spacing),
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
      SizedBox(height: spacing),
      _buildTextField(
        controller: _birthdateController,
        hintText: 'Birthdate (Optional)',
        readOnly: true,
        suffixIcon: Icons.calendar_today_outlined,
        onTap: () => _selectDate(context, _birthdateController),
      ),
      SizedBox(height: spacing),
      const Text(
        'Address',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      SizedBox(height: spacing),

      _isLoadingRegions
          ? const Center(child: CircularProgressIndicator())
          : DropdownButtonFormField<int>(
              value: _selectedRegionId,
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              items: _regions.map((region) {
                return DropdownMenuItem<int>(
                  value: region['id'] as int,
                  child: Text(region['name'] as String),
                );
              }).toList(),
              onChanged: (int? value) async {
                if (value == null) return;
                setState(() {
                  _selectedRegionId = value;
                  _selectedProvinceId = null;
                  _selectedCityId = null;
                  _selectedBarangayId = null;
                  _provinces = [];
                  _cities = [];
                  _barangays = [];
                });
                await _fetchProvinces(value);
              },
            ),
      SizedBox(height: spacing),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        items: _provinces.map((province) {
          return DropdownMenuItem<int>(
            value: province['id'] as int,
            child: Text(province['name'] as String),
          );
        }).toList(),
        onChanged: (int? value) async {
          if (value == null) return;
          setState(() {
            _selectedProvinceId = value;
            _selectedCityId = null;
            _selectedBarangayId = null;
            _cities = [];
            _barangays = [];
          });
          await _fetchCities(value);
        },
      ),
      SizedBox(height: spacing),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        items: _cities.map((city) {
          return DropdownMenuItem<int>(
            value: city['id'] as int,
            child: Text(city['name'] as String),
          );
        }).toList(),
        onChanged: (int? value) async {
          if (value == null) return;
          setState(() {
            _selectedCityId = value;
            _selectedBarangayId = null;
            _barangays = [];
          });
          await _fetchBarangays(value);
        },
      ),
      SizedBox(height: spacing),
      DropdownButtonFormField<int>(
        value: _selectedBarangayId,
        decoration: InputDecoration(
          labelText: 'Barangay (Optional)',
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
            horizontal: 16,
            vertical: 12,
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
      SizedBox(height: spacing),

      const Text(
        'ID Numbers',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      SizedBox(height: spacing),
      _buildTextField(
        controller: _sssIdController,
        hintText: 'SSS ID (Optional)',
      ),
      SizedBox(height: spacing),
      _buildTextField(
        controller: _philHealthIdController,
        hintText: 'PhilHealth ID (Optional)',
      ),
      SizedBox(height: spacing),
      _buildTextField(
        controller: _pagIbigIdController,
        hintText: 'PagIbig ID (Optional)',
      ),
      SizedBox(height: spacing),
      _buildTextField(
        controller: _payrateController,
        hintText: 'Payrate (Optional)',
        keyboardType: TextInputType.number,
      ),
      SizedBox(height: spacing),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Role',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _isCustomRole ? 'custom_role' : _selectedRole,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: 'Mason', child: Text('Mason')),
                  const DropdownMenuItem(
                    value: 'Painter',
                    child: Text('Painter'),
                  ),
                  const DropdownMenuItem(
                    value: 'Electrician',
                    child: Text('Electrician'),
                  ),
                  const DropdownMenuItem(
                    value: 'Carpenter',
                    child: Text('Carpenter'),
                  ),
                  const DropdownMenuItem(
                    value: 'custom_role',
                    child: Text('Custom Role'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    if (value == 'custom_role') {
                      _isCustomRole = true;
                      _customRoleController.clear();
                    } else {
                      _isCustomRole = false;
                      _selectedRole = value ?? 'Mason';
                      _customRoleController.clear();
                    }
                  });
                },
              ),
            ),
          ),
        ],
      ),
      if (_isCustomRole) ...[
        SizedBox(height: spacing),
        _buildTextField(
          controller: _customRoleController,
          hintText: 'Enter custom role',
          validator: (value) {
            if (_isCustomRole && (value == null || value.isEmpty)) {
              return 'Please enter a role';
            }
            return null;
          },
        ),
      ],
    ];
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    bool readOnly = false,
    IconData? suffixIcon,
    VoidCallback? onTap,
    String? Function(String?)? validator,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: hintText,
        labelStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, size: 18, color: Colors.grey[600])
            : null,
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
          horizontal: 16,
          vertical: 12,
        ),
      ),
      validator: validator,
    );
  }
}
