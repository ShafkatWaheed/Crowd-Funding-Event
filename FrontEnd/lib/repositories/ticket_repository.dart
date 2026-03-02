import '../models/ticket.dart';
import 'base_repository.dart';

class TicketRepository extends BaseRepository {
  TicketRepository(super.dio);

  // ─── Ticket Strategies ───

  Future<List<dynamic>> getTicketStrategies() async {
    final r = await dio.get('/ticket-strategies');
    return r.data;
  }

  Future<Map<String, dynamic>> createTicketStrategy(
      Map<String, dynamic> data) async {
    final r = await dio.post('/ticket-strategies', data: data);
    return r.data;
  }

  Future<Map<String, dynamic>> getTicketStrategy(int id) async {
    final r = await dio.get('/ticket-strategies/$id');
    return r.data;
  }

  Future<void> deleteTicketStrategy(int id) async {
    await dio.delete('/ticket-strategies/$id');
  }

  // ─── Customer tickets ───

  Future<PaginatedResult<TicketSale>> getMyTickets({
    int offset = 0,
    int limit = 20,
    String? sortBy,
  }) async {
    final params = <String, dynamic>{'offset': offset, 'limit': limit};
    if (sortBy != null) params['sort_by'] = sortBy;
    final r = await dio.get('/me/tickets', queryParameters: params);
    final list = r.data as List;
    return PaginatedResult(
      items: list.map((j) => TicketSale.fromJson(Map<String, dynamic>.from(j))).toList(),
      hasMore: list.length >= limit,
    );
  }

  // ─── Ticket tiers ───

  Future<List<TicketTier>> getTicketTiers(int eventId) async {
    final r = await dio.get('/events/$eventId/ticket-tiers');
    return (r.data as List)
        .map((j) => TicketTier.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  Future<Map<String, dynamic>> createTicketTier(
      int eventId, Map<String, dynamic> data) async {
    final r = await dio.post('/events/$eventId/ticket-tiers', data: data);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> updateTicketTier(
      int eventId, int tierId, Map<String, dynamic> data) async {
    final r = await dio.patch('/events/$eventId/ticket-tiers/$tierId', data: data);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> deleteTicketTier(int eventId, int tierId) async {
    await dio.delete('/events/$eventId/ticket-tiers/$tierId');
  }

  // ─── Ticket pricing ───

  Future<Map<String, dynamic>> getTicketPrice(int eventId, int ticketTierId) async {
    final r = await dio.get('/events/$eventId/ticket-price',
        queryParameters: {'ticket_tier_id': ticketTierId});
    return Map<String, dynamic>.from(r.data as Map);
  }

  // ─── Ticket purchase ───

  Future<List<TicketSale>> purchaseTickets(
      int eventId, {required int tierId, int quantity = 1, String? extraPerks}) async {
    final data = <String, dynamic>{
      'tier_id': tierId,
      'quantity': quantity,
    };
    if (extraPerks != null) data['extra_perks'] = extraPerks;
    final r = await dio.post('/events/$eventId/purchase-ticket', data: data);
    return (r.data as List)
        .map((j) => TicketSale.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  // ─── Ticket receipts ───

  Future<Map<String, dynamic>> getTicketReceipt(int eventId, int saleId) async {
    final r = await dio.get('/events/$eventId/tickets/$saleId/receipt');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> getMyTicketReceipt(int saleId) async {
    final r = await dio.get('/me/tickets/$saleId/receipt');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> getPurchaseGroupReceipt(int eventId, String groupId) async {
    final r = await dio.get('/events/$eventId/purchase-group/$groupId/receipt');
    return Map<String, dynamic>.from(r.data as Map);
  }

  // ─── Ticket sales stats ───

  Future<Map<String, dynamic>> getTicketSalesStats(int eventId) async {
    final r = await dio.get('/events/$eventId/ticket-sales-stats');
    return Map<String, dynamic>.from(r.data as Map);
  }

  // ─── Ticket scanning ───

  Future<Map<String, dynamic>> scanTicket(
      int eventId, {String? ticketCode, String? encryptedPayload}) async {
    final body = <String, dynamic>{};
    if (encryptedPayload != null && encryptedPayload.isNotEmpty) {
      body['encrypted_payload'] = encryptedPayload;
    } else if (ticketCode != null) {
      body['ticket_code'] = ticketCode;
    }
    final r = await dio.post('/events/$eventId/scan-ticket', data: body);
    return Map<String, dynamic>.from(r.data as Map);
  }

  // ─── Ticket sales lists (organizer/event) ───

  Future<List<TicketSale>> getTicketSales(int eventId, {int offset = 0, int limit = 20}) async {
    final r = await dio.get('/events/$eventId/ticket-sales',
        queryParameters: {'offset': offset, 'limit': limit});
    return (r.data as List)
        .map((j) => TicketSale.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  Future<List<TicketSale>> getScannedTickets(int eventId, {int offset = 0, int limit = 20}) async {
    final r = await dio.get('/events/$eventId/scanned-tickets',
        queryParameters: {'offset': offset, 'limit': limit});
    return (r.data as List)
        .map((j) => TicketSale.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  // ─── Organizer cross-event sales ───

  Future<List<TicketSale>> getOrganizerTicketSales({
    bool scannedOnly = false,
    String? eventStatus,
    String? genre,
    int? eventId,
    int offset = 0,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'offset': offset, 'limit': limit};
    if (scannedOnly) params['scanned_only'] = true;
    if (eventStatus != null) params['event_status'] = eventStatus;
    if (genre != null) params['genre'] = genre;
    if (eventId != null) params['event_id'] = eventId;
    final r = await dio.get('/me/organizer-ticket-sales', queryParameters: params);
    return (r.data as List)
        .map((j) => TicketSale.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  // ─── Refunds ───

  Future<Map<String, dynamic>> requestTicketRefund(int eventId, int ticketId) async {
    final r = await dio.post('/events/$eventId/tickets/$ticketId/refund');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<TicketSale>> getRefundRequests(int eventId) async {
    final r = await dio.get('/events/$eventId/refund-requests');
    return (r.data as List)
        .map((j) => TicketSale.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  Future<List<TicketSale>> getOrganizerRefundRequests({
    int? eventId,
    int offset = 0,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{'offset': offset, 'limit': limit};
    if (eventId != null) params['event_id'] = eventId;
    final r = await dio.get('/me/organizer-refund-requests', queryParameters: params);
    return (r.data as List)
        .map((j) => TicketSale.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  Future<Map<String, dynamic>> approveTicketRefund(int eventId, int ticketId) async {
    final r = await dio.post('/events/$eventId/tickets/$ticketId/approve-refund');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> rejectTicketRefund(int eventId, int ticketId) async {
    final r = await dio.post('/events/$eventId/tickets/$ticketId/reject-refund');
    return Map<String, dynamic>.from(r.data as Map);
  }

  // ─── Waitlist ───

  Future<List<TicketSale>> getWaitlistedTickets(int eventId) async {
    final r = await dio.get('/events/$eventId/waitlisted-tickets');
    return (r.data as List)
        .map((j) => TicketSale.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  Future<Map<String, dynamic>> approveWaitlistedTicket(int eventId, int ticketId) async {
    final r = await dio.post('/events/$eventId/waitlisted-tickets/$ticketId/approve');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> rejectWaitlistedTicket(int eventId, int ticketId) async {
    final r = await dio.post('/events/$eventId/waitlisted-tickets/$ticketId/reject');
    return Map<String, dynamic>.from(r.data as Map);
  }

  // ─── Event discounts ───

  Future<List<dynamic>> getEventDiscounts(int eventId) async {
    final r = await dio.get('/events/$eventId/discounts/rules');
    return r.data as List;
  }

  Future<Map<String, dynamic>> createEventDiscount(
      int eventId, Map<String, dynamic> data) async {
    final r = await dio.post('/events/$eventId/discounts/rules', data: data);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> deleteEventDiscount(int eventId, int discountId) async {
    await dio.delete('/events/$eventId/discounts/rules/$discountId');
  }

  Future<List<dynamic>> getMyDiscounts(int eventId) async {
    final r = await dio.get('/events/$eventId/my-discounts');
    return r.data as List;
  }

  // ─── Discount strategies ───

  Future<List<dynamic>> getDiscountStrategies() async {
    final r = await dio.get('/discount-strategies');
    return r.data as List;
  }

  Future<Map<String, dynamic>> createDiscountStrategy(Map<String, dynamic> data) async {
    final r = await dio.post('/discount-strategies', data: data);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> deleteDiscountStrategy(int id) async {
    await dio.delete('/discount-strategies/$id');
  }

  Future<void> attachDiscountStrategy(int eventId, int strategyId, {bool autoApply = true}) async {
    await dio.post('/events/$eventId/discount-strategies/$strategyId',
        data: {'auto_apply': autoApply});
  }

  Future<void> detachDiscountStrategy(int eventId, int strategyId) async {
    await dio.delete('/events/$eventId/discount-strategies/$strategyId');
  }

  Future<List<dynamic>> getEventDiscountStrategies(int eventId) async {
    final r = await dio.get('/events/$eventId/discount-strategies');
    return r.data as List;
  }

  // ─── Customer discount claims ───

  Future<List<dynamic>> getClaimableDiscounts(int eventId) async {
    final r = await dio.get('/events/$eventId/claimable-discounts');
    return r.data as List;
  }

  Future<void> claimDiscount(int eventId, int linkId) async {
    await dio.post('/events/$eventId/claim-discount/$linkId');
  }

  Future<void> unclaimDiscount(int eventId, int linkId) async {
    await dio.delete('/events/$eventId/claim-discount/$linkId');
  }

  // ─── Early bird discounts ───

  Future<List<dynamic>> getEarlyBirdDiscounts(int eventId) async {
    final r = await dio.get('/events/$eventId/early-bird-discounts');
    return r.data as List;
  }

  Future<Map<String, dynamic>> createEarlyBirdDiscount(
      int eventId, Map<String, dynamic> data) async {
    final r = await dio.post('/events/$eventId/early-bird-discounts', data: data);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> updateEarlyBirdDiscount(
      int eventId, int discountId, Map<String, dynamic> data) async {
    final r = await dio.patch('/events/$eventId/early-bird-discounts/$discountId', data: data);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> deleteEarlyBirdDiscount(int eventId, int discountId) async {
    await dio.delete('/events/$eventId/early-bird-discounts/$discountId');
  }

  // ─── Admin ───

  Future<PaginatedResult<TicketSale>> adminGetTickets({
    int offset = 0,
    int limit = 20,
    String? search,
    String? status,
  }) async {
    final params = <String, dynamic>{'offset': offset, 'limit': limit};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final r = await dio.get('/admin/tickets', queryParameters: params);
    final data = Map<String, dynamic>.from(r.data as Map);
    final items = (data['items'] as List)
        .map((j) => TicketSale.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    return PaginatedResult(
      items: items,
      hasMore: items.length >= limit,
      total: data['total'] as int?,
    );
  }
}
