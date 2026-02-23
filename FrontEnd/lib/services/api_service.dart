import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';

/// Central Dio client with Firebase auth interceptor.
class ApiService {
  late final Dio dio;

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
      {String? displayName, String? termsAcceptedAt}) async {
    final data = <String, dynamic>{
      'id_token': idToken,
      'role': role,
    };
    if (displayName != null) {
      data['display_name'] = displayName;
    }
    if (termsAcceptedAt != null) {
      data['terms_accepted_at'] = termsAcceptedAt;
    }
    final resp = await dio.post('/auth/verify', data: data);
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

  Future<List<dynamic>> getOrganizerTicketSales({bool scannedOnly = false, String? eventStatus, int offset = 0, int limit = 20}) async {
    final resp = await dio.get('/me/organizer-ticket-sales', queryParameters: {
      if (scannedOnly) 'scanned_only': true,
      if (eventStatus != null) 'event_status': eventStatus,
      'offset': offset,
      'limit': limit,
    });
    return resp.data;
  }

  Future<List<dynamic>> getOrganizerPledges({String? status, String? eventStatus, int offset = 0, int limit = 20}) async {
    final resp = await dio.get('/me/organizer-pledges', queryParameters: {
      if (status != null) 'status': status,
      if (eventStatus != null) 'event_status': eventStatus,
      'offset': offset,
      'limit': limit,
    });
    return resp.data;
  }

  // ─── Events ───

  Future<List<dynamic>> getEvents({Map<String, dynamic>? params, int offset = 0, int limit = 20}) async {
    final merged = <String, dynamic>{
      ...?params,
      'offset': offset,
      'limit': limit,
    };
    final resp = await dio.get('/events', queryParameters: merged);
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

  Future<List<dynamic>> getOrganizerCustomers({int offset = 0, int limit = 20}) async {
    final resp = await dio.get('/me/customers', queryParameters: {'offset': offset, 'limit': limit});
    return resp.data;
  }

  // ─── Organizer Dashboard ───

  Future<Map<String, dynamic>> getOrganizerDashboard({String? status, int? eventId}) async {
    final resp = await dio.get('/me/organizer-dashboard', queryParameters: {
      if (status != null) 'status': status,
      if (eventId != null) 'event_id': eventId,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> getOrganizerTimeSeries({int days = 30, String? status, int? eventId}) async {
    final resp = await dio.get('/me/organizer-dashboard/time-series', queryParameters: {
      'days': days,
      if (status != null) 'status': status,
      if (eventId != null) 'event_id': eventId,
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

  // ─── Feature Flags ───

  Future<Map<String, bool>> getFeatureFlags() async {
    final resp = await dio.get('/admin/settings');
    final list = resp.data as List;
    return {
      for (var s in list.where((s) => (s['key'] as String).startsWith('feature_')))
        s['key'] as String: s['value'] == 'true',
    };
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

  Future<List<dynamic>> getOrganizerSponsors({String? eventStatus, int offset = 0, int limit = 20}) async {
    final resp = await dio.get('/me/organizer-sponsors', queryParameters: {
      if (eventStatus != null) 'event_status': eventStatus,
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
}
