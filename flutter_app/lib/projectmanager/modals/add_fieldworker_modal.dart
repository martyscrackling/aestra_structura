import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddFieldWorkerModal extends StatefulWidget {
  final String workerType;
  final int projectId;

  const AddFieldWorkerModal({
    super.key,
    required this.workerType,
    required this.projectId,
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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
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
        final fieldWorkerData = {
          'user_id': 1, // TODO: Replace with current logged-in user ID
          'project_id': widget.projectId,
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
        };

        print('Creating field worker: $fieldWorkerData');

        final response = await http.post(
          Uri.parse('http://127.0.0.1:8000/api/field-workers/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(fieldWorkerData),
        );

        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.statusCode == 201 || response.statusCode == 200) {
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
            Expanded(
              child: Row(
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
                  Container(width: 1, color: const Color(0xFFE5E7EB)),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                            _buildTextField(
                              controller: _middleNameController,
                              hintText: 'Middle Name (Optional)',
                            ),
                            const SizedBox(height: 16),
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
                            _buildTextField(
                              controller: _birthdateController,
                              hintText: 'Birthdate (Optional)',
                              readOnly: true,
                              suffixIcon: Icons.calendar_today_outlined,
                              onTap: () =>
                                  _selectDate(context, _birthdateController),
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _sssIdController,
                              hintText: 'SSS ID (Optional)',
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _philHealthIdController,
                              hintText: 'PhilHealth ID (Optional)',
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _pagIbigIdController,
                              hintText: 'PagIbig ID (Optional)',
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _payrateController,
                              hintText: 'Payrate (Optional)',
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
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
                                      value: _isCustomRole
                                          ? 'custom_role'
                                          : _selectedRole,
                                      isExpanded: true,
                                      items: [
                                        const DropdownMenuItem(
                                          value: 'Mason',
                                          child: Text('Mason'),
                                        ),
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
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _customRoleController,
                                hintText: 'Enter custom role',
                                validator: (value) {
                                  if (_isCustomRole &&
                                      (value == null || value.isEmpty)) {
                                    return 'Please enter a role';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: 24),
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
