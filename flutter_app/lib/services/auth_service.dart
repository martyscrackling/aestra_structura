import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  Map<String, dynamic>? _currentUser;
  bool _isLoggedIn = false;
  final String apiUrl = "http://127.0.0.1:8000/api/";

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
      final response = await http
          .post(
            Uri.parse("${apiUrl}login/"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(const Duration(seconds: 10));

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
            Uri.parse("${apiUrl}users/"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "email": email,
              "password_hash": password,
              "first_name": firstName,
              "last_name": lastName,
            }),
          )
          .timeout(const Duration(seconds: 10));

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
            Uri.parse("${apiUrl}users/$userId/"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(updatePayload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _currentUser = jsonDecode(response.body);
        notifyListeners();
        return true;
      }
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
