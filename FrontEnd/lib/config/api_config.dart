import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API configuration from environment variables.
class ApiConfig {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
  static const String apiPrefix = '/api/v1';
  static String get apiUrl => '$baseUrl$apiPrefix';

  /// Resolve an image URL that may be a relative path from the backend.
  /// e.g. `/static/uploads/img.jpg` -> `http://localhost:8000/static/uploads/img.jpg`
  static String imageUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$baseUrl$url';
  }
}
