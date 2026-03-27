import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/inventory_service.dart';
import '../../services/auth_service.dart';

class AddInventoryItemModal extends StatefulWidget {
  const AddInventoryItemModal({super.key});

  @override
  State<AddInventoryItemModal> createState() => _AddInventoryItemModalState();
}

class _AddInventoryItemModalState extends State<AddInventoryItemModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final List<TextEditingController> _serialNumberControllers = [
    TextEditingController(),
  ];
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final List<String> _categoryOptions = const ['Tools', 'Machines'];

  String? _selectedCategory;

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isLoading = false;

  int _parsedQuantity() {
    final parsed = int.tryParse(_quantityController.text.trim()) ?? 1;
    return parsed < 1 ? 1 : parsed;
  }

  void _syncSerialInputsWithQuantity() {
    final quantity = _parsedQuantity();
    final current = _serialNumberControllers.length;
    if (quantity == current) return;

    if (quantity > current) {
      for (int i = current; i < quantity; i++) {
        _serialNumberControllers.add(TextEditingController());
      }
    } else {
      for (int i = current - 1; i >= quantity; i--) {
        _serialNumberControllers[i].dispose();
        _serialNumberControllers.removeAt(i);
      }
    }

    if (mounted) {
      setState(() {});
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
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = image.name;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = AuthService().currentUser?['user_id'];
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Step 1: Create the item
      _syncSerialInputsWithQuantity();
      final serialNumbers = _serialNumberControllers
          .map((controller) => controller.text.trim())
          .where((value) => value.isNotEmpty)
          .toList();

      final result = await InventoryService.addInventoryItem(
        userId: userId,
        name: _nameController.text.trim(),
        category: _selectedCategory!,
        serialNumber: serialNumbers.isNotEmpty ? serialNumbers.first : null,
        serialNumbers: serialNumbers,
        quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      // Step 2: Upload photo if selected
      if (_selectedImageBytes != null && result['item_id'] != null) {
        try {
          await InventoryService.uploadItemPhoto(
            itemId: result['item_id'],
            userId: userId,
            bytes: _selectedImageBytes!,
            filename: _selectedImageName ?? 'item_photo.jpg',
          );
        } catch (e) {
          debugPrint('Photo upload failed: $e');
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    for (final controller in _serialNumberControllers) {
      controller.dispose();
    }
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
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
          maxHeight: isMobile ? screenHeight * 0.9 : 620,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Text(
                    'Add Inventory Item',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0C1935),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: Colors.grey[600],
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // ── Body ──
            Expanded(
              child: isMobile
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Image on top for mobile
                          GestureDetector(
                            onTap: _isLoading ? null : _pickImage,
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
                                          Icons.add_photo_alternate,
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
                          // Info note
                          _buildInfoNote(),
                          const SizedBox(height: 16),
                          // Form for mobile
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildFormFields(),
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
                                onTap: _isLoading ? null : _pickImage,
                                child: Container(
                                  width: 200,
                                  height: 200,
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
                                              Icons.add_photo_alternate,
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
                              if (_selectedImageBytes != null) ...[
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : () => setState(() {
                                          _selectedImageBytes = null;
                                          _selectedImageName = null;
                                        }),
                                  icon: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'Remove photo',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
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
                                  _buildInfoNote(),
                                  const SizedBox(height: 16),
                                  ..._buildFormFields(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            // ── Footer Buttons ──
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
                            onPressed: _isLoading ? null : _submitForm,
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
                                    'Add Item',
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
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.of(context).pop(),
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
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.of(context).pop(),
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
                            onPressed: _isLoading ? null : _submitForm,
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
                                    'Add Item',
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

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'New items will be added with "Available" status',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          enabled: !_isLoading,
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
          ),
          validator: validator,
          onChanged: onChanged,
        ),
      ],
    );
  }

  List<Widget> _buildFormFields() {
    return [
      _buildTextField(
        controller: _nameController,
        hintText: 'Item Name *',
        validator: (value) {
          if (value == null || value.isEmpty) return 'Please enter item name';
          return null;
        },
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: _selectedCategory,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Category *',
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
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: _categoryOptions
                  .map(
                    (category) => DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: _isLoading
                  ? null
                  : (value) => setState(() => _selectedCategory = value),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a category';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTextField(
              controller: _quantityController,
              hintText: 'Number of Units',
              keyboardType: TextInputType.number,
              onChanged: (_) => _syncSerialInputsWithQuantity(),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final qty = int.tryParse(value);
                  if (qty == null || qty < 1) return 'Invalid';
                }
                return null;
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Set number of units to add serial fields for each unit.',
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      ),
      const SizedBox(height: 12),
      ..._buildSerialNumberFields(),
      const SizedBox(height: 12),
      _buildTextField(
        controller: _locationController,
        hintText: 'Location (Optional)',
      ),
      const SizedBox(height: 12),
      _buildTextField(
        controller: _notesController,
        hintText: 'Notes (Optional)',
        maxLines: 3,
      ),
    ];
  }

  List<Widget> _buildSerialNumberFields() {
    final widgets = <Widget>[];
    for (int i = 0; i < _serialNumberControllers.length; i++) {
      widgets.add(
        _buildTextField(
          controller: _serialNumberControllers[i],
          hintText: 'Unit ${i + 1} Serial Number (Optional)',
        ),
      );
      if (i != _serialNumberControllers.length - 1) {
        widgets.add(const SizedBox(height: 10));
      }
    }
    return widgets;
  }
}
