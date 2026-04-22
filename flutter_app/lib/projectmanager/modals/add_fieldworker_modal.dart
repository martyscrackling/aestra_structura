import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/subscription_helper.dart';
import '../../services/photo_verifier.dart';
import '../../utils/philippine_phone_input.dart';

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
  static const double _standardHoursPerWeek = 48;

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _payrateController = TextEditingController();
  final _sssTopupController = TextEditingController();
  final _philHealthTopupController = TextEditingController();
  final _pagIbigTopupController = TextEditingController();
  final _customRoleController = TextEditingController();

  String _selectedRole = 'Mason';
  bool _isCustomRole = false;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isLoading = false;
  bool _isPhotoVerifying = false;
  bool _photoVerified = false;

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
    _payrateController.dispose();
    _sssTopupController.dispose();
    _philHealthTopupController.dispose();
    _pagIbigTopupController.dispose();
    _customRoleController.dispose();
    super.dispose();
  }

  double _readMoney(TextEditingController controller) {
    final raw = controller.text.trim().replaceAll(',', '');
    return double.tryParse(raw) ?? 0;
  }

  double _round2(double value) => (value * 100).roundToDouble() / 100;

  double _weeklyToMonthlyEquivalent(double weekly) => (weekly * 52) / 12;

  double _sssWeeklyMin(double weeklySalary) {
    final monthly = _weeklyToMonthlyEquivalent(weeklySalary);
    final salaryBase = math.min(monthly, 35000);
    final monthlyEmployeeShare = salaryBase * 0.05;
    return _round2((monthlyEmployeeShare * 12) / 52);
  }

  double _philHealthWeeklyMin(double weeklySalary) {
    final monthly = _weeklyToMonthlyEquivalent(weeklySalary);
    final salaryBase = math.max(10000, math.min(monthly, 100000));
    final monthlyEmployeeShare = (salaryBase * 0.05) / 2;
    return _round2((monthlyEmployeeShare * 12) / 52);
  }

  double _pagIbigWeeklyMin(double weeklySalary) {
    final monthly = _weeklyToMonthlyEquivalent(weeklySalary);
    final salaryBase = math.min(monthly, 5000);
    final rate = monthly <= 1500 ? 0.01 : 0.02;
    final monthlyEmployeeShare = salaryBase * rate;
    return _round2((monthlyEmployeeShare * 12) / 52);
  }

  double get _hourlyPayrate => math.max(0, _readMoney(_payrateController));
  double get _weeklySalary => _round2(_hourlyPayrate * _standardHoursPerWeek);
  double get _sssTopup => math.max(0, _readMoney(_sssTopupController));
  double get _philHealthTopup =>
      math.max(0, _readMoney(_philHealthTopupController));
  double get _pagIbigTopup => math.max(0, _readMoney(_pagIbigTopupController));

  double get _sssMinDeduction =>
      _weeklySalary > 0 ? _sssWeeklyMin(_weeklySalary) : 0;
  double get _philHealthMinDeduction =>
      _weeklySalary > 0 ? _philHealthWeeklyMin(_weeklySalary) : 0;
  double get _pagIbigMinDeduction =>
      _weeklySalary > 0 ? _pagIbigWeeklyMin(_weeklySalary) : 0;

  double get _sssTotalDeduction => _round2(_sssMinDeduction + _sssTopup);
  double get _philHealthTotalDeduction =>
      _round2(_philHealthMinDeduction + _philHealthTopup);
  double get _pagIbigTotalDeduction =>
      _round2(_pagIbigMinDeduction + _pagIbigTopup);
  double get _totalWeeklyDeduction => _round2(
    _sssTotalDeduction + _philHealthTotalDeduction + _pagIbigTotalDeduction,
  );
  double get _netWeeklyPay => _round2(_weeklySalary - _totalWeeklyDeduction);

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

  int? _parsedCurrentUserId() {
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
      userId: _parsedCurrentUserId(),
    );

    if (!mounted) {
      return result.accepted;
    }

    setState(() {
      _isPhotoVerifying = false;
      _photoVerified = result.accepted;
    });

    if (!result.accepted) {
      _showOverlayMessage(result.message, backgroundColor: Colors.red);
    }

    return result.accepted;
  }

  void _showOverlayMessage(
    String message, {
    Color backgroundColor = const Color(0xFF1F2937),
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!mounted) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: backgroundColor),
      );
      return;
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned.fill(
          child: IgnorePointer(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 14,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    Future.delayed(duration, () {
      if (entry.mounted) {
        entry.remove();
      }
    });
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
    final today = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: today,
    );
    if (picked != null) {
      setState(() {
        controller.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
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
          'phone_number': PhilippinePhoneInputFormatter.normalizeDigits(
            _phoneNumberController.text.trim(),
          ),
          'birthdate': _birthdateController.text.trim().isEmpty
              ? null
              : _birthdateController.text.trim(),
          'role': _isCustomRole
              ? _customRoleController.text.trim()
              : _selectedRole,
          'payrate': _hourlyPayrate > 0 ? _hourlyPayrate : null,
          'weekly_salary': _weeklySalary > 0 ? _weeklySalary : null,
          'sss_weekly_topup': _sssTopup,
          'philhealth_weekly_topup': _philHealthTopup,
          'pagibig_weekly_topup': _pagIbigTopup,
          'sss_weekly_min': _sssMinDeduction,
          'philhealth_weekly_min': _philHealthMinDeduction,
          'pagibig_weekly_min': _pagIbigMinDeduction,
          'sss_weekly_total': _sssTotalDeduction,
          'philhealth_weekly_total': _philHealthTotalDeduction,
          'pagibig_weekly_total': _pagIbigTotalDeduction,
          'total_weekly_deduction': _totalWeeklyDeduction,
          'net_weekly_pay': _netWeeklyPay,
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

        if (!mounted) return;

        // Check for subscription expiry first
        if (SubscriptionHelper.handleResponse(context, response)) {
          setState(() {
            _isLoading = false;
          });
          return;
        }

        if (response.statusCode == 201 || response.statusCode == 200) {
          int? createdFieldWorkerId;
          bool photoRejected = false;
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
                final msg = e.toString();
                final isFaceReject = msg.contains('No human face detected');

                _showOverlayMessage(msg, backgroundColor: Colors.red);

                if (isFaceReject) {
                  photoRejected = true;

                  // Delete the created record so nonhuman photos don't create usable profiles.
                  try {
                    final deleteHeaders = currentUserId != null
                        ? {'X-User-Id': currentUserId.toString()}
                        : <String, String>{};

                    final baseDeleteUri = AppConfig.apiUri(
                      'field-workers/$createdFieldWorkerId/',
                    );

                    final deleteUri =
                        (currentUserId == null && widget.projectId != null)
                        ? AppConfig.apiUri(
                            'field-workers/$createdFieldWorkerId/?project_id=${widget.projectId}',
                          )
                        : baseDeleteUri;

                    await http.delete(
                      deleteUri,
                      headers: deleteHeaders.isEmpty ? null : deleteHeaders,
                    );
                  } catch (_) {
                    // Ignore delete failures; user still sees the rejection message.
                  }
                }
              }
            }
          }

          if (mounted && !photoRejected) {
            _showOverlayMessage(
              'Field worker added successfully!',
              backgroundColor: Colors.green,
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
              _showOverlayMessage(
                'Error: $errorMessage',
                backgroundColor: Colors.red,
              );
            }
          } catch (e) {
            if (mounted) {
              _showOverlayMessage(
                'Error: Failed to add field worker',
                backgroundColor: Colors.red,
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          _showOverlayMessage('Error: $e', backgroundColor: Colors.red);
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
        hintText: 'Phone Number (09XX-XXX-XXXX)',
        keyboardType: TextInputType.phone,
        inputFormatters: [PhilippinePhoneInputFormatter()],
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Required';
          }
          if (!PhilippinePhoneInputFormatter.isValidFormattedPhone(
            value.trim(),
          )) {
            return 'Use 09XX-XXX-XXXX';
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
              isExpanded: true,
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
                final name = region['name'] as String;
                return DropdownMenuItem<int>(
                  value: region['id'] as int,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              selectedItemBuilder: (context) => _regions.map((region) {
                final name = region['name'] as String;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
        isExpanded: true,
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
          final name = province['name'] as String;
          return DropdownMenuItem<int>(
            value: province['id'] as int,
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        selectedItemBuilder: (context) => _provinces.map((province) {
          final name = province['name'] as String;
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
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
        isExpanded: true,
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
          final name = city['name'] as String;
          return DropdownMenuItem<int>(
            value: city['id'] as int,
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        selectedItemBuilder: (context) => _cities.map((city) {
          final name = city['name'] as String;
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
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
        isExpanded: true,
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
          final name = barangay['name'] as String;
          return DropdownMenuItem<int>(
            value: barangay['id'] as int,
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        selectedItemBuilder: (context) => _barangays.map((barangay) {
          final name = barangay['name'] as String;
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
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
        'Salary & Deductions',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      SizedBox(height: spacing),
      _buildTextField(
        controller: _payrateController,
        hintText: 'Payrate Per Hour',
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        validator: (value) {
          final amount = double.tryParse(
            (value ?? '').trim().replaceAll(',', ''),
          );
          if (amount == null || amount <= 0) {
            return 'Hourly payrate is required';
          }
          return null;
        },
      ),
      SizedBox(height: spacing),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Minimum weekly deductions (auto-computed)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            _buildDeductionRow(
              'Computed weekly salary (48 hrs/week)',
              _weeklySalary,
            ),
            const SizedBox(height: 4),
            _buildDeductionRow('SSS (minimum)', _sssMinDeduction),
            _buildDeductionRow('PhilHealth (minimum)', _philHealthMinDeduction),
            _buildDeductionRow('Pag-IBIG (minimum)', _pagIbigMinDeduction),
          ],
        ),
      ),
      SizedBox(height: spacing),
      _buildTextField(
        controller: _sssTopupController,
        hintText: 'SSS top-up (optional, additional only)',
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        validator: (value) {
          final amount = double.tryParse(
            (value ?? '').trim().replaceAll(',', ''),
          );
          if (amount == null && (value ?? '').trim().isNotEmpty) {
            return 'Invalid amount';
          }
          if ((amount ?? 0) < 0) return 'Cannot be negative';
          return null;
        },
      ),
      SizedBox(height: spacing),
      _buildTextField(
        controller: _philHealthTopupController,
        hintText: 'PhilHealth top-up (optional, additional only)',
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        validator: (value) {
          final amount = double.tryParse(
            (value ?? '').trim().replaceAll(',', ''),
          );
          if (amount == null && (value ?? '').trim().isNotEmpty) {
            return 'Invalid amount';
          }
          if ((amount ?? 0) < 0) return 'Cannot be negative';
          return null;
        },
      ),
      SizedBox(height: spacing),
      _buildTextField(
        controller: _pagIbigTopupController,
        hintText: 'Pag-IBIG top-up (optional, additional only)',
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        validator: (value) {
          final amount = double.tryParse(
            (value ?? '').trim().replaceAll(',', ''),
          );
          if (amount == null && (value ?? '').trim().isNotEmpty) {
            return 'Invalid amount';
          }
          if ((amount ?? 0) < 0) return 'Cannot be negative';
          return null;
        },
      ),
      SizedBox(height: spacing),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFD7A8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeductionRow('Total weekly deduction', _totalWeeklyDeduction),
            const SizedBox(height: 4),
            _buildDeductionRow('Estimated net weekly pay', _netWeeklyPay),
          ],
        ),
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

  Widget _buildDeductionRow(String label, double value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ),
        Text(
          'PHP ${value.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0C1935),
          ),
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
    Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
    AutovalidateMode? autovalidateMode,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      autovalidateMode: autovalidateMode,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 2),
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
