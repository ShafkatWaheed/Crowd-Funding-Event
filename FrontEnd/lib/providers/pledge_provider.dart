import 'package:flutter/foundation.dart';
import '../models/funding.dart';
import '../repositories/base_repository.dart';
import '../repositories/funding_repository.dart';

class PledgeProvider extends ChangeNotifier {
  final FundingRepository _repo;
  PledgeProvider(this._repo);

  List<Pledge> pledges = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = true;
  String? error;
  String sortBy = 'newest';

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _repo.getMyPledges(sortBy: sortBy);
      pledges = result.items;
      hasMore = result.hasMore;
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    loadingMore = true;
    notifyListeners();
    try {
      final result = await _repo.getMyPledges(
        offset: pledges.length,
        sortBy: sortBy,
      );
      pledges.addAll(result.items);
      hasMore = result.hasMore;
    } catch (e) {
      error = e.toString();
    }
    loadingMore = false;
    notifyListeners();
  }

  Future<void> setSortBy(String value) async {
    if (sortBy == value) return;
    sortBy = value;
    await load();
  }

  Future<void> refresh() async {
    pledges = [];
    hasMore = true;
    await load();
  }

  // ─── Forwarded FundingRepository methods ─────────────────────────────────

  Future<PaginatedResult<Pledge>> getMyPledges({
    int offset = 0,
    int limit = 20,
    String? sortBy,
  }) =>
      _repo.getMyPledges(offset: offset, limit: limit, sortBy: sortBy);

  Future<FundingSummary> getFundingSummary(int eventId) =>
      _repo.getFundingSummary(eventId);

  Future<Map<String, dynamic>> getPledgePreview(
          int eventId, int amountCents, int reservedSpots) =>
      _repo.getPledgePreview(eventId, amountCents, reservedSpots);

  Future<Pledge> pledge(int eventId, int amountCents,
          {int reservedSpots = 0,
          List<Map<String, dynamic>>? tierReservations}) =>
      _repo.pledge(eventId, amountCents,
          reservedSpots: reservedSpots, tierReservations: tierReservations);

  Future<Map<String, dynamic>> unpledge(int eventId) =>
      _repo.unpledge(eventId);

  Future<Map<String, dynamic>> getPledgeReceipt(
          int eventId, int pledgeId) =>
      _repo.getPledgeReceipt(eventId, pledgeId);

  Future<Map<String, dynamic>> getMyPledgeReceipt(int pledgeId) =>
      _repo.getMyPledgeReceipt(pledgeId);

  Future<Map<String, dynamic>> getRefundStatus(int eventId) =>
      _repo.getRefundStatus(eventId);

  Future<PaginatedResult<Pledge>> getOrganizerPledges({
    String? status,
    String? eventStatus,
    String? genre,
    int? eventId,
    int offset = 0,
    int limit = 20,
  }) =>
      _repo.getOrganizerPledges(
        status: status,
        eventStatus: eventStatus,
        genre: genre,
        eventId: eventId,
        offset: offset,
        limit: limit,
      );

  Future<PaginatedResult<Pledge>> adminGetPledges({
    int offset = 0,
    int limit = 20,
    String? search,
    String? status,
    bool? isDonation,
  }) =>
      _repo.adminGetPledges(
        offset: offset,
        limit: limit,
        search: search,
        status: status,
        isDonation: isDonation,
      );

  Future<void> adminRefundPledge(int eventId, int fundingId) =>
      _repo.adminRefundPledge(eventId, fundingId);
}
