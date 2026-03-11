import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SubscriptionHelper {
  /// Check if the response is a subscription error (403 with subscription_expired error)
  static bool isSubscriptionExpired(http.Response response) {
    if (response.statusCode == 403) {
      try {
        final data = jsonDecode(response.body);
        return data['error'] == 'subscription_expired' ||
            data['subscription_status'] == 'expired';
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  /// Show subscription expired dialog
  static void showSubscriptionExpiredDialog(BuildContext context, {String? customMessage}) {
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap button to dismiss
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 30,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Subscription Expired',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customMessage ??
                    'Your trial period has expired. To continue creating and editing content, please subscribe to our service.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'You can still view your data',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.red.shade600, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Creating and editing is disabled',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Contact your administrator to renew your subscription.',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Handle API response and show subscription dialog if expired
  /// Returns true if subscription error was handled, false otherwise
  static bool handleResponse(BuildContext context, http.Response response) {
    if (isSubscriptionExpired(response)) {
      String message = 'Your trial period has expired. Please subscribe to continue.';
      
      try {
        final data = jsonDecode(response.body);
        message = data['message'] ?? message;
      } catch (e) {
        // Use default message if parsing fails
      }
      
      showSubscriptionExpiredDialog(context, customMessage: message);
      return true;
    }
    return false;
  }

  /// Wrap an API call with subscription error handling
  /// Example usage:
  /// ```dart
  /// final success = await SubscriptionHelper.makeApiCall(
  ///   context,
  ///   () async {
  ///     final response = await http.post(...);
  ///     return response;
  ///   },
  ///   onSuccess: (response) {
  ///     // Handle success
  ///   },
  ///   onError: (error) {
  ///     // Handle other errors
  ///   },
  /// );
  /// ```
  static Future<bool> makeApiCall(
    BuildContext context,
    Future<http.Response> Function() apiCall, {
    Function(http.Response)? onSuccess,
    Function(String)? onError,
  }) async {
    try {
      final response = await apiCall();

      if (!context.mounted) return false;

      // Check for subscription error first
      if (handleResponse(context, response)) {
        return false;
      }

      // Check for success
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (onSuccess != null) {
          onSuccess(response);
        }
        return true;
      }

      // Handle other errors
      if (onError != null) {
        try {
          final data = jsonDecode(response.body);
          final errorMessage = data['message'] ?? data['error'] ?? data['detail'] ?? 'Request failed';
          onError(errorMessage);
        } catch (e) {
          onError('Request failed with status ${response.statusCode}');
        }
      }

      return false;
    } catch (e) {
      if (onError != null) {
        onError('Network error: ${e.toString()}');
      }
      return false;
    }
  }
}
