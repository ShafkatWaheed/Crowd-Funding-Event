import 'package:dio/dio.dart';

import 'base_repository.dart';

class EventRepository extends BaseRepository {
  EventRepository(super.dio);

  // ─── Event CRUD ───

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

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> data) async {
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

  Future<Map<String, dynamic>> cancelEvent(int id,
      {required String reason}) async {
    final resp =
        await dio.post('/events/$id/cancel', data: {'reason': reason});
    return resp.data;
  }

  Future<Map<String, dynamic>> reactivateEvent(int id) async {
    final resp = await dio.post('/events/$id/reactivate');
    return resp.data;
  }

  Future<Map<String, dynamic>> startSellingTickets(int id) async {
    final resp = await dio.post('/events/$id/start-selling');
    return resp.data;
  }

  // ─── My Events ───

  Future<List<dynamic>> getMyEvents(
      {int offset = 0, int limit = 20, String? sortBy}) async {
    final resp = await dio.get('/me/events', queryParameters: {
      'offset': offset,
      'limit': limit,
      if (sortBy != null) 'sort_by': sortBy,
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

  // ─── Discovery ───

  Future<Map<String, dynamic>> getFeaturedEvents(
      {bool sponsorshipOnly = false}) async {
    final resp = await dio.get('/events/featured', queryParameters: {
      if (sponsorshipOnly) 'sponsorship_only': true,
    });
    return resp.data;
  }

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
    bool sponsorshipOnly = false,
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
    if (sponsorshipOnly) params['sponsorship_only'] = true;
    final resp = await dio.get('/events/map', queryParameters: params);
    return resp.data;
  }

  Future<List<dynamic>> getGenres() async {
    final resp = await dio.get('/events/genres');
    return resp.data;
  }

  // ─── Event Images ───

  Future<List<dynamic>> getEventImages(int eventId) async {
    final resp = await dio.get('/events/$eventId/images');
    return resp.data;
  }

  Future<Map<String, dynamic>> addEventImage(int eventId,
      {required String imageUrl, String? caption, int displayOrder = 0}) async {
    final resp = await dio.post('/events/$eventId/images', queryParameters: {
      'image_url': imageUrl,
      if (caption != null) 'caption': caption,
      'display_order': displayOrder,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> uploadEventImage(int eventId,
      {required List<int> fileBytes,
      required String fileName,
      String? caption,
      int displayOrder = 0}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      if (caption != null) 'caption': caption,
      'display_order': displayOrder,
    });
    final resp =
        await dio.post('/events/$eventId/images/upload', data: formData);
    return resp.data;
  }

  Future<void> deleteEventImage(int eventId, int imageId) async {
    await dio.delete('/events/$eventId/images/$imageId');
  }

  // ─── Event Posts/Feed ───

  Future<List<dynamic>> getEventPosts(int eventId) async {
    final resp = await dio.get('/events/$eventId/posts');
    return resp.data;
  }

  Future<Map<String, dynamic>> createEventPost(
      int eventId, String content) async {
    final resp = await dio
        .post('/events/$eventId/posts', data: {'content': content});
    return resp.data;
  }

  Future<void> deleteEventPost(int eventId, int postId) async {
    await dio.delete('/events/$eventId/posts/$postId');
  }

  Future<Map<String, dynamic>> toggleEventPosts(int eventId) async {
    final resp = await dio.post('/events/$eventId/toggle-posts');
    return resp.data;
  }

  // ─── Reactions ───

  Future<Map<String, dynamic>> reactToEvent(
      int eventId, String reaction) async {
    final resp = await dio
        .post('/events/$eventId/react', queryParameters: {'reaction': reaction});
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
    final resp = await dio
        .get('/users/search-organizers', queryParameters: {'q': query});
    return resp.data is List ? resp.data : [];
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
    final resp = await dio
        .patch('/events/$eventId/milestones/$milestoneId', data: data);
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
    final resp = await dio
        .get('/events/$eventId/milestones/$milestoneId/my-reaction');
    return resp.data;
  }

  Future<List<dynamic>> getMilestoneSnapshots(int eventId) async {
    final resp = await dio.get('/events/$eventId/milestone-snapshots');
    return resp.data;
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

  Future<Map<String, dynamic>> deleteScheduleImage(
      int eventId, int itemId) async {
    final resp = await dio.delete('/events/$eventId/schedule/$itemId/image');
    return resp.data;
  }

  /// Sync method — returns the URL string for schedule CSV export.
  String getScheduleExportUrl(int eventId) {
    return '${dio.options.baseUrl}/events/$eventId/schedule/export';
  }

  // ─── Bookmarks ───

  Future<Map<String, dynamic>> toggleBookmark(int eventId) async {
    final resp = await dio.post('/me/bookmarks/$eventId');
    return resp.data;
  }

  Future<Map<String, dynamic>> checkBookmarks(List<int> eventIds) async {
    final ids = eventIds.join(',');
    final resp = await dio
        .get('/me/bookmarks/check', queryParameters: {'event_ids': ids});
    return resp.data;
  }

  Future<List<dynamic>> getBookmarkedEvents(
      {String? search, String? status, int offset = 0, int limit = 20}) async {
    final params = <String, dynamic>{'offset': offset, 'limit': limit};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final resp = await dio.get('/me/bookmarks', queryParameters: params);
    return resp.data as List;
  }

  // ─── Ratings/Reviews ───

  Future<Map<String, dynamic>> createRating(
    int eventId, {
    required String direction,
    int? ratedUserId,
    required int stars,
    String? description,
  }) async {
    final resp = await dio.post('/events/$eventId/ratings', data: {
      'direction': direction,
      if (ratedUserId != null) 'rated_user_id': ratedUserId,
      'stars': stars,
      if (description != null && description.isNotEmpty)
        'description': description,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> getEventRatingsSummary(int eventId) async {
    final resp = await dio.get('/events/$eventId/ratings/summary');
    return resp.data;
  }

  Future<List<dynamic>> getEventRatings(int eventId,
      {String? direction}) async {
    final params = <String, dynamic>{};
    if (direction != null) params['direction'] = direction;
    final resp = await dio.get('/events/$eventId/ratings',
        queryParameters: params);
    return resp.data as List;
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

  Future<Map<String, dynamic>> decideRegistration(
      int eventId, int registrationId, String action) async {
    final resp = await dio.post(
      '/events/$eventId/registrations/$registrationId/decision',
      data: {'action': action},
    );
    return resp.data;
  }

  Future<Map<String, dynamic>> getCapacityInfo(int eventId) async {
    final resp = await dio.get('/events/$eventId/capacity-info');
    return resp.data;
  }

  // ─── Extension ───

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

  // ─── Event Cities ───

  Future<List<String>> getEventCities() async {
    final resp = await dio.get('/events/cities');
    final data = resp.data;
    if (data is Map) return List<String>.from(data['cities'] ?? []);
    if (data is List) return List<String>.from(data);
    return [];
  }

  // ─── Organizer Dashboard ───

  Future<Map<String, dynamic>> getOrganizerDashboard(
      {String? status, int? eventId, String? genre, String? period}) async {
    final resp = await dio.get('/me/organizer-dashboard', queryParameters: {
      if (status != null) 'status': status,
      if (eventId != null) 'event_id': eventId,
      if (genre != null) 'genre': genre,
      if (period != null) 'period': period,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> getOrganizerTimeSeries(
      {int days = 30,
      String? status,
      int? eventId,
      String? genre}) async {
    final resp =
        await dio.get('/me/organizer-dashboard/time-series', queryParameters: {
      'days': days,
      if (status != null) 'status': status,
      if (eventId != null) 'event_id': eventId,
      if (genre != null) 'genre': genre,
    });
    return resp.data;
  }

  Future<List<dynamic>> getOrganizerCustomers(
      {int offset = 0, int limit = 20}) async {
    final resp = await dio.get('/me/customers',
        queryParameters: {'offset': offset, 'limit': limit});
    return resp.data;
  }

  // ─── Public Config ───

  Future<Map<String, dynamic>> getPublicConfig() async {
    final resp = await dio.get('/config');
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, bool>> getFeatureFlags() async {
    try {
      final resp = await dio.get('/config');
      final data = resp.data as Map<String, dynamic>;
      return {
        for (final entry in data.entries)
          if (entry.key.startsWith('feature_'))
            entry.key: entry.value == true,
      };
    } catch (_) {
      return {};
    }
  }

  // ─── Calendar ───

  /// Returns the .ics calendar URL for an event.
  String calendarUrl(int eventId) =>
      '${dio.options.baseUrl}/events/$eventId/calendar.ics';
}
