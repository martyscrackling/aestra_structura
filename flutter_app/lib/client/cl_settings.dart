import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/app_config.dart';
import '../services/auth_service.dart';

class ClSettingsPage extends StatefulWidget {
  const ClSettingsPage({super.key});

  @override
  State<ClSettingsPage> createState() => _ClSettingsPageState();
}

class _ClSettingsPageState extends State<ClSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _contact = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final auth = AuthService();
    final user = auth.currentUser;

    _firstName.text = (user?['first_name'] as String?) ?? '';
    _lastName.text = (user?['last_name'] as String?) ?? '';
    _email.text = (user?['email'] as String?) ?? '';

    final clientIdRaw = user?['client_id'];
    final clientId = clientIdRaw is int
        ? clientIdRaw
        : int.tryParse(clientIdRaw?.toString() ?? '');

    if (clientId == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    try {
      final response = await http.get(AppConfig.apiUri('clients/$clientId/'));
      if (response.statusCode != 200) {
        throw Exception('Failed to load profile');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected profile response');
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _firstName.text = (decoded['first_name'] as String?) ?? _firstName.text;
        _lastName.text = (decoded['last_name'] as String?) ?? _lastName.text;
        _email.text = (decoded['email'] as String?) ?? _email.text;
        _contact.text = (decoded['phone_number'] as String?) ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = AuthService();
    final user = auth.currentUser;
    final clientIdRaw = user?['client_id'];
    final clientId = clientIdRaw is int
        ? clientIdRaw
        : int.tryParse(clientIdRaw?.toString() ?? '');

    if (clientId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to save profile.')));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final payload = <String, dynamic>{
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'email': _email.text.trim(),
        'phone_number': _contact.text.trim(),
      };

      if (_password.text.isNotEmpty) {
        payload['password_hash'] = _password.text;
      }

      final response = await http.patch(
        AppConfig.apiUri('clients/$clientId/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        throw Exception('Save failed');
      }

      await auth.updateLocalUserFields({
        'first_name': payload['first_name'],
        'last_name': payload['last_name'],
        'email': payload['email'],
      });

      if (!mounted) return;
      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to save settings')));
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _contact.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration([String? hintText]) {
    return InputDecoration(
      hintText: hintText,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6.0),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
  );

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Settings',
          style: TextStyle(color: Color(0xFF0C1935)),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.0 : 20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 12),
              ],
              _label('First name:'),
              TextFormField(
                controller: _firstName,
                enabled: !_loading,
                decoration: _fieldDecoration(),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              _label('Last name:'),
              TextFormField(
                controller: _lastName,
                enabled: !_loading,
                decoration: _fieldDecoration(),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              _label('Email:'),
              TextFormField(
                controller: _email,
                enabled: !_loading,
                decoration: _fieldDecoration(),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(v)) {
                    return 'Invalid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              _label('Contact info:'),
              TextFormField(
                controller: _contact,
                enabled: !_loading,
                decoration: _fieldDecoration(),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              _label('Enter new password:'),
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                enabled: !_loading,
                decoration: _fieldDecoration().copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _label('Confirm new password:'),
              TextFormField(
                controller: _confirm,
                obscureText: _obscureConfirm,
                enabled: !_loading,
                decoration: _fieldDecoration().copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (_password.text.isNotEmpty && v != _password.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0C1935)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFF0C1935)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0C1935),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_loading ? 'Saving…' : 'Save Edit'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
