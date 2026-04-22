import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../clients_page.dart';
import '../../services/app_config.dart';
import '../../services/auth_service.dart';
import '../../utils/philippine_phone_input.dart';

class ViewEditClientModal extends StatefulWidget {
  final ClientInfo client;

  const ViewEditClientModal({super.key, required this.client});

  @override
  State<ViewEditClientModal> createState() => _ViewEditClientModalState();
}

class _ViewEditClientModalState extends State<ViewEditClientModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _contactNumberController;
  late TextEditingController _emailController;

  int? _selectedRegionId;
  int? _selectedProvinceId;
  int? _selectedCityId;
  int? _selectedBarangayId;

  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _barangays = [];

  bool _isLoadingAddress = false;
  bool _isSaving = false;

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isEditing = true;

  String? _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['detail'] != null) {
          return decoded['detail'].toString();
        }
        if (decoded['email'] is List && (decoded['email'] as List).isNotEmpty) {
          return (decoded['email'] as List).first.toString();
        }
        for (final value in decoded.values) {
          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          }
          if (value != null) {
            final message = value.toString().trim();
            if (message.isNotEmpty) {
              return message;
            }
          }
        }
      }
    } catch (_) {
      // Response is not JSON; return null to fall back to default message.
    }
    return null;
  }

  String _formatPhoneForDisplay(String value) {
    final digits = PhilippinePhoneInputFormatter.normalizeDigits(value);
    if (digits.isEmpty) return '';
    return PhilippinePhoneInputFormatter.formatFromDigits(digits);
  }

  bool _isValidPhoneForSave(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (PhilippinePhoneInputFormatter.isValidFormattedPhone(trimmed)) {
      return true;
    }
    final digits = PhilippinePhoneInputFormatter.normalizeDigits(trimmed);
    return digits.length == 11 && digits.startsWith('09');
  }

  @override
  void initState() {
    super.initState();
    final nameParts = widget.client.name.split(' ');
    _firstNameController = TextEditingController(
      text: nameParts.isNotEmpty ? nameParts[0] : '',
    );
    _lastNameController = TextEditingController(
      text: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
    );
    _contactNumberController = TextEditingController(
      text: _formatPhoneForDisplay(widget.client.phone),
    );
    _emailController = TextEditingController(text: widget.client.email);
    _fetchRegions();
    _loadClientDetails();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  int? _currentUserId() {
    final raw = AuthService().currentUser?['user_id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<void> _fetchRegions() async {
    try {
      setState(() => _isLoadingAddress = true);
      final response = await http.get(AppConfig.apiUri('regions/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _regions = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {
      // No-op: keep current values if address lists fail to load.
    } finally {
      if (mounted) {
        setState(() => _isLoadingAddress = false);
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
        if (!mounted) return;
        setState(() {
          _provinces = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {
      // No-op
    }
  }

  Future<void> _fetchCities(int provinceId) async {
    try {
      final response = await http.get(
        AppConfig.apiUri('cities/?province=$provinceId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _cities = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {
      // No-op
    }
  }

  Future<void> _fetchBarangays(int cityId) async {
    try {
      final response = await http.get(
        AppConfig.apiUri('barangays/?city=$cityId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _barangays = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {
      // No-op
    }
  }

  Future<void> _loadClientDetails() async {
    final clientId = widget.client.id;
    final userId = _currentUserId();
    if (clientId == null || userId == null) return;

    try {
      final response = await http.get(
        AppConfig.apiUri('clients/$clientId/?user_id=$userId'),
      );
      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;

      final firstName = (decoded['first_name']?.toString() ?? '').trim();
      final lastName = (decoded['last_name']?.toString() ?? '').trim();
      final email = (decoded['email']?.toString() ?? '').trim();
      final phone = (decoded['phone_number']?.toString() ?? '').trim();

      final regionId = decoded['region'] is int
          ? decoded['region'] as int
          : int.tryParse(decoded['region']?.toString() ?? '');
      final provinceId = decoded['province'] is int
          ? decoded['province'] as int
          : int.tryParse(decoded['province']?.toString() ?? '');
      final cityId = decoded['city'] is int
          ? decoded['city'] as int
          : int.tryParse(decoded['city']?.toString() ?? '');
      final barangayId = decoded['barangay'] is int
          ? decoded['barangay'] as int
          : int.tryParse(decoded['barangay']?.toString() ?? '');

      if (regionId != null) {
        await _fetchProvinces(regionId);
      }
      if (provinceId != null) {
        await _fetchCities(provinceId);
      }
      if (cityId != null) {
        await _fetchBarangays(cityId);
      }

      if (!mounted) return;
      setState(() {
        _firstNameController.text = firstName;
        _lastNameController.text = lastName;
        _emailController.text = email;
        _contactNumberController.text = _formatPhoneForDisplay(phone);
        _selectedRegionId = regionId;
        _selectedProvinceId = provinceId;
        _selectedCityId = cityId;
        _selectedBarangayId = barangayId;
      });
    } catch (_) {
      // No-op
    }
  }

  Future<void> _pickImage() async {
    if (!_isEditing) return;

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

  Future<void> _uploadClientPhoto({
    required int clientId,
    required int pmUserId,
  }) async {
    if (_selectedImage == null || _selectedImageBytes == null) {
      return;
    }

    final uri = AppConfig.apiUri(
      'clients/$clientId/upload-photo/?user_id=$pmUserId',
    );

    final request = http.MultipartRequest('POST', uri);
    request.headers['X-User-Id'] = pmUserId.toString();
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        _selectedImageBytes!,
        filename: _selectedImage!.name,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final serverMessage = _extractErrorMessage(response.body);
      throw Exception(
        serverMessage ?? 'Failed to upload photo (${response.statusCode}).',
      );
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final clientId = widget.client.id;
    final userId = _currentUserId();
    if (clientId == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save client profile.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final response = await http.patch(
        AppConfig.apiUri('clients/$clientId/?user_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': userId.toString(),
        },
        body: jsonEncode({
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone_number': PhilippinePhoneInputFormatter.normalizeDigits(
            _contactNumberController.text.trim(),
          ),
          'region': _selectedRegionId,
          'province': _selectedProvinceId,
          'city': _selectedCityId,
          'barangay': _selectedBarangayId,
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        if (_selectedImage != null) {
          await _uploadClientPhoto(clientId: clientId, pmUserId: userId);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client profile updated successfully.')),
        );
        Navigator.of(context).pop(true);
      } else {
        String message = 'Failed to save changes (${response.statusCode}).';
        final serverMessage = _extractErrorMessage(response.body);
        if (serverMessage != null && serverMessage.isNotEmpty) {
          message = serverMessage;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isNotEmpty ? message : 'Failed to save changes.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildAddressDropdown({
    required String label,
    required int? value,
    required List<Map<String, dynamic>> items,
    required ValueChanged<int?> onChanged,
    bool isRequired = true,
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      items: items.map((entry) {
        return DropdownMenuItem<int>(
          value: entry['id'] as int,
          child: Text(entry['name'] as String),
        );
      }).toList(),
      onChanged: _isEditing ? onChanged : null,
      validator: (selected) {
        if (isRequired && selected == null) {
          return 'Required';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 650),
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
                    'Client Profile',
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
                      // Client's Profile Section
                      const Text(
                        'Client\'s Profile',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0C1935),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Image Upload
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundImage: _selectedImage != null
                                    ? MemoryImage(_selectedImageBytes!)
                                    : NetworkImage(widget.client.avatarUrl),
                              ),
                              if (_isEditing)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF7A18),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Client's Information
                      const Text(
                        'Client\'s information',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0C1935),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // First Name and Last Name
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Firstname',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0C1935),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _firstNameController,
                                  readOnly: !_isEditing,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: _isEditing
                                        ? const Color(0xFFF9FAFB)
                                        : Colors.grey[100],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: _isEditing
                                            ? Colors.grey[300]!
                                            : Colors.grey[200]!,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: _isEditing
                                            ? Colors.grey[300]!
                                            : Colors.grey[200]!,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Lastname',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0C1935),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _lastNameController,
                                  readOnly: !_isEditing,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: _isEditing
                                        ? const Color(0xFFF9FAFB)
                                        : Colors.grey[100],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: _isEditing
                                            ? Colors.grey[300]!
                                            : Colors.grey[200]!,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: _isEditing
                                            ? Colors.grey[300]!
                                            : Colors.grey[200]!,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
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
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Location
                      const Text(
                        'Location',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0C1935),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingAddress)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        _buildAddressDropdown(
                          label: 'Region',
                          value: _selectedRegionId,
                          items: _regions,
                          onChanged: (value) {
                            setState(() {
                              _selectedRegionId = value;
                              _selectedProvinceId = null;
                              _selectedCityId = null;
                              _selectedBarangayId = null;
                              _provinces = [];
                              _cities = [];
                              _barangays = [];
                            });
                            if (value != null) {
                              _fetchProvinces(value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildAddressDropdown(
                          label: 'Province',
                          value: _selectedProvinceId,
                          items: _provinces,
                          onChanged: (value) {
                            setState(() {
                              _selectedProvinceId = value;
                              _selectedCityId = null;
                              _selectedBarangayId = null;
                              _cities = [];
                              _barangays = [];
                            });
                            if (value != null) {
                              _fetchCities(value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildAddressDropdown(
                          label: 'City',
                          value: _selectedCityId,
                          items: _cities,
                          onChanged: (value) {
                            setState(() {
                              _selectedCityId = value;
                              _selectedBarangayId = null;
                              _barangays = [];
                            });
                            if (value != null) {
                              _fetchBarangays(value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildAddressDropdown(
                          label: 'Barangay',
                          value: _selectedBarangayId,
                          items: _barangays,
                          isRequired: false,
                          onChanged: (value) {
                            setState(() {
                              _selectedBarangayId = value;
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Contact Number
                      const Text(
                        'Contact Number',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0C1935),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _contactNumberController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [PhilippinePhoneInputFormatter()],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        readOnly: !_isEditing,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: _isEditing
                              ? const Color(0xFFF9FAFB)
                              : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _isEditing
                                  ? Colors.grey[300]!
                                  : Colors.grey[200]!,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _isEditing
                                  ? Colors.grey[300]!
                                  : Colors.grey[200]!,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (!_isValidPhoneForSave(value)) {
                            return 'Use 09XX-XXX-XXXX';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email
                      const Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0C1935),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        readOnly: !_isEditing,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: _isEditing
                              ? const Color(0xFFF9FAFB)
                              : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _isEditing
                                  ? Colors.grey[300]!
                                  : Colors.grey[200]!,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _isEditing
                                  ? Colors.grey[300]!
                                  : Colors.grey[200]!,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Save Button (only visible when editing)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: const Color(0xFFFF7A18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
