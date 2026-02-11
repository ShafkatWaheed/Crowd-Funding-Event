import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';

/// Central Dio client with Firebase auth interceptor.
class ApiService {
  late final Dio dio;

  ApiService() {
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
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  // ─── Auth ───

  Future<Map<String, dynamic>> verifyToken(
      String idToken, String role) async {
    final resp = await dio.post('/auth/verify', data: {
      'id_token': idToken,
      'role': role,
    });
    return resp.data;
  }

  // ─── User Profile ───

  Future<Map<String, dynamic>> getMe() async {
    final resp = await dio.get('/me');
    return resp.data;
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> data) async {
    final resp = await dio.patch('/me', data: data);
    return resp.data;
  }

  Future<List<dynamic>> getMyPledges() async {
    final resp = await dio.get('/me/pledges');
    return resp.data;
  }

  Future<List<dynamic>> getMyTickets() async {
    final resp = await dio.get('/me/tickets');
    return resp.data;
  }

  // ─── Events ───

  Future<List<dynamic>> getEvents({Map<String, dynamic>? params}) async {
    final resp = await dio.get('/events', queryParameters: params);
    return resp.data;
  }

  Future<Map<String, dynamic>> getEvent(int id) async {
    final resp = await dio.get('/events/$id');
    return resp.data;
  }

  Future<Map<String, dynamic>> createEvent(
      Map<String, dynamic> data) async {
    final resp = await dio.post('/events', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> updateEvent(
      int id, Map<String, dynamic> data) async {
    final resp = await dio.patch('/events/$id', data: data);
    return resp.data;
  }

  Future<void> deleteEvent(int id) async {
    await dio.delete('/events/$id');
  }

  Future<Map<String, dynamic>> submitEvent(int id) async {
    final resp = await dio.post('/events/$id/submit');
    return resp.data;
  }

  Future<Map<String, dynamic>> cancelEvent(int id) async {
    final resp = await dio.post('/events/$id/cancel');
    return resp.data;
  }

  // ─── Funding ───

  Future<Map<String, dynamic>> getFundingSummary(int eventId) async {
    final resp = await dio.get('/events/$eventId/funding');
    return resp.data;
  }

  Future<Map<String, dynamic>> pledge(
      int eventId, int amountCents) async {
    final resp = await dio.post('/events/$eventId/pledge', data: {
      'amount_cents': amountCents,
    });
    return resp.data;
  }

  // ─── Registration ───

  Future<Map<String, dynamic>> register(int eventId) async {
    final resp = await dio.post('/events/$eventId/register');
    return resp.data;
  }

  Future<Map<String, dynamic>> unregister(int eventId) async {
    final resp = await dio.post('/events/$eventId/unregister');
    return resp.data;
  }

  Future<List<dynamic>> getRegistrations(int eventId) async {
    final resp = await dio.get('/events/$eventId/registrations');
    return resp.data;
  }

  // ─── Tickets ───

  Future<List<dynamic>> getTicketTiers(int eventId) async {
    final resp = await dio.get('/events/$eventId/ticket-tiers');
    return resp.data;
  }

  Future<Map<String, dynamic>> createTicketTier(
      int eventId, Map<String, dynamic> data) async {
    final resp =
        await dio.post('/events/$eventId/ticket-tiers', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> getTicketPrice(
      int eventId, int ticketTierId) async {
    final resp = await dio.get('/events/$eventId/ticket-price',
        queryParameters: {'ticket_tier_id': ticketTierId});
    return resp.data;
  }

  Future<Map<String, dynamic>> purchaseTicket(
      int eventId, Map<String, dynamic> data) async {
    final resp =
        await dio.post('/events/$eventId/purchase-ticket', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> scanTicket(
      int eventId, String ticketCode) async {
    final resp = await dio.post('/events/$eventId/scan-ticket', data: {
      'ticket_code': ticketCode,
    });
    return resp.data;
  }

  // ─── Venues ───

  Future<List<dynamic>> getVenues() async {
    final resp = await dio.get('/venues');
    return resp.data;
  }

  Future<Map<String, dynamic>> getVenue(int id) async {
    final resp = await dio.get('/venues/$id');
    return resp.data;
  }

  Future<Map<String, dynamic>> createVenue(
      Map<String, dynamic> data) async {
    final resp = await dio.post('/venues', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> updateVenue(
      int id, Map<String, dynamic> data) async {
    final resp = await dio.patch('/venues/$id', data: data);
    return resp.data;
  }

  Future<void> deleteVenue(int id) async {
    await dio.delete('/venues/$id');
  }

  // ─── Admin ───

  Future<List<dynamic>> adminGetUsers() async {
    final resp = await dio.get('/admin/users');
    return resp.data;
  }

  Future<List<dynamic>> adminGetEvents(
      {Map<String, dynamic>? params}) async {
    final resp = await dio.get('/admin/events', queryParameters: params);
    return resp.data;
  }

  Future<Map<String, dynamic>> adminApproveEvent(
      int id, Map<String, dynamic> data) async {
    final resp =
        await dio.post('/admin/events/$id/approve', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> adminGetStats() async {
    final resp = await dio.get('/admin/stats');
    return resp.data;
  }
}
