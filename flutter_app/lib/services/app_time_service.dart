import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTimeService {
  static const String _overrideKey = 'app_time_override_iso';
  static DateTime? _overrideNow;

  // Notifier allows UI pages to refresh when test time changes.
  static final ValueNotifier<DateTime?> overrideNotifier =
      ValueNotifier<DateTime?>(null);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_overrideKey);
    if (iso == null || iso.trim().isEmpty) {
      _overrideNow = null;
      overrideNotifier.value = null;
      return;
    }

    final parsed = DateTime.tryParse(iso);
    _overrideNow = parsed;
    overrideNotifier.value = parsed;
  }

  static DateTime now() {
    return _overrideNow ?? DateTime.now();
  }

  static DateTime? get overrideNow => _overrideNow;

  static Future<void> setOverride(DateTime value) async {
    final normalized = DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
    );
    _overrideNow = normalized;
    overrideNotifier.value = normalized;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_overrideKey, normalized.toIso8601String());
  }

  static Future<void> clearOverride() async {
    _overrideNow = null;
    overrideNotifier.value = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_overrideKey);
  }
}
