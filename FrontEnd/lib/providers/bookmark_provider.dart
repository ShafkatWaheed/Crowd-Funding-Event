import 'package:flutter/foundation.dart';

import '../models/event.dart';
import '../repositories/bookmark_repository.dart';

class BookmarkProvider extends ChangeNotifier {
  final BookmarkRepository _repo;
  BookmarkProvider(this._repo);

  Future<List<Event>> getBookmarkedEvents({
    String? search,
    String? status,
    int offset = 0,
    int limit = 20,
  }) =>
      _repo.getBookmarkedEvents(
          search: search, status: status, offset: offset, limit: limit);

  Future<BookmarkToggleResult> toggleBookmark(int eventId) =>
      _repo.toggleBookmark(eventId);
}
