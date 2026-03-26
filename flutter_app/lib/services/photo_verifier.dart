import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'app_config.dart';

class PhotoVerificationResult {
  final bool accepted;
  final String message;
  final int? statusCode;
  final String? imageVerification;

  const PhotoVerificationResult({
    required this.accepted,
    required this.message,
    this.statusCode,
    this.imageVerification,
  });
}

class PhotoVerifier {
  static Future<PhotoVerificationResult> verify({
    required Uint8List bytes,
    String? filename,
    int? userId,
  }) async {
    try {
      final uri = AppConfig.apiUri('image-verification/');
      final request = http.MultipartRequest('POST', uri);

      if (userId != null) {
        request.headers['X-User-Id'] = userId.toString();
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: filename ?? 'profile_photo.jpg',
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      Map<String, dynamic>? payload;
      try {
        payload = jsonDecode(response.body) as Map<String, dynamic>?;
      } catch (_) {
        payload = null;
      }

      final verdict = payload?['image_verification']?.toString();
      final detail =
          payload?['detail']?.toString() ?? 'Unable to verify photo.';
      final accepted =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          verdict != 'REJECT';

      return PhotoVerificationResult(
        accepted: accepted,
        statusCode: response.statusCode,
        message: detail,
        imageVerification: verdict,
      );
    } catch (e) {
      return PhotoVerificationResult(
        accepted: false,
        message: 'Unable to verify photo: $e',
      );
    }
  }
}
