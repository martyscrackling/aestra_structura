import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../workforce_page.dart';

class ViewEditWorkerModal extends StatefulWidget {
  final WorkerInfo worker;

  const ViewEditWorkerModal({super.key, required this.worker});

  @override
  State<ViewEditWorkerModal> createState() => _ViewEditWorkerModalState();
}

class _ViewEditWorkerModalState extends State<ViewEditWorkerModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _roleController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _dateHiredController;
  late TextEditingController _shiftScheduleController;
  late TextEditingController _rateController;

  XFile? _selectedImage;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.worker.name);
    _roleController = TextEditingController(text: widget.worker.role);
    _addressController = TextEditingController(text: '123 Sample Street, City');
    _phoneController = TextEditingController(text: widget.worker.phone);
    _dateHiredController = TextEditingController(text: '01-15-2024');
    _shiftScheduleController = TextEditingController(text: '8:00 AM - 5:00 PM');
    _rateController = TextEditingController(text: '500');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _roleController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _dateHiredController.dispose();
    _shiftScheduleController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (!_isEditing) return;

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
    if (!_isEditing) return;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        controller.text =
            '${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}-${picked.year}';
      });
    }
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop({
        'fullName': _fullNameController.text,
        'role': _roleController.text,
        'address': _addressController.text,
        'phoneNumber': _phoneController.text,
        'dateHired': _dateHiredController.text,
        'shiftSchedule': _shiftScheduleController.text,
        'rate': _rateController.text,
        'image': _selectedImage,
      });
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
        width: isMobile ? double.infinity : 900,
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
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    color: const Color(0xFF0C1935),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.worker.role,
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0C1935),
                      ),
                    ),
                  ),
                  if (!_isEditing)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isEditing = true;
                        });
                      },
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Color(0xFFFF7A18),
                      ),
                      label: const Text(
                        'Edit',
                        style: TextStyle(
                          color: Color(0xFFFF7A18),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile Avatar at top on mobile
                            Center(
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: NetworkImage(
                                      widget.worker.avatarUrl,
                                    ),
                                  ),
                                  if (_isEditing)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: _pickImage,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF7A18),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Personal Information Section
                            const Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0C1935),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Full Name
                            _buildLabeledField(
                              label: 'Full Name',
                              controller: _fullNameController,
                              hintText: 'Enter full name',
                              readOnly: !_isEditing,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Role
                            _buildLabeledField(
                              label: 'Role',
                              controller: _roleController,
                              hintText: 'Enter role',
                              readOnly: !_isEditing,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Address
                            _buildLabeledField(
                              label: 'Address',
                              controller: _addressController,
                              hintText: 'Enter address',
                              readOnly: !_isEditing,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Phone Number
                            _buildLabeledField(
                              label: 'Phone Number',
                              controller: _phoneController,
                              hintText: 'Enter phone number',
                              keyboardType: TextInputType.phone,
                              readOnly: !_isEditing,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Work Information Section
                            const Text(
                              'Work Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0C1935),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Date Hired
                            _buildLabeledField(
                              label: 'Date Hired',
                              controller: _dateHiredController,
                              hintText: 'Select date',
                              readOnly: true,
                              suffixIcon: Icons.calendar_today_outlined,
                              onTap: () =>
                                  _selectDate(context, _dateHiredController),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Shift Schedule
                            _buildLabeledField(
                              label: 'Shift Schedule',
                              controller: _shiftScheduleController,
                              hintText: 'Enter shift schedule',
                              readOnly: !_isEditing,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Rate
                            _buildLabeledField(
                              label: 'Rate (₱/hour)',
                              controller: _rateController,
                              hintText: 'Enter hourly rate',
                              keyboardType: TextInputType.number,
                              readOnly: !_isEditing,
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
                              GestureDetector(
                                onTap: _pickImage,
                                child: Stack(
                                  children: [
                                    Container(
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
                                            : DecorationImage(
                                                image: NetworkImage(
                                                  widget.worker.avatarUrl,
                                                ),
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                    ),
                                    if (_isEditing)
                                      Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.1,
                                                ),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt,
                                            size: 20,
                                            color: Color(0xFFFF7A18),
                                          ),
                                        ),
                                      ),
                                  ],
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
                                  // Full Name
                                  _buildTextField(
                                    controller: _fullNameController,
                                    hintText: 'Full Name',
                                    readOnly: !_isEditing,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Role
                                  _buildTextField(
                                    controller: _roleController,
                                    hintText: 'Role',
                                    readOnly: !_isEditing,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Address
                                  _buildTextField(
                                    controller: _addressController,
                                    hintText: 'Address',
                                    readOnly: !_isEditing,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Phone Number
                                  _buildTextField(
                                    controller: _phoneController,
                                    hintText: 'Phone Number',
                                    keyboardType: TextInputType.phone,
                                    readOnly: !_isEditing,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Date Hired
                                  _buildTextField(
                                    controller: _dateHiredController,
                                    hintText: 'Date Hired',
                                    readOnly: true,
                                    suffixIcon: Icons.calendar_today_outlined,
                                    onTap: () => _selectDate(
                                      context,
                                      _dateHiredController,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Shift Schedule
                                  _buildTextField(
                                    controller: _shiftScheduleController,
                                    hintText: 'Shift Schedule',
                                    readOnly: !_isEditing,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Rate
                                  _buildTextField(
                                    controller: _rateController,
                                    hintText: 'Rate',
                                    keyboardType: TextInputType.number,
                                    readOnly: !_isEditing,
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
                          ),
                        ),
                      ],
                    ),
            ),

            // Footer Buttons
            if (_isEditing)
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
                              onPressed: _handleSave,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: const Color(0xFFFF7A18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Save Changes',
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
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
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
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
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
                              onPressed: _handleSave,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: const Color(0xFFFF7A18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
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
          ],
        ),
      ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    bool readOnly = false,
    IconData? suffixIcon,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0C1935),
          ),
        ),
        const SizedBox(height: 6),
        _buildTextField(
          controller: controller,
          hintText: hintText,
          keyboardType: keyboardType,
          readOnly: readOnly,
          suffixIcon: suffixIcon,
          onTap: onTap,
          validator: validator,
        ),
      ],
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      style: TextStyle(
        color: readOnly && !_isEditing ? const Color(0xFF0C1935) : null,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
        filled: true,
        fillColor: _isEditing ? const Color(0xFFF9FAFB) : Colors.grey[100],
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, size: 18, color: Colors.grey[600])
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: _isEditing ? Colors.grey[300]! : Colors.grey[200]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: _isEditing ? Colors.grey[300]! : Colors.grey[200]!,
          ),
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
