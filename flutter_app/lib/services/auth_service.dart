import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_config.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  static const Duration _networkTimeout = Duration(seconds: 30);

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  Map<String, dynamic>? _currentUser;
  bool _isLoggedIn = false;

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  Map<String, dynamic>? get currentUser => _currentUser;

  /// Initialize auth state from local storage
  Future<void> initializeAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      if (userJson != null && isLoggedIn) {
        _currentUser = jsonDecode(userJson);
        _isLoggedIn = true;
        notifyListeners();
      }
    } catch (e) {
      print("Initialize auth error: $e");
    }
  }

  /// Save auth state to local storage
  Future<void> _saveAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_isLoggedIn && _currentUser != null) {
        await prefs.setString('current_user', jsonEncode(_currentUser));
        await prefs.setBool('is_logged_in', true);
      } else {
        await prefs.remove('current_user');
        await prefs.setBool('is_logged_in', false);
      }
    } catch (e) {
      print("Save auth state error: $e");
    }
  }

  /// Login user (can be ProjectManager or Supervisor)
  Future<bool> login(String email, String password) async {
    try {
      print('Attempting login with email: $email');
      print('API_BASE_URL: ${AppConfig.apiBaseUrl}');
      print('Login URL: ${AppConfig.apiUri('login/')}');
      final response = await http
          .post(
            AppConfig.apiUri('login/'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(_networkTimeout);

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          _currentUser = result['user'];
          _isLoggedIn = true;
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
    _currentUser = null;
    _isLoggedIn = false;
    await _saveAuthState();
    notifyListeners();
  }
}
