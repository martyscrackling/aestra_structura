import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/app_config.dart';

Future<String?> _fetchUserName(String? userId) async {
  if (userId == null) return null;
  try {
    final response = await http.get(AppConfig.apiUri('users/$userId/'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final name = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
      return name.isNotEmpty ? name : null;
    }
  } catch (_) {}
  return null;
}

class PaymentSuccessPage extends StatelessWidget {
  final String? userId;

  const PaymentSuccessPage({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: FutureBuilder<String?>(
            future: _fetchUserName(userId),
            builder: (context, snapshot) {
              final name = snapshot.data;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 100),
                  const SizedBox(height: 32),
                  const Text(
                    'Payment Successful!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0B1437),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Thank you for your purchase. Your license has been activated.\n${name != null ? "User: $name" : (userId != null ? "User ID: $userId" : "")}',
                    style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5A1F),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Return to Home',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            }
          ),
        ),
      ),
    );
  }
}

class PaymentFailedPage extends StatelessWidget {
  final String? userId;

  const PaymentFailedPage({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: FutureBuilder<String?>(
            future: _fetchUserName(userId),
            builder: (context, snapshot) {
              final name = snapshot.data;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 100),
                  const SizedBox(height: 32),
                  const Text(
                    'Payment Failed',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0B1437),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Unfortunately, your payment could not be processed at this time. Please try again.\n${name != null ? "User: $name" : (userId != null ? "User ID: $userId" : "")}',
                    style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5A1F),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Return to Home',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            }
          ),
        ),
      ),
    );
  }
}
