import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/app_config.dart';
import '../services/auth_service.dart';
import '../projectmanager/modals/upgrade_plan_modal.dart';

/// Account, preferences, security, and danger zone — shared by PM and Supervisor.
class AccountSettingsView extends StatefulWidget {
  const AccountSettingsView({super.key});

  @override
  State<AccountSettingsView> createState() => _AccountSettingsViewState();
}

class _AccountSettingsViewState extends State<AccountSettingsView> {
  bool emailUpdates = true;
  bool smsAlerts = false;
  bool _isSavingAccount = false;

  final AuthService _authService = AuthService();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  String _initialFirstName = '';
  String _initialMiddleName = '';
  String _initialLastName = '';
  String _initialEmail = '';
  String _initialPhone = '';
  String _subscriptionStatus = '';
  DateTime? _subscriptionStartDate;
  DateTime? _subscriptionEndDate;
  DateTime? _trialStartDate;
  DateTime? _trialEndDate;
  int _subscriptionYears = 0;

  @override
  void initState() {
    super.initState();
    _loadAccountInfo();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadAccountInfo() async {
    final currentUser = _authService.currentUser;
    _setAccountFields(currentUser);

    final userIdRaw = currentUser?['user_id'];
    final userId = userIdRaw is int
        ? userIdRaw
        : int.tryParse(userIdRaw?.toString() ?? '');

    if (userId == null) {
      return;
    }

    try {
      final response = await http
          .get(AppConfig.apiUri('users/$userId/'))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      _setAccountFields(decoded);
      await _authService.updateLocalUserFields({
        'email': decoded['email'],
        'first_name': decoded['first_name'],
        'middle_name': decoded['middle_name'],
        'last_name': decoded['last_name'],
        'phone': decoded['phone'],
        'phone_number': decoded['phone'],
      });
    } on TimeoutException {
      // Keep locally available profile values when request times out.
    } catch (_) {
      // Keep locally available profile values when request fails.
    }
  }

  void _setAccountFields(Map<String, dynamic>? source) {
    String readString(String key) {
      final value = source?[key];
      if (value == null) {
        return '';
      }
      return value.toString().trim();
    }

    DateTime? readDate(String key) {
      final raw = source?[key];
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    final email = readString('email');
    final firstName = readString('first_name');
    final middleName = readString('middle_name');
    final lastName = readString('last_name');
    final phone = readString('phone').isNotEmpty
        ? readString('phone')
        : readString('phone_number');
    final subscriptionStatus = readString('subscription_status').toLowerCase();
    final subscriptionYearsRaw = source?['subscription_years'];
    final subscriptionYears = subscriptionYearsRaw is int
        ? subscriptionYearsRaw
        : int.tryParse(subscriptionYearsRaw?.toString() ?? '') ?? 0;

    if (!mounted) {
      return;
    }

    setState(() {
      _initialFirstName = firstName;
      _initialMiddleName = middleName;
      _initialLastName = lastName;
      _initialEmail = email;
      _initialPhone = phone;
      _subscriptionStatus = subscriptionStatus;
      _subscriptionStartDate = readDate('subscription_start_date');
      _subscriptionEndDate = readDate('subscription_end_date');
      _trialStartDate = readDate('trial_start_date');
      _trialEndDate = readDate('trial_end_date');
      _subscriptionYears = subscriptionYears;

      _firstNameController.text = firstName;
      _middleNameController.text = middleName;
      _lastNameController.text = lastName;
      _emailController.text = email;
      _phoneNumberController.text = phone;
    });
  }

  bool get _hasSubscriptionData =>
      _subscriptionStatus.isNotEmpty ||
      _subscriptionStartDate != null ||
      _subscriptionEndDate != null ||
      _trialStartDate != null ||
      _trialEndDate != null;

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    final local = dt.toLocal();
    final y = local.year.toString();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _durationText(DateTime? endDate) {
    if (endDate == null) return 'N/A';
    final now = DateTime.now();
    final localNow = DateTime(now.year, now.month, now.day);
    final localEnd = DateTime(
      endDate.toLocal().year,
      endDate.toLocal().month,
      endDate.toLocal().day,
    );
    final remainingDays = localEnd.difference(localNow).inDays;
    if (remainingDays < 0) return 'Expired';
    if (remainingDays == 0) return 'Ends today';
    return '$remainingDays day${remainingDays == 1 ? '' : 's'} remaining';
  }

  Widget _buildSubscriptionCard() {
    final isTrial = _subscriptionStatus == 'trial';
    final isActive = _subscriptionStatus == 'active';
    final endDate = isTrial ? _trialEndDate : _subscriptionEndDate;
    final startDate = isTrial ? _trialStartDate : _subscriptionStartDate;
    final statusLabel = isTrial
        ? 'Trial'
        : (isActive ? 'Subscription' : (_subscriptionStatus.isEmpty ? 'Unknown' : _subscriptionStatus));
    final actionLabel = isActive
        ? 'Upgrade Subscription'
        : 'Activate Subscription';

    return SettingsCard(
      title: 'Subscription',
      description: 'Current plan duration and validity',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _SubscriptionInfoLine(label: 'Status', value: statusLabel),
              _SubscriptionInfoLine(
                label: 'Duration',
                value: _durationText(endDate),
              ),
              _SubscriptionInfoLine(
                label: 'Start date',
                value: _formatDate(startDate),
              ),
              _SubscriptionInfoLine(
                label: 'End date',
                value: _formatDate(endDate),
              ),
              if (!isTrial && _subscriptionYears > 0)
                _SubscriptionInfoLine(
                  label: 'Plan length',
                  value:
                      '$_subscriptionYears year${_subscriptionYears == 1 ? '' : 's'}',
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () => UpgradePlanModal.show(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A18),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.workspace_premium_outlined, size: 18),
              label: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetAccountForm() {
    setState(() {
      _firstNameController.text = _initialFirstName;
      _middleNameController.text = _initialMiddleName;
      _lastNameController.text = _initialLastName;
      _emailController.text = _initialEmail;
      _phoneNumberController.text = _initialPhone;
    });
  }

  Future<void> _saveAccountChanges() async {
    final userIdRaw = _authService.currentUser?['user_id'];
    final userId = userIdRaw is int
        ? userIdRaw
        : int.tryParse(userIdRaw?.toString() ?? '');

    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save: user session not found.'),
        ),
      );
      return;
    }

    final firstName = _firstNameController.text.trim();
    final middleName = _middleNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneNumberController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('First Name, Last Name, and Email are required.'),
        ),
      );
      return;
    }

    setState(() => _isSavingAccount = true);

    try {
      final response = await http
          .patch(
            AppConfig.apiUri('users/$userId/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'first_name': firstName,
              'middle_name': middleName,
              'last_name': lastName,
              'email': email,
              'phone': phone,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save changes (${response.statusCode}).'),
          ),
        );
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        _setAccountFields(decoded);
        await _authService.updateLocalUserFields({
          'email': decoded['email'],
          'first_name': decoded['first_name'],
          'middle_name': decoded['middle_name'],
          'last_name': decoded['last_name'],
          'phone': decoded['phone'],
          'phone_number': decoded['phone'],
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account details updated successfully.')),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request timed out. Please try again.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save changes.')));
    } finally {
      if (mounted) {
        setState(() => _isSavingAccount = false);
      }
    }
  }

  Future<void> _showChangePasswordModal() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool isSubmitting = false;

    final email = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : (_authService.currentUser?['email']?.toString().trim() ?? '');

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              title: const Text(
                'Change Password',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C1935),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Old Password',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: oldPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'New Password',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final oldPassword = oldPasswordController.text.trim();
                          final newPassword = newPasswordController.text.trim();

                          if (oldPassword.isEmpty || newPassword.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter old and new password.',
                                ),
                              ),
                            );
                            return;
                          }

                          if (email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Email not found for this user.'),
                              ),
                            );
                            return;
                          }

                          setModalState(() => isSubmitting = true);

                          final changed = await _authService.changePassword(
                            email: email,
                            currentPassword: oldPassword,
                            newPassword: newPassword,
                          );

                          if (!mounted) return;

                          if (changed) {
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password changed successfully.'),
                              ),
                            );
                          } else {
                            setModalState(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Failed to change password. Check old password and try again.',
                                ),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Update Password',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    oldPasswordController.dispose();
    newPasswordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: isMobile ? 16 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingsIntro(
              onReset: _resetAccountForm,
              onSave: _saveAccountChanges,
              isSaving: _isSavingAccount,
            ),
            const SizedBox(height: 24),
            if (_hasSubscriptionData) ...[
              _buildSubscriptionCard(),
              const SizedBox(height: 20),
            ],
            SettingsCard(
              title: 'Account',
              description: null,
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SettingsTextField(
                          label: 'First Name',
                          controller: _firstNameController,
                        ),
                        const SizedBox(height: 16),
                        _SettingsTextField(
                          label: 'Middle Name',
                          controller: _middleNameController,
                        ),
                        const SizedBox(height: 16),
                        _SettingsTextField(
                          label: 'Last Name',
                          controller: _lastNameController,
                        ),
                        const SizedBox(height: 16),
                        _SettingsTextField(
                          label: 'Email',
                          controller: _emailController,
                        ),
                        const SizedBox(height: 16),
                        _SettingsTextField(
                          label: 'Phone Number',
                          controller: _phoneNumberController,
                        ),
                      ],
                    )
                  : Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: 260,
                          child: _SettingsTextField(
                            label: 'First Name',
                            controller: _firstNameController,
                          ),
                        ),
                        SizedBox(
                          width: 260,
                          child: _SettingsTextField(
                            label: 'Middle Name',
                            controller: _middleNameController,
                          ),
                        ),
                        SizedBox(
                          width: 260,
                          child: _SettingsTextField(
                            label: 'Last Name',
                            controller: _lastNameController,
                          ),
                        ),
                        SizedBox(
                          width: 260,
                          child: _SettingsTextField(
                            label: 'Email',
                            controller: _emailController,
                          ),
                        ),
                        SizedBox(
                          width: 260,
                          child: _SettingsTextField(
                            label: 'Phone Number',
                            controller: _phoneNumberController,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            SettingsCard(
              title: 'Preferences',
              description: 'Choose how Structura behaves for you',
              child: Column(
                children: [
                  _SwitchTile(
                    label: 'Email updates',
                    subtitle: 'Receive a digest when project milestones change',
                    value: emailUpdates,
                    onChanged: (value) => setState(() => emailUpdates = value),
                  ),
                  _SwitchTile(
                    label: 'SMS alerts',
                    subtitle: 'Send urgent site notices to my phone',
                    value: smsAlerts,
                    onChanged: (value) => setState(() => smsAlerts = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SettingsCard(
              title: 'Security',
              description: 'Keep your account protected',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isMobile) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0C1935),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Last changed 54 days ago',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        SizedBox(height: 12),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _showChangePasswordModal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7A18),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Change password',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ] else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Password',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0C1935),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Last changed 54 days ago',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: _showChangePasswordModal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF7A18),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Change password',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SettingsCard(
              title: 'Danger Zone',
              description: 'Irreversible actions',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Deactivate account',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0C1935),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Temporarily suspend your Structura workspace access.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: isMobile ? double.infinity : null,
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF43F5E),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Deactivate',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isMobile ? 80 : 20),
          ],
        ),
    );
  }
}

class _SettingsIntro extends StatelessWidget {
  const _SettingsIntro({
    required this.onReset,
    required this.onSave,
    required this.isSaving,
  });

  final VoidCallback onReset;
  final VoidCallback onSave;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Workspace Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0C1935),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage account details, preferences, and security.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isSaving ? null : onReset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0C1935),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Reset',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isSaving ? null : onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Workspace Settings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0C1935),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Manage account details, preferences, and security.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          height: 40,
          child: ElevatedButton(
            onPressed: isSaving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: isSaving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save changes',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.title,
    this.description,
    required this.child,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0C1935),
            ),
          ),
          if (description != null && description!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SettingsTextField extends StatelessWidget {
  const _SettingsTextField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0C1935),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
      ),
      activeColor: const Color(0xFFFF7A18),
    );
  }
}

class _SubscriptionInfoLine extends StatelessWidget {
  const _SubscriptionInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0C1935),
            ),
          ),
        ],
      ),
    );
  }
}
