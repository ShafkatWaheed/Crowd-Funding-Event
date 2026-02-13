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

  Future<List<dynamic>> getMyEvents() async {
    final resp = await dio.get('/me/events');
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

  Future<Map<String, dynamic>> publishEvent(int id) async {
    final resp = await dio.post('/events/$id/publish');
    return resp.data;
  }

  Future<Map<String, dynamic>> cancelEvent(int id, {required String reason}) async {
    final resp = await dio.post('/events/$id/cancel', data: {'reason': reason});
    return resp.data;
  }

  Future<Map<String, dynamic>> reactivateEvent(int id) async {
    final resp = await dio.post('/events/$id/reactivate');
    return resp.data;
  }

  // ─── Featured / Discover ───

  Future<Map<String, dynamic>> getFeaturedEvents() async {
    final resp = await dio.get('/events/featured');
    return resp.data;
  }

  Future<List<dynamic>> getGenres() async {
    final resp = await dio.get('/events/genres');
    return resp.data;
  }

  // ─── Event Posts (Feed) ───

  Future<List<dynamic>> getEventPosts(int eventId) async {
    final resp = await dio.get('/events/$eventId/posts');
    return resp.data;
  }

  Future<Map<String, dynamic>> createEventPost(int eventId, String content) async {
    final resp = await dio.post('/events/$eventId/posts', data: {'content': content});
    return resp.data;
  }

  Future<void> deleteEventPost(int eventId, int postId) async {
    await dio.delete('/events/$eventId/posts/$postId');
  }

  Future<Map<String, dynamic>> toggleEventPosts(int eventId) async {
    final resp = await dio.post('/events/$eventId/toggle-posts');
    return resp.data;
  }

  // ─── Event Images ───

  Future<List<dynamic>> getEventImages(int eventId) async {
    final resp = await dio.get('/events/$eventId/images');
    return resp.data;
  }

  Future<Map<String, dynamic>> addEventImage(int eventId, {required String imageUrl, String? caption, int displayOrder = 0}) async {
    final resp = await dio.post('/events/$eventId/images', queryParameters: {
      'image_url': imageUrl,
      if (caption != null) 'caption': caption,
      'display_order': displayOrder,
    });
    return resp.data;
  }

  Future<void> deleteEventImage(int eventId, int imageId) async {
    await dio.delete('/events/$eventId/images/$imageId');
  }

  // ─── Like / Dislike ───

  Future<Map<String, dynamic>> reactToEvent(int eventId, String reaction) async {
    final resp = await dio.post('/events/$eventId/react', queryParameters: {'reaction': reaction});
    return resp.data;
  }

  Future<Map<String, dynamic>> getMyReaction(int eventId) async {
    final resp = await dio.get('/events/$eventId/my-reaction');
    return resp.data;
  }

  // ─── Clone ───

  Future<Map<String, dynamic>> cloneEvent(int eventId) async {
    final resp = await dio.post('/events/$eventId/clone');
    return resp.data;
  }

  // ─── Ticket Strategies ───

  Future<List<dynamic>> getTicketStrategies() async {
    final resp = await dio.get('/ticket-strategies');
    return resp.data;
  }

  Future<Map<String, dynamic>> createTicketStrategy(Map<String, dynamic> data) async {
    final resp = await dio.post('/ticket-strategies', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> getTicketStrategy(int id) async {
    final resp = await dio.get('/ticket-strategies/$id');
    return resp.data;
  }

  Future<void> deleteTicketStrategy(int id) async {
    await dio.delete('/ticket-strategies/$id');
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

  Future<Map<String, dynamic>> unpledge(int eventId) async {
    final resp = await dio.post('/events/$eventId/unpledge');
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

  Future<Map<String, dynamic>> getMyRegistration(int eventId) async {
    final resp = await dio.get('/events/$eventId/my-registration');
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

  Future<Map<String, dynamic>> updateTicketTier(
      int eventId, int tierId, Map<String, dynamic> data) async {
    final resp =
        await dio.patch('/events/$eventId/ticket-tiers/$tierId', data: data);
    return resp.data;
  }

  Future<void> deleteTicketTier(int eventId, int tierId) async {
    await dio.delete('/events/$eventId/ticket-tiers/$tierId');
  }

  Future<List<dynamic>> getTicketSales(int eventId) async {
    final resp = await dio.get('/events/$eventId/ticket-sales');
    return resp.data;
  }

  Future<List<dynamic>> getScannedTickets(int eventId) async {
    final resp = await dio.get('/events/$eventId/scanned-tickets');
    return resp.data;
  }

  Future<List<dynamic>> getWaitlistedTickets(int eventId) async {
    final resp = await dio.get('/events/$eventId/waitlisted-tickets');
    return resp.data;
  }

  Future<Map<String, dynamic>> approveWaitlistedTicket(int eventId, int ticketId) async {
    final resp = await dio.post('/events/$eventId/waitlisted-tickets/$ticketId/approve');
    return resp.data;
  }

  Future<Map<String, dynamic>> rejectWaitlistedTicket(int eventId, int ticketId) async {
    final resp = await dio.post('/events/$eventId/waitlisted-tickets/$ticketId/reject');
    return resp.data;
  }

  Future<Map<String, dynamic>> startSellingTickets(int eventId) async {
    final resp = await dio.post('/events/$eventId/start-selling');
    return resp.data;
  }

  Future<Map<String, dynamic>> decideRegistration(
      int eventId, int registrationId, String action) async {
    final resp = await dio.post(
      '/events/$eventId/registrations/$registrationId/decision',
      data: {'action': action},
    );
    return resp.data;
  }

  String calendarUrl(int eventId) =>
      '${dio.options.baseUrl}/events/$eventId/calendar.ics';

  // ─── Co-Organizers ───

  Future<List<dynamic>> getEventOrganizers(int eventId) async {
    final resp = await dio.get('/events/$eventId/organizers');
    return resp.data;
  }

  Future<Map<String, dynamic>> addEventOrganizer(
      int eventId, Map<String, dynamic> data) async {
    final resp = await dio.post('/events/$eventId/organizers', data: data);
    return resp.data;
  }

  Future<void> removeEventOrganizer(int eventId, int userId) async {
    await dio.delete('/events/$eventId/organizers/$userId');
  }

  // ─── Event Discounts ───

  Future<List<dynamic>> getEventDiscounts(int eventId) async {
    final resp = await dio.get('/events/$eventId/discounts/rules');
    return resp.data;
  }

  Future<Map<String, dynamic>> createEventDiscount(
      int eventId, Map<String, dynamic> data) async {
    final resp =
        await dio.post('/events/$eventId/discounts/rules', data: data);
    return resp.data;
  }

  Future<void> deleteEventDiscount(int eventId, int discountId) async {
    await dio.delete('/events/$eventId/discounts/rules/$discountId');
  }

  Future<List<dynamic>> getMyDiscounts(int eventId) async {
    final resp = await dio.get('/events/$eventId/my-discounts');
    return resp.data;
  }

  // ─── Extension Approval ───

  Future<Map<String, dynamic>> extendFunding(
      int eventId, Map<String, dynamic> data) async {
    final resp =
        await dio.post('/events/$eventId/extend-funding', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> setEventDate(
      int eventId, Map<String, dynamic> data) async {
    final resp =
        await dio.post('/events/$eventId/set-event-date', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> decideExtension(
      int eventId, String action) async {
    final resp = await dio.post(
      '/events/$eventId/extension-decision',
      data: {'action': action},
    );
    return resp.data;
  }

  // ─── Customer History ───

  Future<List<dynamic>> getOrganizerCustomers() async {
    final resp = await dio.get('/me/customers');
    return resp.data;
  }

  // ─── Discount Strategies ───

  Future<List<dynamic>> getDiscountStrategies() async {
    final resp = await dio.get('/discount-strategies');
    return resp.data;
  }

  Future<Map<String, dynamic>> createDiscountStrategy(
      Map<String, dynamic> data) async {
    final resp = await dio.post('/discount-strategies', data: data);
    return resp.data;
  }

  Future<void> deleteDiscountStrategy(int id) async {
    await dio.delete('/discount-strategies/$id');
  }

  Future<void> attachDiscountStrategy(int eventId, int strategyId, {bool autoApply = true}) async {
    await dio.post('/events/$eventId/discount-strategies/$strategyId', data: {'auto_apply': autoApply});
  }

  Future<void> detachDiscountStrategy(int eventId, int strategyId) async {
    await dio.delete('/events/$eventId/discount-strategies/$strategyId');
  }

  Future<List<dynamic>> getEventDiscountStrategies(int eventId) async {
    final resp = await dio.get('/events/$eventId/discount-strategies');
    return resp.data;
  }

  // ─── Customer Discount Claims ───

  Future<List<dynamic>> getClaimableDiscounts(int eventId) async {
    final resp = await dio.get('/events/$eventId/claimable-discounts');
    return resp.data;
  }

  Future<void> claimDiscount(int eventId, int linkId) async {
    await dio.post('/events/$eventId/claim-discount/$linkId');
  }

  Future<void> unclaimDiscount(int eventId, int linkId) async {
    await dio.delete('/events/$eventId/claim-discount/$linkId');
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
