import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../workforce_page.dart';
import '../../services/app_config.dart';
import '../../services/auth_service.dart';

/// Same pattern as [ViewEditClientModal]: opens ready to edit, loads from API, PATCH on save.
class ViewEditWorkerModal extends StatefulWidget {
  const ViewEditWorkerModal({super.key, required this.worker});

  final WorkerInfo worker;

  @override
  State<ViewEditWorkerModal> createState() => _ViewEditWorkerModalState();
}

class _ViewEditWorkerModalState extends State<ViewEditWorkerModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _dateHiredController;
  late TextEditingController _shiftScheduleController;
  late TextEditingController _rateController;

  String? _fieldWorkerRole;
  static const _fieldWorkerRoles = <String>[
    'Mason',
    'Painter',
    'Electrician',
    'Carpenter',
  ];

  XFile? _selectedImage;
  Uint8List? _pickedImageBytes;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  int? get _pmUserId {
    final r = AuthService().currentUser?['user_id'];
    if (r is int) return r;
    return int.tryParse('${r ?? ''}');
  }

  bool get _isSupervisor => widget.worker.type == 'Supervisor';

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _dateHiredController = TextEditingController();
    _shiftScheduleController = TextEditingController();
    _rateController = TextEditingController();
    _loadDetails();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dateHiredController.dispose();
    _shiftScheduleController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  String _str(dynamic v) => (v ?? '').toString().trim();

  String _formatCreated(dynamic raw) {
    final s = _str(raw);
    if (s.isEmpty) return '—';
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}-${dt.year}';
  }

  List<String> _splitFirstLast(String full) {
    final t = full.trim();
    if (t.isEmpty) return ['', ''];
    final i = t.indexOf(' ');
    if (i < 0) return [t, ''];
    return [t.substring(0, i), t.substring(i + 1).trim()];
  }

  String? _errMsg(String body) {
    try {
      final d = jsonDecode(body);
      if (d is Map && d['detail'] != null) return d['detail'].toString();
    } catch (_) {}
    return null;
  }

  Future<void> _loadDetails() async {
    final userId = _pmUserId;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _loadError = 'Not signed in as project manager.';
      });
      return;
    }

    try {
      late final http.Response response;
      if (_isSupervisor) {
        final id = widget.worker.supervisorId;
        if (id == null) {
          setState(() {
            _isLoading = false;
            _loadError = 'Missing supervisor id.';
          });
          return;
        }
        response = await http.get(
          AppConfig.apiUri('supervisors/$id/?user_id=$userId'),
        );
      } else {
        final id = widget.worker.fieldWorkerId;
        if (id == null) {
          setState(() {
            _isLoading = false;
            _loadError = 'Missing field worker id.';
          });
          return;
        }
        response = await http.get(
          AppConfig.apiUri('field-workers/$id/?user_id=$userId'),
        );
      }

      if (response.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _loadError = _errMsg(response.body) ?? 'Failed to load (HTTP ${response.statusCode})';
        });
        return;
      }

      final m = Map<String, dynamic>.from(
        jsonDecode(response.body) as Map,
      );

      if (!mounted) return;
      setState(() {
        final fn = _str(m['first_name']);
        final ln = _str(m['last_name']);
        _fullNameController.text = [fn, ln].where((e) => e.isNotEmpty).join(' ').trim();
        if (_fullNameController.text.isEmpty) {
          _fullNameController.text = widget.worker.name;
        }
        _emailController.text = _isSupervisor
            ? _str(m['email'])
            : 'N/A';
        _phoneController.text = _str(m['phone_number']);
        if (_phoneController.text.isEmpty) {
          _phoneController.text = widget.worker.phone;
        }
        _dateHiredController.text = _formatCreated(m['created_at']);
        final shift = m['shift_schedule'];
        if (shift is Map) {
          _shiftScheduleController.text = jsonEncode(shift);
        } else {
          _shiftScheduleController.text = _str(shift);
        }
        if (_shiftScheduleController.text.isEmpty) {
          _shiftScheduleController.text = '—';
        }
        final pr = m['payrate'];
        _rateController.text = pr == null
            ? ''
            : (pr is num ? pr.toString() : pr.toString());
        _fieldWorkerRole = _str(m['role']);
        if (_fieldWorkerRole!.isEmpty) {
          _fieldWorkerRole = 'Mason';
        }
        if (!_fieldWorkerRoles.contains(_fieldWorkerRole)) {
          _fieldWorkerRole = _fieldWorkerRoles.first;
        }
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _pickImage() async {
    if (_isLoading || _isSaving) return;
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedImage = image;
      _pickedImageBytes = bytes;
    });
  }

  Future<void> _uploadSupervisorPhoto(int supervisorId, int userId) async {
    if (_selectedImage == null || _pickedImageBytes == null) return;
    final uri = AppConfig.apiUri(
      'supervisors/$supervisorId/upload-photo/?user_id=$userId',
    );
    final request = http.MultipartRequest('POST', uri);
    request.headers['X-User-Id'] = userId.toString();
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        _pickedImageBytes!,
        filename: _selectedImage!.name,
      ),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errMsg(response.body) ?? 'Photo upload failed.');
    }
  }

  Future<void> _uploadFieldWorkerPhoto(int fieldWorkerId, int userId) async {
    if (_selectedImage == null || _pickedImageBytes == null) return;
    final uri = AppConfig.apiUri(
      'field-workers/$fieldWorkerId/upload-photo/?user_id=$userId',
    );
    final request = http.MultipartRequest('POST', uri);
    request.headers['X-User-Id'] = userId.toString();
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        _pickedImageBytes!,
        filename: _selectedImage!.name,
      ),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errMsg(response.body) ?? 'Photo upload failed.');
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = _pmUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not signed in as project manager.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final names = _splitFirstLast(_fullNameController.text);
      final firstName = names[0].isNotEmpty ? names[0] : names[1];
      final lastName = names[0].isNotEmpty ? names[1] : '';
      final pay = double.tryParse(_rateController.text.trim());

      if (_isSupervisor) {
        final id = widget.worker.supervisorId;
        if (id == null) return;
        final body = <String, dynamic>{
          'first_name': firstName,
          'last_name': lastName,
          'phone_number': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
        };
        if (pay != null) body['payrate'] = pay;
        final response = await http.patch(
          AppConfig.apiUri('supervisors/$id/?user_id=$userId'),
          headers: {
            'Content-Type': 'application/json',
            'X-User-Id': userId.toString(),
          },
          body: jsonEncode(body),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            _errMsg(response.body) ?? 'Save failed (${response.statusCode})',
          );
        }
        if (_selectedImage != null) {
          await _uploadSupervisorPhoto(id, userId);
        }
      } else {
        final id = widget.worker.fieldWorkerId;
        if (id == null) return;
        final body = <String, dynamic>{
          'first_name': firstName,
          'last_name': lastName,
          'phone_number': _phoneController.text.trim(),
          'role': _fieldWorkerRole ?? 'Mason',
        };
        if (pay != null) body['payrate'] = pay;
        final response = await http.patch(
          AppConfig.apiUri('field-workers/$id/?user_id=$userId'),
          headers: {
            'Content-Type': 'application/json',
            'X-User-Id': userId.toString(),
          },
          body: jsonEncode(body),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            _errMsg(response.body) ?? 'Save failed (${response.statusCode})',
          );
        }
        if (_selectedImage != null) {
          await _uploadFieldWorkerPhoto(id, userId);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isNotEmpty ? msg : 'Failed to save changes.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    const accent = Color(0xFFFF7A18);
    const navy = Color(0xFF0C1935);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: isMobile ? 24 : 40,
      ),
      child: Container(
        width: isMobile ? double.infinity : 700,
        constraints: const BoxConstraints(maxHeight: 640),
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
                  const Text(
                    'Edit profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                  const Spacer(),
                  if (_isSaving)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 52,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: _pickedImageBytes != null
                                        ? MemoryImage(_pickedImageBytes!)
                                        : (widget.worker.avatarUrl
                                                .trim()
                                                .isNotEmpty
                                            ? NetworkImage(
                                                widget.worker.avatarUrl,
                                              )
                                            : null),
                                    child: _pickedImageBytes != null ||
                                            widget.worker.avatarUrl
                                                .trim()
                                                .isNotEmpty
                                        ? null
                                        : const Icon(
                                            Icons.person,
                                            size: 56,
                                            color: Color(0xFF6B7280),
                                          ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _pickImage,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: accent,
                                          shape: BoxShape.circle,
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
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                widget.worker.type,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Personal',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: navy,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _fullNameController,
                              decoration: _decoration('Full name', hint: 'Full name'),
                              textCapitalization: TextCapitalization.words,
                              readOnly: _isSaving,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            if (_isSupervisor)
                              TextFormField(
                                controller: _emailController,
                                decoration: _decoration('Email', hint: 'Email'),
                                keyboardType: TextInputType.emailAddress,
                                readOnly: _isSaving,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  if (!v.contains('@')) return 'Invalid email';
                                  return null;
                                },
                              ),
                            if (_isSupervisor) const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              decoration: _decoration('Phone', hint: 'Phone number'),
                              keyboardType: TextInputType.phone,
                              readOnly: _isSaving,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(11),
                              ],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                            if (!_isSupervisor) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _fieldWorkerRole,
                                decoration: _decoration('Role', hint: 'Role'),
                                items: _fieldWorkerRoles
                                    .map(
                                      (r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(r),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _isSaving
                                    ? null
                                    : (v) => setState(() {
                                        _fieldWorkerRole = v;
                                      }),
                              ),
                            ] else
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Role is always Supervisor for this account.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 20),
                            const Text(
                              'Work',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: navy,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _dateHiredController,
                              decoration: _decoration(
                                'Date added (on record)',
                                hint: '—',
                                icon: Icons.event_outlined,
                              ),
                              readOnly: true,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _shiftScheduleController,
                              decoration: _decoration(
                                'Shift / schedule (read-only from system)',
                                hint: '—',
                              ),
                              readOnly: true,
                              minLines: 1,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _rateController,
                              decoration: _decoration(
                                'Rate (₱/hr)',
                                hint: '0.00',
                              ),
                              readOnly: _isSaving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading || _loadError != null || _isSaving
                          ? null
                          : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save changes'),
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

  InputDecoration _decoration(
    String label, {
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      suffixIcon: icon != null
          ? Icon(icon, size: 18, color: Colors.grey[600])
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
