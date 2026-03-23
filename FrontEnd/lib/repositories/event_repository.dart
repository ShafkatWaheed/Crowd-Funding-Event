import 'package:dio/dio.dart';

import '../models/dashboard.dart';
import '../models/event.dart';
import '../models/event_image.dart';
import '../models/map_event.dart';
import '../models/milestone.dart';
import '../models/post.dart';
import '../models/rating.dart';
import '../models/schedule.dart';
import 'base_repository.dart';

class EventRepository extends BaseRepository {
  EventRepository(super.dio);

  // ─── Event CRUD ───

  /// Returns typed [EventListPage] with items and next_cursor. Prefer cursor over offset for infinite scroll.
  Future<EventListPage> getEvents({
    EventFilters? filters,
    int? offset,
    int limit = 20,
    String? cursor,
  }) async {
    final merged = <String, dynamic>{
      ...?filters?.toQueryParams(),
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
      return EventListPage.fromJson({'items': data, 'next_cursor': null});
    }
    return EventListPage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Event> getEvent(int id, {String? shareToken}) async {
    final resp = await dio.get('/events/$id',
        queryParameters: shareToken != null ? {'token': shareToken} : null);
    return Event.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<Event> createEvent(EventCreateRequest data) async {
    final resp = await dio.post('/events', data: data.toJson());
    return Event.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Event> updateEvent(
      int id, EventUpdateRequest data) async {
    final resp = await dio.patch('/events/$id', data: data.toJson());
    return Event.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> deleteEvent(int id) async {
    await dio.delete('/events/$id');
  }

  Future<Event> publishEvent(int id) async {
    final resp = await dio.post('/events/$id/publish');
    return Event.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Event> cancelEvent(int id,
      {required String reason}) async {
    final resp =
        await dio.post('/events/$id/cancel', data: {'reason': reason});
    return Event.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Event> reactivateEvent(int id) async {
    final resp = await dio.post('/events/$id/reactivate');
    return Event.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Event> startSellingTickets(int id) async {
    final resp = await dio.post('/events/$id/start-selling');
    return Event.fromJson(resp.data as Map<String, dynamic>);
  }

  // ─── My Events ───

  Future<List<Event>> getMyEvents(
      {int offset = 0, int limit = 20, String? sortBy}) async {
    final resp = await dio.get('/me/events', queryParameters: {
      'offset': offset,
      'limit': limit,
      if (sortBy != null) 'sort_by': sortBy,
    });
    return (resp.data as List)
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Event>> getCoOrganizedEvents({
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
    return (resp.data as List)
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── Discovery ───

  Future<FeaturedEvents> getFeaturedEvents(
      {bool sponsorshipOnly = false}) async {
    final resp = await dio.get('/events/featured', queryParameters: {
      if (sponsorshipOnly) 'sponsorship_only': true,
    });
    return FeaturedEvents.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<List<EventMarker>> getMapEvents({
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
    return (resp.data as List)
        .map((e) => EventMarker.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> getGenres() async {
    final resp = await dio.get('/events/genres');
    return List<String>.from(resp.data as List);
  }

  // ─── Event Images ───

  Future<List<EventImage>> getEventImages(int eventId) async {
    final resp = await dio.get('/events/$eventId/images');
    return (resp.data as List)
        .map((e) => EventImage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EventImage> addEventImage(int eventId,
      {required String imageUrl, String? caption, int displayOrder = 0}) async {
    final resp = await dio.post('/events/$eventId/images', queryParameters: {
      'image_url': imageUrl,
      if (caption != null) 'caption': caption,
      'display_order': displayOrder,
    });
    return EventImage.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<EventImage> uploadEventImage(int eventId,
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
    return EventImage.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> deleteEventImage(int eventId, int imageId) async {
    await dio.delete('/events/$eventId/images/$imageId');
  }

  // ─── Event Posts/Feed ───

  Future<List<EventPost>> getEventPosts(int eventId) async {
    final resp = await dio.get('/events/$eventId/posts');
    return (resp.data as List)
        .map((e) => EventPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EventPost> createEventPost(
      int eventId, String content) async {
    final resp = await dio
        .post('/events/$eventId/posts', data: {'content': content});
    return EventPost.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> deleteEventPost(int eventId, int postId) async {
    await dio.delete('/events/$eventId/posts/$postId');
  }

  Future<PostsToggleResult> toggleEventPosts(int eventId) async {
    final resp = await dio.post('/events/$eventId/toggle-posts');
    return PostsToggleResult.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  // ─── Reactions ───

  Future<ReactionResult> reactToEvent(
      int eventId, String reaction) async {
    final resp = await dio
        .post('/events/$eventId/react', queryParameters: {'reaction': reaction});
    return ReactionResult.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<MyReactionStatus> getMyReaction(int eventId) async {
    final resp = await dio.get('/events/$eventId/my-reaction');
    return MyReactionStatus.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  // ─── Clone ───

  Future<Event> cloneEvent(int eventId) async {
    final resp = await dio.post('/events/$eventId/clone');
    return Event.fromJson(resp.data as Map<String, dynamic>);
  }

  // ─── Co-Organizers ───

  Future<List<EventOrganizer>> getEventOrganizers(int eventId) async {
    final resp = await dio.get('/events/$eventId/organizers');
    return (resp.data as List)
        .map((e) => EventOrganizer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<EventOrganizer> addEventOrganizer(
      int eventId, AddEventOrganizerRequest data) async {
    final resp = await dio.post('/events/$eventId/organizers', data: data.toJson());
    return EventOrganizer.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<EventOrganizer> updateOrganizerPermission(
      int eventId, int userId, String permission) async {
    final resp = await dio.patch('/events/$eventId/organizers/$userId',
        data: {'permission': permission});
    return EventOrganizer.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<EventOrganizer> respondToInvitation(
      int eventId, int userId, bool accept) async {
    final resp = await dio.post('/events/$eventId/organizers/$userId/respond',
        data: {'accept': accept});
    return EventOrganizer.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<void> selfRemoveFromEvent(int eventId) async {
    await dio.delete('/events/$eventId/organizers/me');
  }

  Future<void> removeEventOrganizer(int eventId, int userId) async {
    await dio.delete('/events/$eventId/organizers/$userId');
  }

  Future<List<OrganizerSearchResult>> searchOrganizers(String query) async {
    final resp = await dio
        .get('/users/search-organizers', queryParameters: {'q': query});
    if (resp.data is! List) return [];
    return (resp.data as List)
        .map((e) => OrganizerSearchResult.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ─── Milestones ───

  Future<List<FundingMilestone>> getMilestones(int eventId) async {
    final resp = await dio.get('/events/$eventId/milestones');
    return (resp.data as List)
        .map((e) => FundingMilestone.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FundingMilestone> createMilestone(
      int eventId, MilestoneRequest data) async {
    final resp = await dio.post('/events/$eventId/milestones', data: data.toJson());
    return FundingMilestone.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<FundingMilestone> updateMilestone(
      int eventId, int milestoneId, MilestoneRequest data) async {
    final resp = await dio
        .patch('/events/$eventId/milestones/$milestoneId', data: data.toJson());
    return FundingMilestone.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> deleteMilestone(int eventId, int milestoneId) async {
    await dio.delete('/events/$eventId/milestones/$milestoneId');
  }

  Future<ReactionResult> reactToMilestone(
      int eventId, int milestoneId, String reaction) async {
    final resp = await dio.post(
      '/events/$eventId/milestones/$milestoneId/react',
      queryParameters: {'reaction': reaction},
    );
    return ReactionResult.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<MilestoneReactionStatus> getMyMilestoneReaction(
      int eventId, int milestoneId) async {
    final resp = await dio
        .get('/events/$eventId/milestones/$milestoneId/my-reaction');
    return MilestoneReactionStatus.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<List<MilestoneSnapshot>> getMilestoneSnapshots(int eventId) async {
    final resp = await dio.get('/events/$eventId/milestone-snapshots');
    return (resp.data as List)
        .map((e) => MilestoneSnapshot.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ─── Schedule ───

  /// Intentional: raw JSON for offline sync.
  Future<List<dynamic>> getScheduleRaw(int eventId) async {
    final resp = await dio.get('/events/$eventId/schedule');
    return resp.data as List;
  }

  Future<List<ScheduleDay>> getSchedule(int eventId) async {
    final resp = await dio.get('/events/$eventId/schedule');
    return (resp.data as List)
        .map((e) => ScheduleDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ScheduleItem> createScheduleItem(
      int eventId, CreateScheduleItemRequest data) async {
    final resp = await dio.post('/events/$eventId/schedule', data: data.toJson());
    return ScheduleItem.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<ScheduleItem>> bulkCreateSchedule(
      int eventId, List<CreateScheduleItemRequest> items) async {
    final resp = await dio.post('/events/$eventId/schedule/bulk',
        data: items.map((i) => i.toJson()).toList());
    return (resp.data as List)
        .map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ScheduleItem> updateScheduleItem(
      int eventId, int itemId, UpdateScheduleItemRequest data) async {
    final resp =
        await dio.patch('/events/$eventId/schedule/$itemId', data: data.toJson());
    return ScheduleItem.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> deleteScheduleItem(int eventId, int itemId) async {
    await dio.delete('/events/$eventId/schedule/$itemId');
  }

  Future<ScheduleImageResult> uploadScheduleImage(
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
    return ScheduleImageResult.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<ScheduleItem> deleteScheduleImage(
      int eventId, int itemId) async {
    final resp = await dio.delete('/events/$eventId/schedule/$itemId/image');
    return ScheduleItem.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  /// Sync method — returns the URL string for schedule CSV export.
  String getScheduleExportUrl(int eventId) {
    return '${dio.options.baseUrl}/events/$eventId/schedule/export';
  }

  // ─── Bookmarks ───

  Future<BookmarkToggleResult> toggleBookmark(int eventId) async {
    final resp = await dio.post('/me/bookmarks/$eventId');
    return BookmarkToggleResult.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<Map<int, bool>> checkBookmarks(List<int> eventIds) async {
    final ids = eventIds.join(',');
    final resp = await dio
        .get('/me/bookmarks/check', queryParameters: {'event_ids': ids});
    final data = Map<String, dynamic>.from(resp.data as Map);
    final bookmarkedList = (data['bookmarked_ids'] as List?)
            ?.where((e) => e != null)
            .map((e) => (e as num).toInt())
            .toList() ??
        [];
    final bookmarkedSet = bookmarkedList.toSet();
    return {for (final id in eventIds) id: bookmarkedSet.contains(id)};
  }

  Future<List<Event>> getBookmarkedEvents(
      {String? search, String? status, int offset = 0, int limit = 20}) async {
    final params = <String, dynamic>{'offset': offset, 'limit': limit};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final resp = await dio.get('/me/bookmarks', queryParameters: params);
    return (resp.data as List)
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── Ratings/Reviews ───

  Future<MyRating> createRating(
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
    return MyRating.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<RatingsSummary> getEventRatingsSummary(int eventId) async {
    final resp = await dio.get('/events/$eventId/ratings/summary');
    return RatingsSummary.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<List<Rating>> getEventRatings(int eventId,
      {String? direction}) async {
    final params = <String, dynamic>{};
    if (direction != null) params['direction'] = direction;
    final resp = await dio.get('/events/$eventId/ratings',
        queryParameters: params);
    return (resp.data as List)
        .map((e) => Rating.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ─── Registration ───

  Future<Registration> register(int eventId) async {
    final resp = await dio.post('/events/$eventId/register');
    return Registration.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<UnregisterResult> unregister(int eventId) async {
    final resp = await dio.post('/events/$eventId/unregister');
    return UnregisterResult.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<Registration?> getMyRegistration(int eventId) async {
    final resp = await dio.get('/events/$eventId/my-registration');
    if (resp.data == null) return null;
    final data = Map<String, dynamic>.from(resp.data as Map);
    // Endpoint returns {registered: bool, status: str|null} — not a full Registration.
    // Only return non-null when the user is actually registered.
    final isRegistered = data['registered'] as bool? ?? false;
    if (!isRegistered) return null;
    return Registration(
      id: 0,
      eventId: eventId,
      userId: 0,
      status: data['status'] as String? ?? 'registered',
      createdAt: DateTime.now(),
    );
  }

  Future<List<Registration>> getRegistrations(int eventId) async {
    final resp = await dio.get('/events/$eventId/registrations');
    return (resp.data as List)
        .map((e) => Registration.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Registration> decideRegistration(
      int eventId, int registrationId, String action) async {
    final resp = await dio.post(
      '/events/$eventId/registrations/$registrationId/decision',
      data: {'action': action},
    );
    return Registration.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<CapacityInfo> getCapacityInfo(int eventId) async {
    final resp = await dio.get('/events/$eventId/capacity-info');
    return CapacityInfo.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  // ─── Extension ───

  Future<Event> extendFunding(
      int eventId, ExtendFundingInput data) async {
    final resp =
        await dio.post('/events/$eventId/extend-funding', data: data.toJson());
    return Event.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<Event> setEventDate(
      int eventId, SetEventDateInput data) async {
    final resp =
        await dio.post('/events/$eventId/set-event-date', data: data.toJson());
    return Event.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<Event> decideExtension(
      int eventId, String action) async {
    final resp = await dio.post(
      '/events/$eventId/extension-decision',
      data: {'action': action},
    );
    return Event.fromJson(Map<String, dynamic>.from(resp.data as Map));
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

  Future<OrganizerDashboard> getOrganizerDashboard(
      {String? status, int? eventId, String? genre, String? period}) async {
    final resp = await dio.get('/me/organizer-dashboard', queryParameters: {
      if (status != null) 'status': status,
      if (eventId != null) 'event_id': eventId,
      if (genre != null) 'genre': genre,
      if (period != null) 'period': period,
    });
    return OrganizerDashboard.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<OrganizerTimeSeries> getOrganizerTimeSeries(
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
    return OrganizerTimeSeries.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<List<CustomerHistoryItem>> getOrganizerCustomers(
      {int offset = 0, int limit = 20}) async {
    final resp = await dio.get('/me/customers',
        queryParameters: {'offset': offset, 'limit': limit});
    return (resp.data as List)
        .map((e) => CustomerHistoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ─── Public Config ───

  Future<PublicConfig> getPublicConfig() async {
    final resp = await dio.get('/config');
    return PublicConfig.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  // ─── Calendar ───

  /// Returns the .ics calendar URL for an event.
  String calendarUrl(int eventId) =>
      '${dio.options.baseUrl}/events/$eventId/calendar.ics';
}
