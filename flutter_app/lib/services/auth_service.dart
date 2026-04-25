import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_config.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  static const Duration _networkTimeout = Duration(seconds: 30);
  static const Duration _defaultSessionDuration = Duration(hours: 8);
  static const Duration _rememberedSessionDuration = Duration(days: 30);

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  Map<String, dynamic>? _currentUser;
  bool _isLoggedIn = false;
  DateTime? _sessionExpiresAt;

  // Getters
  bool get isLoggedIn => _isLoggedIn && _isSessionActive;
  Map<String, dynamic>? get currentUser => _currentUser;
  DateTime? get sessionExpiresAt => _sessionExpiresAt;
  bool get hasRememberedSession =>
      _sessionExpiresAt != null &&
      _sessionExpiresAt!.difference(DateTime.now()) >
          const Duration(days: 7);

  bool get _isSessionActive {
    if (_sessionExpiresAt == null) return false;
    return DateTime.now().isBefore(_sessionExpiresAt!);
  }

  /// Update locally cached user fields and persist them.
  Future<void> updateLocalUserFields(Map<String, dynamic> updates) async {
    if (_currentUser == null) return;
    _currentUser = {..._currentUser!, ...updates};
    await _saveAuthState();
    notifyListeners();
  }

  /// Initialize auth state from local storage
  Future<void> initializeAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      final sessionExpiresAtMs = prefs.getInt('session_expires_at_ms');

      if (userJson != null && isLoggedIn && sessionExpiresAtMs != null) {
        _currentUser = jsonDecode(userJson);
        _isLoggedIn = true;
        _sessionExpiresAt = DateTime.fromMillisecondsSinceEpoch(sessionExpiresAtMs);

        if (!_isSessionActive) {
          await _clearAuthState();
          return;
        }

        notifyListeners();
        return;
      }

      await _clearAuthState();
    } catch (e) {
      print("Initialize auth error: $e");
    }
  }

  /// Save auth state to local storage
  Future<void> _saveAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_isLoggedIn && _currentUser != null && _sessionExpiresAt != null) {
        await prefs.setString('current_user', jsonEncode(_currentUser));
        await prefs.setBool('is_logged_in', true);
        await prefs.setInt(
          'session_expires_at_ms',
          _sessionExpiresAt!.millisecondsSinceEpoch,
        );
      } else {
        await _clearAuthState();
      }
    } catch (e) {
      print("Save auth state error: $e");
    }
  }

  Future<void> _clearAuthState() async {
    _currentUser = null;
    _isLoggedIn = false;
    _sessionExpiresAt = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('session_expires_at_ms');
  }

  /// Login user (can be ProjectManager or Supervisor)
  Future<bool> login(String email, String password, {bool rememberMe = false}) async {
    email = email.trim();
    try {
      print('Attempting login with email: $email');
      print('API_BASE_URL: ${AppConfig.apiBaseUrl}');
      print('Login URL: ${AppConfig.apiUri('login/')}');

      // Retry once on 502/503/504 to survive Render cold starts.
      http.Response response = await _postJsonWithRetry(
        AppConfig.apiUri('login/'),
        {"email": email, "password": password},
      );

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          _currentUser = result['user'];
          _isLoggedIn = true;
          _sessionExpiresAt = DateTime.now().add(
            rememberMe ? _rememberedSessionDuration : _defaultSessionDuration,
          );
          await _saveAuthState();
          notifyListeners();
          return true;
        }
      }
      return false;
    } on TimeoutException catch (e) {
      print('Login timeout after ${_networkTimeout.inSeconds}s: $e');
      return false;
    } catch (e) {
      print("Login error: $e");
      return false;
    }
  }

  /// POST JSON with a single retry for transient gateway errors (502/503/504)
  /// that are common on free-tier hosts during cold start.
  Future<http.Response> _postJsonWithRetry(
    Uri url,
    Map<String, dynamic> body,
  ) async {
    final encoded = jsonEncode(body);
    const headers = {"Content-Type": "application/json"};

    Future<http.Response> doPost() =>
        http.post(url, headers: headers, body: encoded).timeout(_networkTimeout);

    final first = await doPost();
    if (first.statusCode == 502 || first.statusCode == 503 || first.statusCode == 504) {
      print('Transient ${first.statusCode} from $url — retrying once after backend wake-up.');
      await Future.delayed(const Duration(seconds: 3));
      return doPost();
    }
    return first;
  }

  /// Change password for Supervisor/Client accounts.
  Future<bool> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            AppConfig.apiUri('change-password/'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "email": email,
              "current_password": currentPassword,
              "new_password": newPassword,
            }),
          )
          .timeout(_networkTimeout);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } on TimeoutException catch (e) {
      print('Change password timeout after ${_networkTimeout.inSeconds}s: $e');
      return false;
    } catch (e) {
      print("Change password error: $e");
      return false;
    }
  }

  Future<bool> signup(
    String email,
    String password,
    String firstName,
    String lastName,
  ) async {
    try {
      print('Attempting signup with email: $email');
      final response = await http
          .post(
            AppConfig.apiUri('users/'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "email": email,
              "password_hash": password,
              "first_name": firstName,
              "last_name": lastName,
            }),
          )
          .timeout(_networkTimeout);

      print('Signup response status: ${response.statusCode}');
      print('Signup response body: ${response.body}');

      if (response.statusCode == 201) {
        final result = jsonDecode(response.body);
        _currentUser = result;
        _isLoggedIn = true;
        await _saveAuthState();
        notifyListeners();
        return true;
      } else if (response.statusCode == 400) {
        print('Signup validation error: ${response.body}');
      }
      return false;
    } on TimeoutException catch (e) {
      print('Signup timeout after ${_networkTimeout.inSeconds}s: $e');
      return false;
    } catch (e) {
      print("Signup error: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> sendSignupOtp(String email) async {
    try {
      final response = await http
          .post(
            AppConfig.apiUri('signup/send-otp/'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email}),
          )
          .timeout(_networkTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'OTP sent successfully',
          'resend_available_in_seconds':
              data['resend_available_in_seconds'] ?? 60,
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to send OTP',
        'retry_after_seconds': data['retry_after_seconds'],
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to send OTP: $e'};
    }
  }

  Future<Map<String, dynamic>> verifySignupOtp(String email, String otp) async {
    try {
      final response = await http
          .post(
            AppConfig.apiUri('signup/verify-otp/'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "otp": otp}),
          )
          .timeout(_networkTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Email verified successfully',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'OTP verification failed',
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to verify OTP: $e'};
    }
  }

  /// Update user info
  Future<bool> updateUserInfo({
    required String firstName,
    required String lastName,
    String? middleName,
    String? birthdate,
    String? phone,
  }) async {
    if (_currentUser == null) return false;

    try {
      final userId = _currentUser!['user_id'];
      final updatePayload = {
        "first_name": firstName,
        "last_name": lastName,
        if (middleName?.isNotEmpty ?? false) "middle_name": middleName,
        if (phone?.isNotEmpty ?? false) "phone": phone,
        if (birthdate?.isNotEmpty ?? false) "birthdate": birthdate,
      };

      final response = await http
          .patch(
            AppConfig.apiUri('users/$userId/'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(updatePayload),
          )
          .timeout(_networkTimeout);

      if (response.statusCode == 200) {
        _currentUser = jsonDecode(response.body);
        notifyListeners();
        return true;
      }
      return false;
    } on TimeoutException catch (e) {
      print('Update user info timeout after ${_networkTimeout.inSeconds}s: $e');
      return false;
    } catch (e) {
      print("Update user info error: $e");
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    await _clearAuthState();
    notifyListeners();
  }
}
