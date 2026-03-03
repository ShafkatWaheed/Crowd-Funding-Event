import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_config.dart';

/// Create a Dio instance with Firebase auth interceptor (token attach + 401 retry).
Dio createAuthDio() {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.apiUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && error.requestOptions.extra['_retried'] != true) {
          try {
            final newToken = await user.getIdToken(true);
            final opts = error.requestOptions;
            opts.headers['Authorization'] = 'Bearer $newToken';
            opts.extra['_retried'] = true;
            final response = await dio.fetch(opts);
            return handler.resolve(response);
          } catch (_) {}
        }
      }
      handler.next(error);
    },
  ));

  return dio;
}
