import 'base_repository.dart';

class BookmarkRepository extends BaseRepository {
  BookmarkRepository(super.dio);

  Future<List<dynamic>> getBookmarkedEvents({
    String? search,
    String? status,
    int offset = 0,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'offset': offset, 'limit': limit};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final resp = await dio.get('/me/bookmarks', queryParameters: params);
    return resp.data as List;
  }

  Future<Map<String, dynamic>> toggleBookmark(int eventId) async {
    final resp = await dio.post('/me/bookmarks/$eventId');
    return resp.data;
  }
}
