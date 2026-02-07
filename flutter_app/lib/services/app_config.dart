class AppConfig {
  // Configure at build/run time:
  // flutter run -d chrome --dart-define=API_BASE_URL=https://YOUR_BACKEND/api/
  // flutter build web --release --dart-define=API_BASE_URL=https://YOUR_BACKEND/api/
  // flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_BACKEND/api/
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/',
  );

  static Uri apiUri(String pathAndQuery) {
    final base = apiBaseUrl.endsWith('/') ? apiBaseUrl : '$apiBaseUrl/';
    final normalized = pathAndQuery.startsWith('/')
        ? pathAndQuery.substring(1)
        : pathAndQuery;
    return Uri.parse('$base$normalized');
  }
}
