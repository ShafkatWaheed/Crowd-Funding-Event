import 'package:dio/dio.dart';

/// Generic paginated response wrapper.
class PaginatedResult<T> {
  final List<T> items;
  final bool hasMore;
  final int? total;

  PaginatedResult({required this.items, required this.hasMore, this.total});
}

/// Structured API error with human-readable message.
class ApiError implements Exception {
  final int statusCode;
  final String message;

  ApiError(this.statusCode, this.message);

  factory ApiError.fromDioException(DioException e) {
    final data = e.response?.data;
    String msg = 'Something went wrong';
    if (data is Map && data.containsKey('detail')) {
      final detail = data['detail'];
      if (detail is String) msg = detail;
      if (detail is List && detail.isNotEmpty) {
        msg = detail.map((d) => d['msg'] ?? d.toString()).join('; ');
      }
    } else if (e.response?.statusCode == 401) {
      msg = 'Session expired. Please log in again.';
    } else if (e.response?.statusCode == 403) {
      msg = "You don't have permission for this action.";
    } else if (e.response?.statusCode == 404) {
      msg = 'Not found.';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      msg = 'Server is taking too long. Please try again.';
    } else if (e.type == DioExceptionType.connectionError) {
      msg = 'Could not connect to server. Check your internet.';
    }
    return ApiError(e.response?.statusCode ?? 0, msg);
  }

  /// Extract a human-readable error message from any exception.
  static String extractMessage(Object e, {String fallback = 'Something went wrong'}) {
    if (e is DioException) return ApiError.fromDioException(e).message;
    if (e is ApiError) return e.message;
    final s = e.toString();
    return s.isNotEmpty ? s : fallback;
  }

  @override
  String toString() => message;
}

/// Base for all repositories — holds shared [Dio] instance.
abstract class BaseRepository {
  final Dio dio;
  BaseRepository(this.dio);
}
