import '../models/funding.dart';
import 'base_repository.dart';

class FundingRepository extends BaseRepository {
  FundingRepository(super.dio);

  Future<PaginatedResult<Pledge>> getMyPledges({
    int offset = 0,
    int limit = 20,
    String? sortBy,
  }) async {
    final params = <String, dynamic>{'offset': offset, 'limit': limit};
    if (sortBy != null) params['sort_by'] = sortBy;
    final r = await dio.get('/me/pledges', queryParameters: params);
    final list = r.data as List;
    return PaginatedResult(
      items: list.map((j) => Pledge.fromJson(Map<String, dynamic>.from(j))).toList(),
      hasMore: list.length >= limit,
    );
  }

  Future<Map<String, dynamic>> getFundingSummary(int eventId) async {
    final r = await dio.get('/events/$eventId/funding');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> getPledgePreview(
    int eventId,
    int amountCents,
    int reservedSpots,
  ) async {
    final r = await dio.get('/events/$eventId/pledge-preview', queryParameters: {
      'amount_cents': amountCents,
      'reserved_spots': reservedSpots,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> pledge(
    int eventId,
    int amountCents, {
    int reservedSpots = 0,
    List<Map<String, dynamic>>? tierReservations,
  }) async {
    final body = <String, dynamic>{
      'amount_cents': amountCents,
      'reserved_spots': reservedSpots,
    };
    if (tierReservations != null) body['tier_reservations'] = tierReservations;
    final r = await dio.post('/events/$eventId/pledge', data: body);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> unpledge(int eventId) async {
    final r = await dio.post('/events/$eventId/unpledge', data: {});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> getPledgeReceipt(int eventId, int pledgeId) async {
    final r = await dio.get('/events/$eventId/pledges/$pledgeId/receipt');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> getMyPledgeReceipt(int pledgeId) async {
    final r = await dio.get('/me/pledges/$pledgeId/receipt');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> getRefundStatus(int eventId) async {
    final r = await dio.get('/events/$eventId/refund-status');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<PaginatedResult<Pledge>> getOrganizerPledges({
    String? status,
    String? eventStatus,
    String? genre,
    int? eventId,
    int offset = 0,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'offset': offset, 'limit': limit};
    if (status != null) params['status'] = status;
    if (eventStatus != null) params['event_status'] = eventStatus;
    if (genre != null) params['genre'] = genre;
    if (eventId != null) params['event_id'] = eventId;
    final r = await dio.get('/me/organizer-pledges', queryParameters: params);
    final list = r.data as List;
    return PaginatedResult(
      items: list.map((j) => Pledge.fromJson(Map<String, dynamic>.from(j))).toList(),
      hasMore: list.length >= limit,
    );
  }

  Future<PaginatedResult<Pledge>> adminGetPledges({
    int offset = 0,
    int limit = 20,
    String? search,
    String? status,
    bool? isDonation,
  }) async {
    final params = <String, dynamic>{'offset': offset, 'limit': limit};
    if (search != null) params['search'] = search;
    if (status != null) params['status'] = status;
    if (isDonation != null) params['is_donation'] = isDonation;
    final r = await dio.get('/admin/pledges', queryParameters: params);
    final data = Map<String, dynamic>.from(r.data as Map);
    final items = (data['items'] as List)
        .map((j) => Pledge.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    return PaginatedResult(
      items: items,
      hasMore: items.length >= limit,
      total: data['total'] as int?,
    );
  }

  Future<void> adminRefundPledge(int eventId, int fundingId) async {
    await dio.post('/admin/events/$eventId/pledges/$fundingId/refund', data: {});
  }
}
