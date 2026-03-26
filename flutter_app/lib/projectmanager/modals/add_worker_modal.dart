import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import '../../services/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/subscription_helper.dart';
import '../../services/photo_verifier.dart';

class AddWorkerModal extends StatefulWidget {
  final String workerType;

  const AddWorkerModal({super.key, required this.workerType});

  @override
  State<AddWorkerModal> createState() => _AddWorkerModalState();
}

class _AddWorkerModalState extends State<AddWorkerModal> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _generatedEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _sssIdController = TextEditingController();
  final _philHealthIdController = TextEditingController();
  final _pagIbigIdController = TextEditingController();
  final _payrateController = TextEditingController();

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

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isLoading = false;
  bool _isPhotoVerifying = false;
  bool _photoVerified = false;

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
    _sssIdController.dispose();
    _philHealthIdController.dispose();
    _pagIbigIdController.dispose();
    _payrateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final verified = await _verifyPhotoSelection(bytes, image.name);
    if (!mounted) return;

    if (verified) {
      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
      });
    } else {
      setState(() {
        _selectedImage = null;
        _selectedImageBytes = null;
      });
    }
  }

  int? _currentUserId() {
    final raw = AuthService().currentUser?['user_id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<bool> _verifyPhotoSelection(Uint8List bytes, String filename) async {
    if (!mounted) return false;
    setState(() {
      _isPhotoVerifying = true;
      _photoVerified = false;
    });

    final result = await PhotoVerifier.verify(
      bytes: bytes,
      filename: filename,
      userId: _currentUserId(),
    );

    if (!mounted) {
      return result.accepted;
    }

    setState(() {
      _isPhotoVerifying = false;
      _photoVerified = result.accepted;
    });

    if (!result.accepted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    }

    return result.accepted;
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

  Widget _buildPhotoPicker({
    required double width,
    required double height,
    required String prompt,
    double iconSize = 40,
  }) {
    final hasImage = _selectedImageBytes != null;
    return GestureDetector(
      onTap: _isPhotoVerifying ? null : _pickImage,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  image: hasImage
                      ? DecorationImage(
                          image: MemoryImage(_selectedImageBytes!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: hasImage
                    ? null
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: iconSize,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            prompt,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
              ),
              if (_isPhotoVerifying)
                Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_photoVerified)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text(
                  'Photo verified',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _fetchRegions() async {
    try {
      setState(() => _isLoadingRegions = true);
      final response = await http.get(AppConfig.apiUri('regions/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final regions = data.cast<Map<String, dynamic>>();

        // Default to Region IX - Zamboanga Peninsula (id: 10).
        final defaultRegion = regions.where((r) => r['id'] == 10).firstOrNull;
        final selectedRegionId =
            (defaultRegion?['id'] as int?) ??
            (regions.isNotEmpty ? regions.first['id'] as int? : null);

        setState(() {
          _regions = regions;
          _selectedRegionId = selectedRegionId;
        });

        if (selectedRegionId != null) {
          await _fetchProvinces(selectedRegionId);
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

        // Default to Zamboanga del Sur (id: 50).
        final defaultProvince = provinces
            .where((p) => p['id'] == 50)
            .firstOrNull;
        final selectedProvinceId =
            (defaultProvince?['id'] as int?) ??
            (provinces.isNotEmpty ? provinces.first['id'] as int? : null);

        setState(() {
          _provinces = provinces;
          _selectedProvinceId = selectedProvinceId;
          _cities = [];
          _barangays = [];
          _selectedCityId = null;
          _selectedBarangayId = null;
        });

        if (selectedProvinceId != null) {
          await _fetchCities(selectedProvinceId);
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

        // Default to Zamboanga City (id: 825).
        final defaultCity = cities.where((c) => c['id'] == 825).firstOrNull;
        final selectedCityId =
            (defaultCity?['id'] as int?) ??
            (cities.isNotEmpty ? cities.first['id'] as int? : null);

        setState(() {
          _cities = cities;
          _selectedCityId = selectedCityId;
          _barangays = [];
          _selectedBarangayId = null;
        });

        if (selectedCityId != null) {
          await _fetchBarangays(selectedCityId);
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
        final currentUserId = AuthService().currentUser?['user_id'];
        // Build payload with ALL fields including optional ones
        final Map<String, dynamic> supervisorData = {
          if (currentUserId != null) 'user_id': currentUserId,
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
          'password_hash': _passwordController.text.trim(),
          'phone_number': _phoneNumberController.text.trim(),
          'birthdate': _birthdateController.text.trim().isEmpty
              ? null
              : _birthdateController.text.trim(),
          'region': _selectedRegionId,
          'province': _selectedProvinceId,
          'city': _selectedCityId,
          'barangay': _selectedBarangayId,
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
        };

        debugPrint('Sending supervisor data: $supervisorData');

        final response = await http.post(
          AppConfig.apiUri('supervisors/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(supervisorData),
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
          int? supervisorId;
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map) {
              final rawId = decoded['supervisor_id'] ?? decoded['id'];
              if (rawId is int) {
                supervisorId = rawId;
              } else if (rawId is String) {
                supervisorId = int.tryParse(rawId);
              }
            }
          } catch (_) {
            // Ignore parsing errors; supervisor was created but we may not be able to upload a photo.
          }

          if (_selectedImage != null && supervisorId != null) {
            final bool Function(String?) isFaceReject = (String? msg) =>
                msg != null && msg.contains('No human face detected');

            final uploadResult = await _uploadSupervisorPhoto(
              supervisorId: supervisorId,
              currentUserId: currentUserId,
            );

            if (!uploadResult.ok && mounted) {
              final msg =
                  uploadResult.message ??
                  'Supervisor created, but photo upload failed (HTTP ${uploadResult.statusCode ?? "?"}).';

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(msg),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );

              final shouldReject =
                  uploadResult.imageVerification == 'REJECT' ||
                  isFaceReject(uploadResult.message);

              if (shouldReject) {
                // Prevent cat/nonhuman photos from creating a usable supervisor record.
                try {
                  final headers = currentUserId != null
                      ? {'X-User-Id': currentUserId.toString()}
                      : <String, String>{};
                  await http.delete(
                    AppConfig.apiUri('supervisors/$supervisorId/'),
                    headers: headers.isEmpty ? null : headers,
                  );
                } catch (_) {
                  // Ignore delete failures; user will still see the rejection message.
                }
                return;
              }
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Supervisor added successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true);
          }
        } else {
          String errorMsg = 'Failed to add supervisor';
          try {
            // Try to parse error response
            final errorData = jsonDecode(response.body);
            if (errorData is Map) {
              final errors = <String>[];
              errorData.forEach((key, value) {
                if (value is List) {
                  errors.add('$key: ${value.join(", ")}');
                } else {
                  errors.add('$key: $value');
                }
              });
              if (errors.isNotEmpty) {
                errorMsg = errors.join(' | ');
              }
            }
          } catch (e) {
            errorMsg = 'HTTP ${response.statusCode}: ${response.body}';
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $errorMsg'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
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

  Future<_UploadResult> _uploadSupervisorPhoto({
    required int supervisorId,
    required dynamic currentUserId,
  }) async {
    final file = _selectedImage;
    if (file == null) {
      return const _UploadResult(ok: true);
    }

    try {
      final baseUri = AppConfig.apiUri(
        'supervisors/$supervisorId/upload-photo/',
      );
      final uri = (currentUserId != null)
          ? baseUri.replace(
              queryParameters: {
                ...baseUri.queryParameters,
                'user_id': currentUserId.toString(),
              },
            )
          : baseUri;
      final request = http.MultipartRequest('POST', uri);

      // The backend scopes access using a Project Manager user id.
      if (currentUserId != null) {
        request.headers['X-User-Id'] = currentUserId.toString();
        request.fields['user_id'] = currentUserId.toString();
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          _selectedImageBytes ?? await file.readAsBytes(),
          filename: (file.name.isNotEmpty)
              ? file.name
              : 'supervisor_$supervisorId.jpg',
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      debugPrint('Photo upload status: ${response.statusCode}');
      debugPrint('Photo upload body: ${response.body}');
      final ok = response.statusCode >= 200 && response.statusCode < 300;

      String? message;
      String? imageVerification;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          message =
              decoded['detail']?.toString() ?? decoded['error']?.toString();
          imageVerification = decoded['image_verification']?.toString();
        }
      } catch (_) {
        // ignore parsing issues
      }

      return _UploadResult(
        ok: ok,
        statusCode: response.statusCode,
        message: message,
        imageVerification: imageVerification,
      );
    } catch (e) {
      debugPrint('Photo upload error: $e');
      return _UploadResult(ok: false, message: e.toString());
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

            // Form Content
            Expanded(
              child: isMobile
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Image on top for mobile
                          _buildPhotoPicker(
                            width: 120,
                            height: 120,
                            prompt: 'Upload photo',
                            iconSize: 40,
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
                        // Left side - Image
                        Container(
                          width: 280,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              _buildPhotoPicker(
                                width: 200,
                                height: 280,
                                prompt: 'Click to upload photo',
                                iconSize: 60,
                              ),
                            ],
                          ),
                        ),

                        // Divider
                        Container(width: 1, color: const Color(0xFFE5E7EB)),

                        // Right side - Form
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
                            onPressed: (_isLoading || _isPhotoVerifying)
                                ? null
                                : _handleSubmit,
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
                                    'Add Worker',
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
                            onPressed: (_isLoading || _isPhotoVerifying)
                                ? null
                                : _handleSubmit,
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
                                    'Add Worker',
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
      // First Name
      const Text(
        'Personal Information',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0C1935),
        ),
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

      // Middle Name
      _buildTextField(
        controller: _middleNameController,
        hintText: 'Middle Name (Optional)',
      ),
      SizedBox(height: spacing),

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
      SizedBox(height: spacing),

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
      SizedBox(height: spacing),

      // Generated Password
      _buildTextField(
        controller: _passwordController,
        hintText: 'Password (Default)',
        readOnly: true,
      ),
      SizedBox(height: spacing),

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
      SizedBox(height: spacing),

      // Birthdate
      _buildTextField(
        controller: _birthdateController,
        hintText: 'Birthdate (Optional)',
        readOnly: true,
        suffixIcon: Icons.calendar_today_outlined,
        onTap: () => _selectDate(context, _birthdateController),
      ),
      SizedBox(height: spacing),

      // Address - Cascading Dropdowns
      const Text(
        'Address',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0C1935),
        ),
      ),
      SizedBox(height: spacing),

      // Region
      _isLoadingRegions
          ? const Center(child: CircularProgressIndicator())
          : DropdownButtonFormField<int>(
              value: _selectedRegionId,
              decoration: _dropdownDecoration('Region'),
              items: _regions.map((region) {
                return DropdownMenuItem<int>(
                  value: region['id'] as int,
                  child: Text(region['name'] as String),
                );
              }).toList(),
              onChanged: (int? value) {
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
                _fetchProvinces(value);
              },
            ),
      SizedBox(height: spacing),

      // Province
      DropdownButtonFormField<int>(
        value: _selectedProvinceId,
        decoration: _dropdownDecoration('Province'),
        items: _provinces.map((province) {
          return DropdownMenuItem<int>(
            value: province['id'] as int,
            child: Text(province['name'] as String),
          );
        }).toList(),
        onChanged: (int? value) {
          if (value == null) return;
          setState(() {
            _selectedProvinceId = value;
            _selectedCityId = null;
            _selectedBarangayId = null;
            _cities = [];
            _barangays = [];
          });
          _fetchCities(value);
        },
      ),
      SizedBox(height: spacing),

      // City
      DropdownButtonFormField<int>(
        value: _selectedCityId,
        decoration: _dropdownDecoration('City'),
        items: _cities.map((city) {
          return DropdownMenuItem<int>(
            value: city['id'] as int,
            child: Text(city['name'] as String),
          );
        }).toList(),
        onChanged: (int? value) {
          if (value == null) return;
          setState(() {
            _selectedCityId = value;
            _selectedBarangayId = null;
            _barangays = [];
          });
          _fetchBarangays(value);
        },
      ),
      SizedBox(height: spacing),

      // Barangay
      DropdownButtonFormField<int>(
        value: _selectedBarangayId,
        decoration: _dropdownDecoration('Barangay'),
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
      // SSS ID
      const Text(
        'ID Numbers (Optional)',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0C1935),
        ),
      ),
      SizedBox(height: spacing),
      _buildTextField(controller: _sssIdController, hintText: 'SSS ID'),
      SizedBox(height: spacing),

      // PhilHealth ID
      _buildTextField(
        controller: _philHealthIdController,
        hintText: 'PhilHealth ID',
      ),
      SizedBox(height: spacing),

      // PagIbig ID
      _buildTextField(controller: _pagIbigIdController, hintText: 'PagIbig ID'),
      SizedBox(height: spacing),

      // Payrate
      _buildTextField(
        controller: _payrateController,
        hintText: 'Payrate',
        keyboardType: TextInputType.number,
      ),
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

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}

class _UploadResult {
  final bool ok;
  final int? statusCode;
  final String? message;
  final String? imageVerification;

  const _UploadResult({
    required this.ok,
    this.statusCode,
    this.message,
    this.imageVerification,
  });
}
