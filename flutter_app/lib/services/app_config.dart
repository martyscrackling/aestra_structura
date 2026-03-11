import 'package:flutter/foundation.dart';

class AppConfig {
  // Configure at build/run time:
  // flutter run -d chrome --dart-define=API_BASE_URL=https://YOUR_BACKEND/api/
  // flutter build web --release --dart-define=API_BASE_URL=https://YOUR_BACKEND/api/
  // flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_BACKEND/api/
  static String get apiBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envUrl.isNotEmpty) {
      return _normalize(envUrl);
    }

    // Android emulators cannot reach host localhost via 127.0.0.1.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/';
    }

    return 'http://127.0.0.1:8000/api/';
  }

  static String _normalize(String url) {
    return url.endsWith('/') ? url : '$url/';
  }

  static Uri apiUri(String pathAndQuery) {
    final base = apiBaseUrl;
    final normalized = pathAndQuery.startsWith('/')
        ? pathAndQuery.substring(1)
        : pathAndQuery;
    return Uri.parse('$base$normalized');
  }
}
