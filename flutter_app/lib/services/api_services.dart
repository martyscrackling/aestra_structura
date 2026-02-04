import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_config.dart';

class ApiService {
  // Configure at build time:
  // flutter build web --dart-define=API_BASE_URL=https://YOUR_BACKEND/api/
  // flutter build apk --dart-define=API_BASE_URL=https://YOUR_BACKEND/api/
  static const String baseUrl = AppConfig.apiBaseUrl;

  static Future<Map<String, dynamic>> registerUser(
    String email,
    String password,
    String firstName,
    String lastName,
  ) async {
    final url = AppConfig.apiUri('users/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password_hash': password,
        'first_name': firstName,
        'last_name': lastName,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to register user: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> loginUser(
    String email,
    String password,
  ) async {
    final url = AppConfig.apiUri('login/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }
}
