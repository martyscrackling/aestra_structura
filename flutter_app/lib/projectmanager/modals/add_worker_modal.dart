import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/auth_service.dart';

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

  XFile? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _passwordController.text = 'PASSWORD';
  }

  void _generateEmail() {
    final firstName = _firstNameController.text.trim().toLowerCase();
    final lastName = _lastNameController.text.trim().toLowerCase();

    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      _generatedEmailController.text = '$lastName.$firstName@structura.com';
    }
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
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
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

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Build payload with ALL fields including optional ones
        final Map<String, dynamic> supervisorData = {
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

        print('Sending supervisor data: $supervisorData');

        final response = await http.post(
          Uri.parse('http://127.0.0.1:8000/api/supervisors/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(supervisorData),
        );

        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.statusCode == 201 || response.statusCode == 200) {
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 900,
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
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    color: const Color(0xFF0C1935),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.workerType,
                    style: const TextStyle(
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side - Image
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
                              image: _selectedImage != null
                                  ? const DecorationImage(
                                      image: AssetImage(
                                        'assets/images/engineer.jpg',
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _selectedImage == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
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

                  // Right side - Form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // First Name
                            _buildTextField(
                              controller: _firstNameController,
                              hintText: 'First Name',
                              onChanged: (value) => _generateEmail(),
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
                              onChanged: (value) => _generateEmail(),
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
                              hintText: 'Account Email (Auto-generated)',
                              readOnly: true,
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
                              onTap: () =>
                                  _selectDate(context, _birthdateController),
                            ),
                            const SizedBox(height: 16),

                            // SSS ID
                            _buildTextField(
                              controller: _sssIdController,
                              hintText: 'SSS ID (Optional)',
                            ),
                            const SizedBox(height: 16),

                            // PhilHealth ID
                            _buildTextField(
                              controller: _philHealthIdController,
                              hintText: 'PhilHealth ID (Optional)',
                            ),
                            const SizedBox(height: 16),

                            // PagIbig ID
                            _buildTextField(
                              controller: _pagIbigIdController,
                              hintText: 'PagIbig ID (Optional)',
                            ),
                            const SizedBox(height: 16),

                            // Payrate
                            _buildTextField(
                              controller: _payrateController,
                              hintText: 'Payrate (Optional)',
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),

                            const SizedBox(height: 24),

                            // Add Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
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
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
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
        hintText: hintText,
        hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      validator: validator,
    );
  }
}
