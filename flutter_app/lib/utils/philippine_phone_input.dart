import 'package:flutter/services.dart';

class PhilippinePhoneInputFormatter extends TextInputFormatter {
  static const int maxDigits = 11;

  static String normalizeDigits(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length > maxDigits
        ? digitsOnly.substring(0, maxDigits)
        : digitsOnly;
  }

  static String formatFromDigits(String digits) {
    if (digits.length <= 4) return digits;
    if (digits.length <= 7) return '${digits.substring(0, 4)}-${digits.substring(4)}';
    return '${digits.substring(0, 4)}-${digits.substring(4, 7)}-${digits.substring(7)}';
  }

  static bool isValidFormattedPhone(String value) {
    return RegExp(r'^09\d{2}-\d{3}-\d{4}$').hasMatch(value);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newDigits = normalizeDigits(newValue.text);
    final formatted = formatFromDigits(newDigits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
