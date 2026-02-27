import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';
import '../models/chat_message.dart';

/// Central Dio client with Firebase auth interceptor.
class ApiService {
  late final Dio dio;
  static late ApiService instance;

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? queryParams}) async {
    final resp = await dio.get(path, queryParameters: queryParams);
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data) async {
    final resp = await dio.post(path, data: data);
    if (resp.data is Map) return Map<String, dynamic>.from(resp.data as Map);
    return {};
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? data}) async {
    final resp = await dio.put(path, data: data);
    if (resp.data is Map) return Map<String, dynamic>.from(resp.data as Map);
    return {};
  }

  /// Extract a human-readable error message from any exception.
  /// Pulls the FastAPI `detail` field from DioException responses.
  static String extractError(Object e, {String fallback = 'Something went wrong'}) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data.containsKey('detail')) {
        final detail = data['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          // Pydantic validation errors: [{msg: "...", loc: [...]}]
          return detail.map((d) => d['msg'] ?? d.toString()).join('; ');
        }
        return detail.toString();
      }
      if (e.response?.statusCode == 401) return 'Session expired. Please log in again.';
      if (e.response?.statusCode == 403) return 'You don\'t have permission for this action.';
      if (e.response?.statusCode == 404) return 'Not found.';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Server is taking too long. Please try again.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Could not connect to server. Check your internet.';
      }
    }
    final msg = e.toString().replaceFirst('Exception: ', '');
    return msg.length > 200 ? fallback : msg;
  }

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
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  // ─── Auth ───

  Future<Map<String, dynamic>> verifyToken(
      String idToken, String role,
      {String? displayName, String? termsAcceptedAt, String? birthday}) async {
    final data = <String, dynamic>{
      'id_token': idToken,
      'role': role,
    };
    if (displayName != null) data['display_name'] = displayName;
    if (termsAcceptedAt != null) data['terms_accepted_at'] = termsAcceptedAt;
    if (birthday != null) data['birthday'] = birthday;
    final resp = await dio.post('/auth/verify', data: data);
    return resp.data;
  }

  // ─── User Profile ───

  Future<Map<String, dynamic>> getMe() async {
    final resp = await dio.get('/me');
    return resp.data;
  }

  // ─── Payment Info ───

  Future<Map<String, dynamic>> getPaymentInfo() async {
    final resp = await dio.get('/me/payment-info');
    return resp.data;
  }

  Future<Map<String, dynamic>> updatePaymentInfo(Map<String, dynamic> data) async {
    final resp = await dio.put('/me/payment-info', data: data);
    return resp.data;
  }

  // ─── Bank Account (organizer) ───

  Future<Map<String, dynamic>> getBankAccount() async {
    final resp = await dio.get('/me/bank-account');
    return resp.data;
  }

  Future<Map<String, dynamic>> updateBankAccount(Map<String, dynamic> data) async {
    final resp = await dio.put('/me/bank-account', data: data);
    return resp.data;
  }

  // ─── Payment Status Polling ───

  Future<Map<String, dynamic>> getPaymentStatus(String transactionId) async {
    final resp = await dio.get('/payments/$transactionId/status');
    return resp.data;
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> data) async {
    final resp = await dio.patch('/me', data: data);
    return resp.data;
  }

  Future<List<dynamic>> getMyPledges({int offset = 0, int limit = 20}) async {
    final resp = await dio.get('/me/pledges', queryParameters: {'offset': offset, 'limit': limit});
    return resp.data;
  }

  Future<List<dynamic>> getMyTickets({int offset = 0, int limit = 20}) async {
    final resp = await dio.get('/me/tickets', queryParameters: {'offset': offset, 'limit': limit});
    return resp.data;
  }

  Future<List<dynamic>> getMyEvents({int offset = 0, int limit = 20}) async {
    final resp = await dio.get('/me/events', queryParameters: {
      'offset': offset,
      'limit': limit,
    });
    return resp.data;
  }

  Future<List<dynamic>> getCoOrganizedEvents({
    String? status,
    String? search,
    int offset = 0,
    int limit = 20,
  }) async {
    final resp = await dio.get('/me/co-organized-events', queryParameters: {
      if (status != null) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      'offset': offset,
      'limit': limit,
    });
    return resp.data;
  }

  Future<List<dynamic>> getOrganizerTicketSales({bool scannedOnly = false, String? eventStatus, String? genre, int? eventId, int offset = 0, int limit = 20}) async {
    final resp = await dio.get('/me/organizer-ticket-sales', queryParameters: {
      if (scannedOnly) 'scanned_only': true,
      if (eventStatus != null) 'event_status': eventStatus,
      if (genre != null) 'genre': genre,
      if (eventId != null) 'event_id': eventId,
      'offset': offset,
      'limit': limit,
    });
    return resp.data;
  }

  Future<List<dynamic>> getOrganizerPledges({String? status, String? eventStatus, String? genre, int? eventId, int offset = 0, int limit = 20}) async {
    final resp = await dio.get('/me/organizer-pledges', queryParameters: {
      if (status != null) 'status': status,
      if (eventStatus != null) 'event_status': eventStatus,
      if (genre != null) 'genre': genre,
      if (eventId != null) 'event_id': eventId,
      'offset': offset,
      'limit': limit,
    });
    return resp.data;
  }

  // ─── Events ───

  /// Returns { items: List, next_cursor: String? }. Prefer cursor over offset for infinite scroll.
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

  Future<Map<String, dynamic>> getFeaturedEvents({bool sponsorshipOnly = false}) async {
    final resp = await dio.get('/events/featured', queryParameters: {
      if (sponsorshipOnly) 'sponsorship_only': true,
    });
    return resp.data;
  }

  // ─── Map ───

  Future<List<dynamic>> getMapEvents({
    double? lat,
    double? lng,
    double? radiusKm,
    String? city,
    bool? live,
    int? organizerId,
    String? search,
    String? genre,
    String? status,
  }) async {
    final params = <String, dynamic>{};
    if (lat != null) params['lat'] = lat;
    if (lng != null) params['lng'] = lng;
    if (radiusKm != null) params['radius_km'] = radiusKm;
    if (city != null) params['city'] = city;
    if (live != null) params['live'] = live;
    if (organizerId != null) params['organizer_id'] = organizerId;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (genre != null) params['genre'] = genre;
    if (status != null) params['status'] = status;
    final resp = await dio.get('/events/map', queryParameters: params);
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

  Future<Map<String, dynamic>> uploadEventImage(int eventId, {required List<int> fileBytes, required String fileName, String? caption, int displayOrder = 0}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      if (caption != null) 'caption': caption,
      'display_order': displayOrder,
    });
    final resp = await dio.post('/events/$eventId/images/upload', data: formData);
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

  Future<Map<String, dynamic>> getPledgePreview(
      int eventId, int amountCents, int reservedSpots) async {
    final resp = await dio.get('/events/$eventId/pledge-preview', queryParameters: {
      'amount_cents': amountCents,
      'reserved_spots': reservedSpots,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> pledge(
      int eventId, int amountCents,
      {int reservedSpots = 0,
      List<Map<String, dynamic>>? tierReservations}) async {
    final body = <String, dynamic>{
      'amount_cents': amountCents,
      'reserved_spots': reservedSpots,
    };
    if (tierReservations != null) body['tier_reservations'] = tierReservations;
    final resp = await dio.post('/events/$eventId/pledge', data: body);
    return resp.data;
  }

  Future<Map<String, dynamic>> getPledgeReceipt(int eventId, int pledgeId) async {
    final resp = await dio.get('/events/$eventId/pledges/$pledgeId/receipt');
    return resp.data;
  }

  Future<Map<String, dynamic>> getMyPledgeReceipt(int pledgeId) async {
    final resp = await dio.get('/me/pledges/$pledgeId/receipt');
    return resp.data;
  }

  Future<Map<String, dynamic>> getCapacityInfo(int eventId) async {
    final resp = await dio.get('/events/$eventId/capacity-info');
    return resp.data;
  }

  Future<Map<String, dynamic>> unpledge(int eventId) async {
    final resp = await dio.post('/events/$eventId/unpledge');
    return resp.data;
  }

  Future<Map<String, dynamic>> getRefundStatus(int eventId) async {
    final resp = await dio.get('/events/$eventId/refund-status');
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

  Future<List<dynamic>> purchaseTickets(
      int eventId, {required int tierId, int quantity = 1, String? extraPerks}) async {
    final data = <String, dynamic>{
      'tier_id': tierId,
      'quantity': quantity,
    };
    if (extraPerks != null) data['extra_perks'] = extraPerks;
    final resp =
        await dio.post('/events/$eventId/purchase-ticket', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> requestTicketRefund(int eventId, int ticketId) async {
    final resp = await dio.post('/events/$eventId/tickets/$ticketId/refund');
    return resp.data;
  }

  Future<List<dynamic>> getRefundRequests(int eventId) async {
    final resp = await dio.get('/events/$eventId/refund-requests');
    return resp.data;
  }

  Future<Map<String, dynamic>> approveTicketRefund(int eventId, int ticketId) async {
    final resp = await dio.post('/events/$eventId/tickets/$ticketId/approve-refund');
    return resp.data;
  }

  Future<Map<String, dynamic>> rejectTicketRefund(int eventId, int ticketId) async {
    final resp = await dio.post('/events/$eventId/tickets/$ticketId/reject-refund');
    return resp.data;
  }

  Future<Map<String, dynamic>> getTicketReceipt(int eventId, int saleId) async {
    final resp = await dio.get('/events/$eventId/tickets/$saleId/receipt');
    return resp.data;
  }

  Future<Map<String, dynamic>> getPurchaseGroupReceipt(int eventId, String groupId) async {
    final resp = await dio.get('/events/$eventId/purchase-group/$groupId/receipt');
    return resp.data;
  }

  Future<Map<String, dynamic>> getTicketSalesStats(int eventId) async {
    final resp = await dio.get('/events/$eventId/ticket-sales-stats');
    return resp.data;
  }

  Future<Map<String, dynamic>> getMyTicketReceipt(int saleId) async {
    final resp = await dio.get('/me/tickets/$saleId/receipt');
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

  Future<Map<String, dynamic>> updateTicketTier(
      int eventId, int tierId, Map<String, dynamic> data) async {
    final resp =
        await dio.patch('/events/$eventId/ticket-tiers/$tierId', data: data);
    return resp.data;
  }

  Future<void> deleteTicketTier(int eventId, int tierId) async {
    await dio.delete('/events/$eventId/ticket-tiers/$tierId');
  }

  Future<List<dynamic>> getTicketSales(int eventId, {int offset = 0, int limit = 20}) async {
    final resp = await dio.get('/events/$eventId/ticket-sales', queryParameters: {'offset': offset, 'limit': limit});
    return resp.data;
  }

  Future<List<dynamic>> getScannedTickets(int eventId, {int offset = 0, int limit = 20}) async {
    final resp = await dio.get('/events/$eventId/scanned-tickets', queryParameters: {'offset': offset, 'limit': limit});
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

  Future<Map<String, dynamic>> updateOrganizerPermission(
      int eventId, int userId, String permission) async {
    final resp = await dio.patch('/events/$eventId/organizers/$userId',
        data: {'permission': permission});
    return resp.data;
  }

  Future<Map<String, dynamic>> respondToInvitation(
      int eventId, int userId, bool accept) async {
    final resp = await dio.post('/events/$eventId/organizers/$userId/respond',
        data: {'accept': accept});
    return resp.data;
  }

  Future<void> selfRemoveFromEvent(int eventId) async {
    await dio.delete('/events/$eventId/organizers/me');
  }

  Future<void> removeEventOrganizer(int eventId, int userId) async {
    await dio.delete('/events/$eventId/organizers/$userId');
  }

  Future<List<dynamic>> searchOrganizers(String query) async {
    final resp = await dio.get('/users/search-organizers', queryParameters: {'q': query});
    return resp.data is List ? resp.data : [];
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

  Future<List<dynamic>> getOrganizerCustomers({int offset = 0, int limit = 20}) async {
    final resp = await dio.get('/me/customers', queryParameters: {'offset': offset, 'limit': limit});
    return resp.data;
  }

  // ─── Organizer Dashboard ───

  Future<Map<String, dynamic>> getOrganizerDashboard({String? status, int? eventId, String? genre, String? period}) async {
    final resp = await dio.get('/me/organizer-dashboard', queryParameters: {
      if (status != null) 'status': status,
      if (eventId != null) 'event_id': eventId,
      if (genre != null) 'genre': genre,
      if (period != null) 'period': period,
    });
    return resp.data;
  }

  Future<List<String>> getEventCities() async {
    final resp = await dio.get('/events/cities');
    final data = resp.data;
    if (data is Map) return List<String>.from(data['cities'] ?? []);
    if (data is List) return List<String>.from(data);
    return [];
  }

  Future<Map<String, dynamic>> getOrganizerTimeSeries({int days = 30, String? status, int? eventId, String? genre}) async {
    final resp = await dio.get('/me/organizer-dashboard/time-series', queryParameters: {
      'days': days,
      if (status != null) 'status': status,
      if (eventId != null) 'event_id': eventId,
      if (genre != null) 'genre': genre,
    });
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

  Future<Map<String, dynamic>> adminGetUsers({int offset = 0, int limit = 20, String? search}) async {
    final resp = await dio.get('/admin/users', queryParameters: {
      'offset': offset, 'limit': limit, if (search != null && search.isNotEmpty) 'search': search,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminGetUserDetail(int userId) async {
    final resp = await dio.get('/admin/users/$userId/detail');
    return resp.data as Map<String, dynamic>;
  }

  Future<void> adminRefundSponsorBid(
      int eventId, int catId, int bidId) async {
    await dio.post(
        '/admin/events/$eventId/sponsorships/$catId/bids/$bidId/refund');
  }

  Future<Map<String, dynamic>> adminGetEvents({int offset = 0, int limit = 20, String? search, String? status}) async {
    final resp = await dio.get('/admin/events', queryParameters: {
      'offset': offset, 'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return resp.data as Map<String, dynamic>;
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

  Future<Map<String, dynamic>> adminGetDashboard({
    String period = '30d',
    String? genre,
    String? status,
  }) async {
    final resp = await dio.get('/admin/dashboard', queryParameters: {
      'period': period,
      if (genre != null) 'genre': genre,
      if (status != null) 'status': status,
    });
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> adminGetTickets({int offset = 0, int limit = 20, String? search, String? status}) async {
    final resp = await dio.get('/admin/tickets', queryParameters: {
      'offset': offset, 'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminGetPledges({int offset = 0, int limit = 20, String? search, String? status, bool? isDonation}) async {
    final resp = await dio.get('/admin/pledges', queryParameters: {
      'offset': offset, 'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
      if (isDonation != null) 'is_donation': isDonation,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<void> adminRefundPledge(int eventId, int fundingId) async {
    await dio.post('/admin/events/$eventId/pledges/$fundingId/refund');
  }

  // ─── Public Config ───

  Future<Map<String, dynamic>> getPublicConfig() async {
    final resp = await dio.get('/config');
    return Map<String, dynamic>.from(resp.data as Map);
  }

  // ─── Feature Flags ───

  Future<Map<String, bool>> getFeatureFlags() async {
    try {
      final resp = await dio.get('/admin/settings');
      final list = resp.data as List;
      return {
        for (var s in list.where((s) => (s['key'] as String).startsWith('feature_')))
          s['key'] as String: s['value'] == 'true',
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) return {};
      rethrow;
    }
  }

  // ─── Milestones ───

  Future<List<dynamic>> getMilestones(int eventId) async {
    final resp = await dio.get('/events/$eventId/milestones');
    return resp.data;
  }

  Future<Map<String, dynamic>> createMilestone(
      int eventId, Map<String, dynamic> data) async {
    final resp = await dio.post('/events/$eventId/milestones', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> updateMilestone(
      int eventId, int milestoneId, Map<String, dynamic> data) async {
    final resp =
        await dio.patch('/events/$eventId/milestones/$milestoneId', data: data);
    return resp.data;
  }

  Future<void> deleteMilestone(int eventId, int milestoneId) async {
    await dio.delete('/events/$eventId/milestones/$milestoneId');
  }

  Future<Map<String, dynamic>> reactToMilestone(
      int eventId, int milestoneId, String reaction) async {
    final resp = await dio.post(
      '/events/$eventId/milestones/$milestoneId/react',
      queryParameters: {'reaction': reaction},
    );
    return resp.data;
  }

  Future<Map<String, dynamic>> getMyMilestoneReaction(
      int eventId, int milestoneId) async {
    final resp =
        await dio.get('/events/$eventId/milestones/$milestoneId/my-reaction');
    return resp.data;
  }

  // ─── Milestone Snapshots ───

  Future<List<dynamic>> getMilestoneSnapshots(int eventId) async {
    final resp = await dio.get('/events/$eventId/milestone-snapshots');
    return resp.data;
  }

  // ─── Early Bird Discounts ───

  Future<List<dynamic>> getEarlyBirdDiscounts(int eventId) async {
    final resp = await dio.get('/events/$eventId/early-bird-discounts');
    return resp.data;
  }

  Future<Map<String, dynamic>> createEarlyBirdDiscount(
      int eventId, Map<String, dynamic> data) async {
    final resp =
        await dio.post('/events/$eventId/early-bird-discounts', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> updateEarlyBirdDiscount(
      int eventId, int discountId, Map<String, dynamic> data) async {
    final resp = await dio.patch(
        '/events/$eventId/early-bird-discounts/$discountId',
        data: data);
    return resp.data;
  }

  Future<void> deleteEarlyBirdDiscount(int eventId, int discountId) async {
    await dio.delete('/events/$eventId/early-bird-discounts/$discountId');
  }

  // ─── Schedule ───

  Future<List<dynamic>> getSchedule(int eventId) async {
    final resp = await dio.get('/events/$eventId/schedule');
    return resp.data;
  }

  Future<Map<String, dynamic>> createScheduleItem(
      int eventId, Map<String, dynamic> data) async {
    final resp = await dio.post('/events/$eventId/schedule', data: data);
    return resp.data;
  }

  Future<List<dynamic>> bulkCreateSchedule(
      int eventId, List<Map<String, dynamic>> items) async {
    final resp = await dio.post('/events/$eventId/schedule/bulk', data: items);
    return resp.data as List;
  }

  Future<Map<String, dynamic>> updateScheduleItem(
      int eventId, int itemId, Map<String, dynamic> data) async {
    final resp =
        await dio.patch('/events/$eventId/schedule/$itemId', data: data);
    return resp.data;
  }

  Future<void> deleteScheduleItem(int eventId, int itemId) async {
    await dio.delete('/events/$eventId/schedule/$itemId');
  }

  Future<Map<String, dynamic>> uploadScheduleImage(
      int eventId, int itemId, dynamic fileBytes, String fileName,
      {String? caption}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      if (caption != null) 'caption': caption,
    });
    final resp = await dio.post(
      '/events/$eventId/schedule/$itemId/upload-image',
      data: formData,
    );
    return resp.data;
  }

  Future<Map<String, dynamic>> deleteScheduleImage(int eventId, int itemId) async {
    final resp = await dio.delete('/events/$eventId/schedule/$itemId/image');
    return resp.data;
  }

  String getScheduleExportUrl(int eventId) {
    return '${dio.options.baseUrl}/events/$eventId/schedule/export';
  }

  // ── Sponsor Profile ──

  Future<Map<String, dynamic>> getSponsorProfile() async {
    final resp = await dio.get('/me/sponsor-profile');
    return resp.data;
  }

  Future<List<dynamic>> getSponsorBidEvents() async {
    final resp = await dio.get('/me/sponsor-bid-events');
    return resp.data;
  }

  Future<List<dynamic>> getSponsorshipAvailableEvents({bool excludeMyBids = false}) async {
    final resp = await dio.get('/events/sponsorship-available', queryParameters: {
      'exclude_my_bids': excludeMyBids,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> createSponsorProfile(
      Map<String, dynamic> data) async {
    final resp = await dio.post('/me/sponsor-profile', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> updateSponsorProfile(
      Map<String, dynamic> data) async {
    final resp = await dio.patch('/me/sponsor-profile', data: data);
    return resp.data;
  }

  // ── Organizer: My Sponsors ──

  Future<List<dynamic>> getOrganizerSponsors({String? eventStatus, String? genre, int? eventId, int offset = 0, int limit = 20}) async {
    final resp = await dio.get('/me/organizer-sponsors', queryParameters: {
      if (eventStatus != null) 'event_status': eventStatus,
      if (genre != null) 'genre': genre,
      if (eventId != null) 'event_id': eventId,
      'offset': offset,
      'limit': limit,
    });
    return resp.data as List;
  }

  Future<List<dynamic>> getSponsorEventsForOrganizer(int sponsorUserId) async {
    final resp = await dio.get('/me/organizer-sponsors/$sponsorUserId/events');
    return resp.data as List;
  }

  // ── Sponsorship Categories ──

  Future<List<dynamic>> getSponsorshipCategories(int eventId) async {
    final resp = await dio.get('/events/$eventId/sponsorships');
    return resp.data as List;
  }

  Future<Map<String, dynamic>> createSponsorshipCategory(
      int eventId, Map<String, dynamic> data) async {
    final resp = await dio.post('/events/$eventId/sponsorships', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> updateSponsorshipCategory(
      int eventId, int catId, Map<String, dynamic> data) async {
    final resp =
        await dio.patch('/events/$eventId/sponsorships/$catId', data: data);
    return resp.data;
  }

  Future<void> deleteSponsorshipCategory(int eventId, int catId) async {
    await dio.delete('/events/$eventId/sponsorships/$catId');
  }

  // ── Sponsor Bids ──

  Future<Map<String, dynamic>> placeBid(
      int eventId, int catId, Map<String, dynamic> data) async {
    final resp = await dio.post(
        '/events/$eventId/sponsorships/$catId/bids',
        data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> updateBid(
      int eventId, int catId, int bidId, Map<String, dynamic> data) async {
    final resp = await dio.patch(
        '/events/$eventId/sponsorships/$catId/bids/$bidId',
        data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> withdrawBid(
      int eventId, int catId, int bidId) async {
    final resp = await dio.post(
        '/events/$eventId/sponsorships/$catId/bids/$bidId/withdraw');
    return resp.data;
  }

  Future<List<dynamic>> listBids(int eventId, int catId) async {
    final resp =
        await dio.get('/events/$eventId/sponsorships/$catId/bids');
    return resp.data as List;
  }

  Future<Map<String, dynamic>> acceptBid(
      int eventId, int catId, int bidId) async {
    final resp = await dio.post(
        '/events/$eventId/sponsorships/$catId/bids/$bidId/accept');
    return resp.data;
  }

  Future<Map<String, dynamic>> rejectBid(
      int eventId, int catId, int bidId) async {
    final resp = await dio.post(
        '/events/$eventId/sponsorships/$catId/bids/$bidId/reject');
    return resp.data;
  }

  // ── Sponsor Payments ──

  Future<Map<String, dynamic>> payBid(
      int eventId, int catId, int bidId) async {
    final resp = await dio.post(
        '/events/$eventId/sponsorships/$catId/bids/$bidId/pay');
    return resp.data;
  }

  // ── Sponsor Tickets ──

  Future<List<dynamic>> getMySponsorTickets() async {
    final resp = await dio.get('/me/sponsor-tickets');
    return resp.data as List;
  }

  Future<Map<String, dynamic>> getSponsorPaymentReceipt(int paymentId) async {
    final resp = await dio.get('/payments/$paymentId/receipt');
    return resp.data;
  }

  Future<Map<String, dynamic>> scanSponsorTicket(
      int eventId, String encryptedPayload) async {
    final resp = await dio.post('/events/$eventId/scan-sponsor', data: {
      'encrypted_payload': encryptedPayload,
    });
    return resp.data;
  }

  // ── Sponsor Delegates ──

  Future<List<dynamic>> listDelegates(int ticketId) async {
    final resp = await dio.get('/me/sponsor-tickets/$ticketId/delegates');
    return resp.data as List;
  }

  Future<Map<String, dynamic>> addDelegate(
      int ticketId, String name, {String? email, String? phone}) async {
    final resp = await dio.post('/me/sponsor-tickets/$ticketId/delegates', data: {
      'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
    });
    return resp.data;
  }

  Future<void> removeDelegate(int ticketId, int delegateId) async {
    await dio.delete('/me/sponsor-tickets/$ticketId/delegates/$delegateId');
  }

  Future<Map<String, dynamic>> checkInDelegate(
      int eventId, int delegateId) async {
    final resp = await dio
        .post('/events/$eventId/sponsor-delegates/$delegateId/check-in');
    return resp.data;
  }

  Future<List<dynamic>> getScannedSponsorTickets(int eventId) async {
    final resp = await dio.get('/events/$eventId/scanned-sponsor-tickets');
    return resp.data as List;
  }

  // ── Public Sponsors ──

  Future<List<dynamic>> getEventSponsors(int eventId) async {
    final resp = await dio.get('/events/$eventId/sponsors');
    return resp.data as List;
  }

  // ── Bookmarks ──

  Future<Map<String, dynamic>> toggleBookmark(int eventId) async {
    final resp = await dio.post('/me/bookmarks/$eventId');
    return resp.data;
  }

  Future<Map<String, dynamic>> checkBookmarks(List<int> eventIds) async {
    final ids = eventIds.join(',');
    final resp = await dio.get('/me/bookmarks/check', queryParameters: {'event_ids': ids});
    return resp.data;
  }

  Future<List<dynamic>> getBookmarkedEvents({String? search, String? status, int offset = 0, int limit = 20}) async {
    final params = <String, dynamic>{'offset': offset, 'limit': limit};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final resp = await dio.get('/me/bookmarks', queryParameters: params);
    return resp.data as List;
  }

  // ── Prerequisites ──

  Future<Map<String, dynamic>> createPrerequisite(
      int eventId, int catId, {required String name, String? description, bool isRequired = true, bool requiresDocument = false}) async {
    final formData = FormData.fromMap({
      'name': name,
      if (description != null) 'description': description,
      'is_required': isRequired,
      'requires_document': requiresDocument,
    });
    final resp = await dio.post(
        '/events/$eventId/sponsorships/$catId/prerequisites',
        data: formData);
    return resp.data;
  }

  Future<List<dynamic>> listPrerequisites(int eventId, int catId) async {
    final resp = await dio.get('/events/$eventId/sponsorships/$catId/prerequisites');
    return resp.data as List;
  }

  Future<void> deletePrerequisite(int eventId, int catId, int prereqId) async {
    await dio.delete('/events/$eventId/sponsorships/$catId/prerequisites/$prereqId');
  }

  Future<Map<String, dynamic>> uploadPrerequisiteDocument(
      int bidId, int prereqId, String filePath, String fileName) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final resp = await dio.post(
        '/bids/$bidId/prerequisites/$prereqId/upload',
        data: formData);
    return resp.data;
  }

  Future<List<dynamic>> listBidPrerequisiteUploads(int bidId) async {
    final resp = await dio.get('/bids/$bidId/prerequisites');
    return resp.data as List;
  }

  Future<Map<String, dynamic>> uploadCategoryPrerequisite(
      int eventId, int catId, int prereqId,
      {String? filePath, String? fileName, List<int>? fileBytes}) async {
    late final MultipartFile multipart;
    if (fileBytes != null) {
      multipart = MultipartFile.fromBytes(fileBytes, filename: fileName ?? 'document');
    } else if (filePath != null) {
      multipart = await MultipartFile.fromFile(filePath, filename: fileName);
    } else {
      throw ArgumentError('Either filePath or fileBytes must be provided');
    }
    final formData = FormData.fromMap({'file': multipart});
    final resp = await dio.post(
        '/events/$eventId/sponsorships/$catId/upload-prerequisite/$prereqId',
        data: formData);
    return resp.data;
  }

  Future<Map<String, dynamic>> reviewPrerequisiteUpload(
      int bidId, int prereqId, {required String status, String? reviewerNote}) async {
    final formData = FormData.fromMap({
      'status': status,
      if (reviewerNote != null) 'reviewer_note': reviewerNote,
    });
    final resp = await dio.patch(
        '/bids/$bidId/prerequisites/$prereqId/review',
        data: formData);
    return resp.data;
  }

  // ── Ratings ──

  Future<Map<String, dynamic>> createRating(int eventId, {
    required String direction,
    int? ratedUserId,
    required int stars,
    String? description,
  }) async {
    final resp = await dio.post('/events/$eventId/ratings', data: {
      'direction': direction,
      if (ratedUserId != null) 'rated_user_id': ratedUserId,
      'stars': stars,
      if (description != null && description.isNotEmpty) 'description': description,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> getEventRatingsSummary(int eventId) async {
    final resp = await dio.get('/events/$eventId/ratings/summary');
    return resp.data;
  }

  Future<List<dynamic>> getEventRatings(int eventId, {String? direction}) async {
    final params = <String, dynamic>{};
    if (direction != null) params['direction'] = direction;
    final resp = await dio.get('/events/$eventId/ratings', queryParameters: params);
    return resp.data as List;
  }

  Future<Map<String, dynamic>> getUserRatingsSummary(int userId) async {
    final resp = await dio.get('/users/$userId/ratings-received');
    return resp.data;
  }

  // ── Public Profiles ──

  Future<Map<String, dynamic>> getPublicProfile(int userId) async {
    final resp = await dio.get('/users/$userId/public-profile');
    return resp.data;
  }

  Future<Map<String, dynamic>> getSponsorPublicProfile(int userId) async {
    final resp = await dio.get('/users/$userId/sponsor-public-profile');
    return resp.data;
  }

  Future<List<dynamic>> getPublicEvents(int userId, {int offset = 0, int limit = 20, String? search, String? status}) async {
    final params = <String, dynamic>{'offset': offset, 'limit': limit};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final resp = await dio.get('/users/$userId/public-events', queryParameters: params);
    return resp.data as List;
  }

  Future<Map<String, dynamic>> refundBid(int eventId, int catId, int bidId) async {
    final resp = await dio.post('/events/$eventId/sponsorships/$catId/bids/$bidId/refund');
    return resp.data;
  }

  // ── Sponsor Category Templates ──

  Future<List<dynamic>> getSponsorCategoryTemplates() async {
    final resp = await dio.get('/me/sponsor-category-templates');
    return resp.data as List;
  }

  Future<Map<String, dynamic>> createSponsorCategoryTemplate(Map<String, dynamic> data) async {
    final resp = await dio.post('/me/sponsor-category-templates', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> updateSponsorCategoryTemplate(int id, Map<String, dynamic> data) async {
    final resp = await dio.patch('/me/sponsor-category-templates/$id', data: data);
    return resp.data;
  }

  Future<void> deleteSponsorCategoryTemplate(int id) async {
    await dio.delete('/me/sponsor-category-templates/$id');
  }

  Future<Map<String, dynamic>> copyTemplateToEvent(int eventId, int templateId) async {
    final resp = await dio.post('/events/$eventId/sponsorships/from-template/$templateId');
    return resp.data;
  }

  Future<List<dynamic>> listTemplatePrerequisites(int templateId) async {
    final resp = await dio.get('/me/sponsor-category-templates/$templateId/prerequisites');
    return resp.data as List;
  }

  Future<Map<String, dynamic>> createTemplatePrerequisite(
      int templateId, {required String name, String? description, bool isRequired = true, bool requiresDocument = false}) async {
    final formData = FormData.fromMap({
      'name': name,
      if (description != null) 'description': description,
      'is_required': isRequired,
      'requires_document': requiresDocument,
    });
    final resp = await dio.post(
        '/me/sponsor-category-templates/$templateId/prerequisites',
        data: formData);
    return resp.data;
  }

  Future<void> deleteTemplatePrerequisite(int templateId, int prereqId) async {
    await dio.delete('/me/sponsor-category-templates/$templateId/prerequisites/$prereqId');
  }

  // ─── Admin Banking ───

  Future<Map<String, dynamic>> adminGetBankingOverview({String period = '30d'}) async {
    final resp = await dio.get('/admin/banking-overview', queryParameters: {'period': period});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminGetEscrows({String type = 'fund', int limit = 50}) async {
    final path = type == 'fund' ? '/admin/escrows'
        : type == 'ticket' ? '/admin/ticket-escrows'
        : '/admin/sponsor-escrows';
    final resp = await dio.get(path, queryParameters: {'limit': '$limit'});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminGetEventEscrows(int eventId) async {
    final resp = await dio.get('/admin/escrows/by-event/$eventId');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminReleaseEscrowStage(int eventId, String escrowType, int stage) async {
    final path = escrowType == 'fund' ? '/admin/escrows/$eventId/release/$stage'
        : escrowType == 'ticket' ? '/admin/ticket-escrows/$eventId/release/$stage'
        : '/admin/sponsor-escrows/$eventId/release/$stage';
    final resp = await dio.post(path, data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminFreezeEscrow(int eventId, String escrowType) async {
    final path = escrowType == 'fund' ? '/admin/escrows/$eventId/freeze'
        : escrowType == 'ticket' ? '/admin/ticket-escrows/$eventId/freeze'
        : '/admin/sponsor-escrows/$eventId/freeze';
    final resp = await dio.post(path, data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminUnfreezeEscrow(int eventId, String escrowType) async {
    final path = escrowType == 'fund' ? '/admin/escrows/$eventId/unfreeze'
        : escrowType == 'ticket' ? '/admin/ticket-escrows/$eventId/unfreeze'
        : '/admin/sponsor-escrows/$eventId/unfreeze';
    final resp = await dio.post(path, data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminToggleAutoRelease(
    int eventId, String escrowType, {
    bool? stage1, bool? stage2, bool? stage3,
  }) async {
    final path = '/admin/$escrowType-escrows/$eventId/auto-release';
    final body = <String, dynamic>{};
    if (stage1 != null) body['stage1_auto_release'] = stage1;
    if (stage2 != null) body['stage2_auto_release'] = stage2;
    if (stage3 != null) body['stage3_auto_release'] = stage3;
    final resp = await dio.patch(path, data: body);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminGetDisputes({String? status, int offset = 0, int limit = 50}) async {
    final resp = await dio.get('/admin/disputes', queryParameters: {
      if (status != null) 'status': status,
      'offset': offset,
      'limit': limit,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminSubmitDisputeEvidence(int disputeId) async {
    final resp = await dio.post('/admin/disputes/$disputeId/submit-evidence', data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminAcceptDisputeLoss(int disputeId) async {
    final resp = await dio.post('/admin/disputes/$disputeId/accept', data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminResolveDispute(int disputeId, {required String outcome, String? notes}) async {
    final resp = await dio.post('/admin/disputes/$disputeId/resolve', data: {
      'outcome': outcome,
      if (notes != null) 'notes': notes,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> adminGetReconciliationHistory({int limit = 30}) async {
    final resp = await dio.get('/admin/reconciliation/history', queryParameters: {'limit': limit});
    return resp.data as List;
  }

  Future<Map<String, dynamic>> adminRunReconciliation() async {
    final resp = await dio.post('/admin/reconciliation/run', data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminGetLedgerHealth() async {
    final resp = await dio.get('/admin/ledger-health');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminGetPayoutStatus() async {
    final resp = await dio.get('/admin/payout-status');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminForcePayout(int organizerId) async {
    final resp = await dio.post('/admin/payouts/$organizerId/force', data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminGetTransactions({int offset = 0, int limit = 20, String? search, String? status}) async {
    final resp = await dio.get('/admin/transactions', queryParameters: {
      'offset': offset,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminSimulateDispute(String transactionId) async {
    final resp = await dio.post('/admin/mock/simulate-dispute', data: {'transaction_id': transactionId});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminClearMockData() async {
    final resp = await dio.post('/admin/mock/clear', data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminSettleAllPending() async {
    final resp = await dio.post('/admin/mock/settle-all', data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminGetPlatformAccount() async {
    final resp = await dio.get('/admin/platform-account');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminUpdatePlatformAccount(Map<String, dynamic> data) async {
    final resp = await dio.put('/admin/platform-account', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminGetAuditLog({int offset = 0, int limit = 50, String? action, String? targetType}) async {
    final resp = await dio.get('/admin/audit-log', queryParameters: {
      'offset': offset,
      'limit': limit,
      if (action != null) 'action': action,
      if (targetType != null) 'target_type': targetType,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminGetWorkerSummary() async {
    final resp = await dio.get('/admin/worker-summary');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminGetWorkerRuns({
    String? taskName,
    String? status,
    int offset = 0,
    int limit = 50,
  }) async {
    final resp = await dio.get('/admin/worker-runs', queryParameters: {
      if (taskName != null) 'task_name': taskName,
      if (status != null) 'status': status,
      'offset': offset,
      'limit': limit,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminSetPolicyOverrides(
    int eventId,
    Map<String, dynamic> overrides,
  ) async {
    final resp = await dio.patch('/admin/events/$eventId/policy-overrides', data: overrides);
    return resp.data as Map<String, dynamic>;
  }

  // ─── KYC (Know Your Customer) ───

  Future<Map<String, dynamic>> getKycStatus() async {
    final resp = await dio.get('/me/kyc-status');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadKycDocument(
    String filePath,
    String documentType,
  ) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'document_type': documentType,
    });
    final resp = await dio.post('/me/kyc-documents', data: formData);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteKycDocument(int documentId) async {
    final resp = await dio.delete('/me/kyc-documents/$documentId');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitKyc() async {
    final resp = await dio.post('/me/kyc-submit', data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> adminGetKycPending() async {
    final resp = await dio.get('/admin/kyc-pending');
    return resp.data as List<dynamic>;
  }

  Future<List<dynamic>> adminGetUserKycDocuments(int userId) async {
    final resp = await dio.get('/admin/users/$userId/kyc-documents');
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> adminVerifyKyc(
    int userId, {
    required bool approved,
    String? rejectionReason,
  }) async {
    final data = <String, dynamic>{'approved': approved};
    if (rejectionReason != null) data['rejection_reason'] = rejectionReason;
    final resp = await dio.post('/admin/users/$userId/kyc-verify', data: data);
    return resp.data as Map<String, dynamic>;
  }

  // ── Chat ──

  Future<List<ChatMessage>> getChatMessages(int bidId, {String? before, int limit = 50}) async {
    final params = <String, String>{'limit': '$limit'};
    if (before != null) params['before'] = before;
    final resp = await dio.get('/chat/bids/$bidId/messages', queryParameters: params);
    return (resp.data as List).map((j) => ChatMessage.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<ChatConversation>> getChatConversations() async {
    final resp = await dio.get('/chat/conversations');
    return (resp.data as List).map((j) => ChatConversation.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> markChatRead(int bidId, String messageId) async {
    await dio.post('/chat/bids/$bidId/read', queryParameters: {'message_id': messageId});
  }
}
