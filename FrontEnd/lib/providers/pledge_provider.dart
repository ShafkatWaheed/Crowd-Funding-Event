import 'package:flutter/foundation.dart';
import '../models/funding.dart';
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
}
