import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/auth_service.dart';

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

  String _selectedStatus = 'active';
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
            hintText: hintText,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
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
        // Get the current logged-in user's ID from AuthService
        final authService = Provider.of<AuthService>(context, listen: false);
        final userId = authService.currentUser?['user_id'];

        final clientData = {
          'user_id': userId, // Include the currently logged-in user's ID
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
          'status': _selectedStatus,
        };

        print('Sending client data: $clientData');

        final response = await http.post(
          Uri.parse('http://127.0.0.1:8000/api/clients/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(clientData),
        );

        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.statusCode == 201 || response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Client added successfully!')),
          );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        width: 700,
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
                    'Add a client',
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

                            // Status Dropdown
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Status',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedStatus,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'active',
                                          child: Text('Active'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'deactivated',
                                          child: Text('Deactivated'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'fired',
                                          child: Text('Fired'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedStatus = value ?? 'active';
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
