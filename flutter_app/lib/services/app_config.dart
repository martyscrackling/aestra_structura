import 'package:flutter/foundation.dart';

class AppConfig {
  static const _defaultProdApiBase =
      'https://structura-backend-4vxo.onrender.com/api/';

  // Configure at build/run time:
  // flutter run -d chrome --dart-define=API_BASE_URL=https://YOUR_BACKEND/api/
  // flutter build web --release --dart-define=API_BASE_URL=https://YOUR_BACKEND/api/
  // flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_BACKEND/api/
  static String get apiBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envUrl.isNotEmpty) {
      return _normalize(envUrl);
    }

    // Hosted web deployments should default to production API when no
    // dart-define is provided by the build platform.
    if (kIsWeb) {
      return _defaultProdApiBase;
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

  /// Same host as the API, but [MEDIA_URL] is never under `/api/`.
  static Uri get _serverOrigin {
    final base = Uri.parse(apiBaseUrl);
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
    );
  }

  /// Turn API-relative or bare storage paths into a full URL for [Image.network].
  static String? resolveMediaUrl(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();
    if (value.isEmpty || value == 'null') return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final origin = _serverOrigin;
    if (value.startsWith('/')) {
      return origin.resolve(value).toString();
    }
    if (value.startsWith('media/')) {
      return origin.resolve('/$value').toString();
    }
    if (value.startsWith('project_images/') ||
        value.startsWith('fieldworker_images/') ||
        value.startsWith('client_images/') ||
        value.startsWith('inventory_images/')) {
      return origin.resolve('/media/$value').toString();
    }
    return origin.resolve('/media/$value').toString();
  }
}
