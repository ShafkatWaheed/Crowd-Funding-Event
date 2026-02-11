import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API configuration from environment variables.
class ApiConfig {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
  static const String apiPrefix = '/api/v1';
  static String get apiUrl => '$baseUrl$apiPrefix';
}
