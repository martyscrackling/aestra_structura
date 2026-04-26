import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'app_config.dart';

class PaymentService {
  static Future<Map<String, dynamic>> createCheckoutSession({
    required int userId,
    required int years,
  }) async {
    try {
      final response = await http.post(
        AppConfig.apiUri('subscription/paymongo-checkout/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'subscription_years': years,
        }),
      );

      final contentType = response.headers['content-type'] ?? '';
      
      if (response.statusCode == 200) {
        if (contentType.contains('application/json')) {
          return jsonDecode(response.body);
        } else {
          return {
            'success': false,
            'message': 'Server returned non-JSON response (Status ${response.statusCode})',
          };
        }
      } else {
        // Handle error status codes
        if (contentType.contains('application/json')) {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'message': errorData['message'] ?? 'Server error (${response.statusCode})',
          };
        } else {
          // If it's HTML (likely a 404 or 500 from the hosting provider)
          return {
            'success': false,
            'message': 'Server Error (${response.statusCode}). The requested resource might not be found or the server is down.',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  static Future<bool> launchCheckout(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
