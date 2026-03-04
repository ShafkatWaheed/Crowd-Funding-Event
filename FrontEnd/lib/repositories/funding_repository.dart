import '../models/funding.dart';
import '../models/receipt.dart';
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

  Future<FundingSummary> getFundingSummary(int eventId) async {
    final r = await dio.get('/events/$eventId/funding');
    return FundingSummary.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<PledgePreview> getPledgePreview(
    int eventId,
    int amountCents,
    int reservedSpots,
  ) async {
    final r = await dio.get('/events/$eventId/pledge-preview', queryParameters: {
      'amount_cents': amountCents,
      'reserved_spots': reservedSpots,
    });
    return PledgePreview.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<Pledge> pledge(
    int eventId,
    int amountCents, {
    int reservedSpots = 0,
    List<TierReservationInput>? tierReservations,
  }) async {
    final body = <String, dynamic>{
      'amount_cents': amountCents,
      'reserved_spots': reservedSpots,
    };
    if (tierReservations != null) body['tier_reservations'] = tierReservations.map((t) => t.toJson()).toList();
    final r = await dio.post('/events/$eventId/pledge', data: body);
    return Pledge.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<UnpledgeResult> unpledge(int eventId) async {
    final r = await dio.post('/events/$eventId/unpledge', data: {});
    return UnpledgeResult.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<PledgeReceipt> getPledgeReceipt(int eventId, int pledgeId) async {
    final r = await dio.get('/events/$eventId/pledges/$pledgeId/receipt');
    return PledgeReceipt.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<PledgeReceipt> getMyPledgeReceipt(int pledgeId) async {
    final r = await dio.get('/me/pledges/$pledgeId/receipt');
    return PledgeReceipt.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<RefundStatus> getRefundStatus(int eventId) async {
    final r = await dio.get('/events/$eventId/refund-status');
    return RefundStatus.fromJson(Map<String, dynamic>.from(r.data as Map));
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
