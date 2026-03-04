import '../models/event.dart';
import 'base_repository.dart';

class BookmarkRepository extends BaseRepository {
  BookmarkRepository(super.dio);

  Future<List<Event>> getBookmarkedEvents({
    String? search,
    String? status,
    int offset = 0,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'offset': offset, 'limit': limit};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final resp = await dio.get('/me/bookmarks', queryParameters: params);
    return (resp.data as List).map((e) => Event.fromJson(e)).toList();
  }

  Future<BookmarkToggleResult> toggleBookmark(int eventId) async {
    final resp = await dio.post('/me/bookmarks/$eventId');
    return BookmarkToggleResult.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }
}
