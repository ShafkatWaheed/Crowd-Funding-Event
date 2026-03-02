import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';

/// Central Dio client with Firebase auth interceptor.
///
/// After the 3-layer refactor, only SyncService and Stripe payment screens
/// use this class directly. All other HTTP calls go through typed repositories.
class ApiService {
  late final Dio dio;
  static late ApiService instance;

  ApiService() {
    instance = this;
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.apiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    // Attach Firebase ID token to every request
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
  }

  // ─── SyncService helpers (offline cache — will migrate in Phase 10) ───

  Future<Map<String, dynamic>> getEvents({
    Map<String, dynamic>? params,
    int? offset,
    int limit = 20,
    String? cursor,
  }) async {
    final merged = <String, dynamic>{
      ...?params,
      'limit': limit,
    };
    if (cursor != null) {
      merged['cursor'] = cursor;
    } else if (offset != null && offset > 0) {
      merged['offset'] = offset;
    }
    final resp = await dio.get('/events', queryParameters: merged);
    final data = resp.data;
    if (data is List) {
      return {'items': data, 'next_cursor': null};
    }
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getMyTickets({int offset = 0, int limit = 20, String? sortBy}) async {
    final resp = await dio.get('/me/tickets', queryParameters: {
      'offset': offset, 'limit': limit,
      if (sortBy != null) 'sort_by': sortBy,
    });
    return resp.data;
  }

  Future<List<dynamic>> getTicketSales(int eventId, {int offset = 0, int limit = 20}) async {
    final resp = await dio.get('/events/$eventId/ticket-sales', queryParameters: {'offset': offset, 'limit': limit});
    return resp.data;
  }

  Future<Map<String, dynamic>> scanTicket(
      int eventId, {String? ticketCode, String? encryptedPayload}) async {
    final body = <String, dynamic>{};
    if (encryptedPayload != null && encryptedPayload.isNotEmpty) {
      body['encrypted_payload'] = encryptedPayload;
    } else if (ticketCode != null) {
      body['ticket_code'] = ticketCode;
    }
    final resp = await dio.post('/events/$eventId/scan-ticket', data: body);
    return resp.data;
  }

  Future<List<dynamic>> getSchedule(int eventId) async {
    final resp = await dio.get('/events/$eventId/schedule');
    return resp.data;
  }

  Future<List<dynamic>> getMySponsorTickets() async {
    final resp = await dio.get('/me/sponsor-tickets');
    return resp.data as List;
  }

  // ── Stripe ──

  /// Whether Stripe is the active payment gateway. Set by [initStripeConfig].
  bool get isStripeEnabled => _stripeEnabled;
  bool _stripeEnabled = false;

  /// Fetch Stripe config from backend and cache the enabled state.
  Future<Map<String, dynamic>> getStripeConfig() async {
    final resp = await dio.get('/stripe/config');
    final data = Map<String, dynamic>.from(resp.data as Map);
    _stripeEnabled = data['stripe_enabled'] == true;
    return data;
  }

  /// Initialize Stripe config (call once after login).
  Future<void> initStripeConfig() async {
    await getStripeConfig();
  }

  /// Create a Stripe PaymentIntent for the Payment Sheet.
  Future<Map<String, dynamic>> createPaymentIntent({
    required int amountCents,
    required String description,
    String? idempotencyKey,
  }) async {
    final resp = await dio.post('/payments/create-intent', data: {
      'amount_cents': amountCents,
      'description': description,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    });
    return Map<String, dynamic>.from(resp.data as Map);
  }
}
