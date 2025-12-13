import 'package:flutter/material.dart';

class ClSettingsPage extends StatefulWidget {
  const ClSettingsPage({super.key});

  @override
  State<ClSettingsPage> createState() => _ClSettingsPageState();
}

class _ClSettingsPageState extends State<ClSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstName = TextEditingController(text: 'Barney');
  final TextEditingController _lastName = TextEditingController(text: 'Mercado');
  final TextEditingController _email = TextEditingController(text: 'client@Structura.com');
  final TextEditingController _contact = TextEditingController(text: '0976-537-4124');
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Settings', style: TextStyle(color: Color(0xFF0C1935))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('First name:'),
              TextFormField(controller: _firstName, decoration: _fieldDecoration(), validator: (v) => (v==null || v.trim().isEmpty) ? 'Required' : null),
              const SizedBox(height: 12),

              _label('Last name:'),
              TextFormField(controller: _lastName, decoration: _fieldDecoration(), validator: (v) => (v==null || v.trim().isEmpty) ? 'Required' : null),
              const SizedBox(height: 12),

              _label('Email:'),
              TextFormField(controller: _email, decoration: _fieldDecoration(), keyboardType: TextInputType.emailAddress, validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(v)) return 'Invalid email';
                return null;
              }),
              const SizedBox(height: 12),

              _label('Contact info:'),
              TextFormField(controller: _contact, decoration: _fieldDecoration(), keyboardType: TextInputType.phone),
              const SizedBox(height: 12),

              _label('Enter new password:'),
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                decoration: _fieldDecoration().copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _label('Confirm new password:'),
              TextFormField(
                controller: _confirm,
                obscureText: _obscureConfirm,
                decoration: _fieldDecoration().copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (_password.text.isNotEmpty && v != _password.text) return 'Passwords do not match';
                  return null;
                },
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0C1935)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF0C1935))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          // Here you would send data to backend.
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0C1935),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save Edit'),
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
