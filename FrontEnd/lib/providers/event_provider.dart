import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/dashboard.dart';
import '../models/event.dart';
import '../models/event_image.dart';
import '../models/map_event.dart';
import '../models/milestone.dart';
import '../models/post.dart';
import '../models/rating.dart';
import '../models/schedule.dart';
import '../repositories/base_repository.dart';
import '../repositories/event_repository.dart';

class EventProvider extends ChangeNotifier {
  final EventRepository _repo;

  List<Event> _events = [];
  Event? _selectedEvent;
  bool _isLoading = false;
  String? _error;

  // Pagination state (keyset cursor for infinite scroll)
  static const int _pageSize = 20;
  String? _nextCursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  EventFilters? _lastFilters;

  // In-memory cache: event id → (Event, timestamp)
  final Map<int, _CacheEntry<Event>> _eventCache = {};
  static const Duration _cacheTtl = Duration(seconds: 60);

  // Incremented on every register/unregister so listeners can react.
  int _registrationVersion = 0;
  // Incremented when viewer-specific data (pledge, tickets) changes so
  // list screens (Home, Explore) know to refresh their activity chips.
  int _viewerDataVersion = 0;

  EventProvider(this._repo);

  List<Event> get events => _events;
  Event? get selectedEvent => _selectedEvent;
  Event? get event => _selectedEvent;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  int get registrationVersion => _registrationVersion;
  int get viewerDataVersion => _viewerDataVersion;

  Future<void> loadEvents({EventFilters? filters}) async {
    _isLoading = true;
    _error = null;
    _nextCursor = null;
    _hasMore = true;
    _lastFilters = filters;
    notifyListeners();

    try {
      final result = await _repo.getEvents(filters: filters, limit: _pageSize);
      _events = result.items;
      _nextCursor = result.nextCursor;
      _hasMore = _nextCursor != null;
    } catch (e) {
      _error = ApiError.extractMessage(e, fallback: 'Failed to load events.');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreEvents() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final result = await _repo.getEvents(
        filters: _lastFilters,
        limit: _pageSize,
        cursor: _nextCursor,
      );
      _events.addAll(result.items);
      _nextCursor = result.nextCursor;
      _hasMore = _nextCursor != null;
    } catch (e) {
      _error = ApiError.extractMessage(e, fallback: 'Failed to load more events.');
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> loadEvent(int id, {bool forceRefresh = false, String? shareToken}) async {
    // Bypass cache when a share token is provided (private event access)
    if (!forceRefresh && shareToken == null) {
      final cached = _eventCache[id];
      if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheTtl) {
        _selectedEvent = cached.data;
        _error = null;
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selectedEvent = await _repo.getEvent(id, shareToken: shareToken);
      // Don't cache private events — they require token validation on every load
      if (_selectedEvent != null && !_selectedEvent!.isPrivate) {
        _eventCache[id] = _CacheEntry(_selectedEvent!, DateTime.now());
      }
    } catch (e) {
      _error = ApiError.extractMessage(e, fallback: 'Failed to load event details.');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Optimistically adjust the registration count on the selected event.
  /// Call immediately after a successful register/unregister so the UI
  /// updates without waiting for the background [loadEvent] round-trip.
  void patchRegistrationCount(int eventId, int delta) {
    if (_selectedEvent == null || _selectedEvent!.id != eventId) return;
    final updated = _selectedEvent!.copyWithRegistrationCount(
      (_selectedEvent!.registrationCount + delta).clamp(0, 999999),
    );
    _selectedEvent = updated;
    _eventCache[eventId] = _CacheEntry(updated, DateTime.now());
    _registrationVersion++;
    notifyListeners();
  }

  /// Signal that the current user's event membership changed (ticket purchase,
  /// registration, etc.) so the Manage tab reloads its list.
  void bumpUserEventsVersion() {
    _registrationVersion++;
    notifyListeners();
  }

  /// Optimistically update viewer-specific fields on an event in the explore
  /// list and cache. Triggers [viewerDataVersion] so Home/Explore screens
  /// can refresh their activity chips without a full network round-trip.
  ///
  /// Pass [pledgeDelta] / [ticketDelta] to ADD to the existing values
  /// (use null to leave a field unchanged).
  void patchViewerData(int eventId, {int? pledgeDelta, int? ticketDelta}) {
    // Patch the explore events list.
    for (int i = 0; i < _events.length; i++) {
      if (_events[i].id == eventId) {
        final old = _events[i];
        _events[i] = old.copyWithViewerData(
          pledgeAmountCents: pledgeDelta != null
              ? (old.viewerPledgeAmountCents ?? 0) + pledgeDelta
              : null,
          ticketCount: ticketDelta != null
              ? (old.viewerTicketCount ?? 0) + ticketDelta
              : null,
        );
        break;
      }
    }
    // Patch the single-event cache too.
    if (_eventCache.containsKey(eventId)) {
      final entry = _eventCache[eventId]!;
      _eventCache[eventId] = _CacheEntry(
        entry.data.copyWithViewerData(
          pledgeAmountCents: pledgeDelta != null
              ? (entry.data.viewerPledgeAmountCents ?? 0) + pledgeDelta
              : null,
          ticketCount: ticketDelta != null
              ? (entry.data.viewerTicketCount ?? 0) + ticketDelta
              : null,
        ),
        entry.timestamp,
      );
    }
    _viewerDataVersion++;
    notifyListeners();
  }

  void invalidateCache(int id) {
    _eventCache.remove(id);
  }

  /// Clear only the in-memory detail cache (used after single-event mutations).
  void clearDetailCache() {
    _eventCache.clear();
  }

  /// Reset ALL cached state — events list, pagination, selected event, detail
  /// cache, loading flags, and viewer-data versions. Called on logout to prevent
  /// data from one user session leaking into another.
  void clearCache() {
    _events = [];
    _selectedEvent = null;
    _isLoading = false;
    _isLoadingMore = false;
    _error = null;
    _nextCursor = null;
    _hasMore = true;
    _lastFilters = null;
    _eventCache.clear();
    _registrationVersion = 0;
    _viewerDataVersion = 0;
    notifyListeners();
  }

  Future<bool> createEvent(EventCreateRequest data) async {
    try {
      await _repo.createEvent(data);
      await loadEvents();
      return true;
    } catch (e) {
      _error = ApiError.extractMessage(e, fallback: 'Failed to create event.');
      notifyListeners();
      return false;
    }
  }

  Future<bool> publishEvent(int id) async {
    try {
      await _repo.publishEvent(id);
      invalidateCache(id);
      await loadEvent(id, forceRefresh: true);
      return true;
    } catch (e) {
      _error = ApiError.extractMessage(e, fallback: 'Failed to publish event.');
      notifyListeners();
      return false;
    }
  }

  Future<String?> cancelEvent(int id, {required String reason}) async {
    try {
      await _repo.cancelEvent(id, reason: reason);
      invalidateCache(id);
      await loadEvent(id, forceRefresh: true);
      return 'Event cancelled successfully.';
    } on DioException catch (e) {
      final detail = e.response?.data;
      final msg = (detail is Map ? detail['detail'] : null) as String?;
      if (e.response?.statusCode == 409 && msg != null && msg.contains('admin')) {
        invalidateCache(id);
        await loadEvent(id, forceRefresh: true);
        return msg;
      }
      _error = msg ?? ApiError.extractMessage(e, fallback: 'Failed to cancel event.');
      notifyListeners();
      return null;
    } catch (e) {
      _error = ApiError.extractMessage(e, fallback: 'Failed to cancel event.');
      notifyListeners();
      return null;
    }
  }

  Future<bool> reactivateEvent(int id) async {
    try {
      await _repo.reactivateEvent(id);
      invalidateCache(id);
      await loadEvent(id, forceRefresh: true);
      return true;
    } catch (e) {
      _error = ApiError.extractMessage(e, fallback: 'Failed to reactivate event.');
      notifyListeners();
      return false;
    }
  }

  Future<bool> startSellingTickets(int id) async {
    try {
      await _repo.startSellingTickets(id);
      invalidateCache(id);
      await loadEvent(id, forceRefresh: true);
      return true;
    } catch (e) {
      _error = ApiError.extractMessage(e, fallback: 'Failed to start selling tickets.');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteEvent(int id) async {
    try {
      await _repo.deleteEvent(id);
      _selectedEvent = null;
      invalidateCache(id);
      await loadEvents();
      return true;
    } catch (e) {
      _error = ApiError.extractMessage(e, fallback: 'Failed to delete event.');
      notifyListeners();
      return false;
    }
  }

  void clearSelected() {
    _selectedEvent = null;
    notifyListeners();
  }

  // ─── Forwarded EventRepository methods ─────────────────────────────────
  // Screens call these via context.read<EventProvider>() instead of touching
  // the repository directly.

  // -- Raw list (used by screens that manage their own pagination)

  Future<EventListPage> getEvents({
    EventFilters? filters,
    int? offset,
    int limit = 20,
    String? cursor,
  }) =>
      _repo.getEvents(
          filters: filters, offset: offset, limit: limit, cursor: cursor);

  // -- CRUD --

  Future<Event> getEvent(int id) => _repo.getEvent(id);

  Future<Event> createEventRaw(EventCreateRequest data) =>
      _repo.createEvent(data);

  Future<Event> updateEvent(int id, EventUpdateRequest data) async {
    final updated = await _repo.updateEvent(id, data);
    _selectedEvent = updated;
    _eventCache[id] = _CacheEntry(updated, DateTime.now());
    notifyListeners();
    return updated;
  }

  Future<Event> cloneEvent(int eventId) => _repo.cloneEvent(eventId);

  // -- My Events --

  Future<List<Event>> getMyEvents(
          {int offset = 0, int limit = 20, String? sortBy}) =>
      _repo.getMyEvents(offset: offset, limit: limit, sortBy: sortBy);

  Future<List<Event>> getCoOrganizedEvents({
    String? status,
    String? search,
    int offset = 0,
    int limit = 20,
  }) =>
      _repo.getCoOrganizedEvents(
          status: status, search: search, offset: offset, limit: limit);

  // -- Discovery --

  Future<FeaturedEvents> getFeaturedEvents(
          {bool sponsorshipOnly = false}) =>
      _repo.getFeaturedEvents(sponsorshipOnly: sponsorshipOnly);

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
  }) =>
      _repo.getMapEvents(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        city: city,
        live: live,
        organizerId: organizerId,
        search: search,
        genre: genre,
        status: status,
        sponsorshipOnly: sponsorshipOnly,
      );

  Future<List<String>> getGenres() => _repo.getGenres();

  // -- Event Images --

  Future<List<EventImage>> getEventImages(int eventId) =>
      _repo.getEventImages(eventId);

  Future<EventImage> addEventImage(int eventId,
          {required String imageUrl, String? caption, int displayOrder = 0}) =>
      _repo.addEventImage(eventId,
          imageUrl: imageUrl, caption: caption, displayOrder: displayOrder);

  Future<EventImage> uploadEventImage(int eventId,
          {required List<int> fileBytes,
          required String fileName,
          String? caption,
          int displayOrder = 0}) =>
      _repo.uploadEventImage(eventId,
          fileBytes: fileBytes,
          fileName: fileName,
          caption: caption,
          displayOrder: displayOrder);

  Future<void> deleteEventImage(int eventId, int imageId) =>
      _repo.deleteEventImage(eventId, imageId);

  // -- Posts/Feed --

  Future<List<EventPost>> getEventPosts(int eventId) =>
      _repo.getEventPosts(eventId);

  Future<EventPost> createEventPost(int eventId, String content) =>
      _repo.createEventPost(eventId, content);

  Future<void> deleteEventPost(int eventId, int postId) =>
      _repo.deleteEventPost(eventId, postId);

  Future<PostsToggleResult> toggleEventPosts(int eventId) =>
      _repo.toggleEventPosts(eventId);

  // -- Reactions --

  Future<ReactionResult> reactToEvent(int eventId, String reaction) =>
      _repo.reactToEvent(eventId, reaction);

  Future<MyReactionStatus> getMyReaction(int eventId) =>
      _repo.getMyReaction(eventId);

  // -- Co-Organizers --

  Future<List<EventOrganizer>> getEventOrganizers(int eventId) =>
      _repo.getEventOrganizers(eventId);

  Future<EventOrganizer> addEventOrganizer(
          int eventId, AddEventOrganizerRequest data) =>
      _repo.addEventOrganizer(eventId, data);

  Future<EventOrganizer> updateOrganizerPermission(
          int eventId, int userId, String permission) =>
      _repo.updateOrganizerPermission(eventId, userId, permission);

  Future<EventOrganizer> respondToInvitation(
          int eventId, int userId, bool accept) =>
      _repo.respondToInvitation(eventId, userId, accept);

  Future<void> selfRemoveFromEvent(int eventId) =>
      _repo.selfRemoveFromEvent(eventId);

  Future<void> removeEventOrganizer(int eventId, int userId) =>
      _repo.removeEventOrganizer(eventId, userId);

  Future<List<OrganizerSearchResult>> searchOrganizers(String query) =>
      _repo.searchOrganizers(query);

  // -- Milestones --

  Future<List<FundingMilestone>> getMilestones(int eventId) =>
      _repo.getMilestones(eventId);

  Future<FundingMilestone> createMilestone(
          int eventId, MilestoneRequest data) =>
      _repo.createMilestone(eventId, data);

  Future<FundingMilestone> updateMilestone(
          int eventId, int milestoneId, MilestoneRequest data) =>
      _repo.updateMilestone(eventId, milestoneId, data);

  Future<void> deleteMilestone(int eventId, int milestoneId) =>
      _repo.deleteMilestone(eventId, milestoneId);

  Future<ReactionResult> reactToMilestone(
          int eventId, int milestoneId, String reaction) =>
      _repo.reactToMilestone(eventId, milestoneId, reaction);

  Future<MilestoneReactionStatus> getMyMilestoneReaction(
          int eventId, int milestoneId) =>
      _repo.getMyMilestoneReaction(eventId, milestoneId);

  Future<List<MilestoneSnapshot>> getMilestoneSnapshots(int eventId) =>
      _repo.getMilestoneSnapshots(eventId);

  // -- Schedule --

  Future<List<ScheduleDay>> getSchedule(int eventId) =>
      _repo.getSchedule(eventId);

  Future<ScheduleItem> createScheduleItem(
          int eventId, CreateScheduleItemRequest data) =>
      _repo.createScheduleItem(eventId, data);

  Future<List<ScheduleItem>> bulkCreateSchedule(
          int eventId, List<CreateScheduleItemRequest> items) =>
      _repo.bulkCreateSchedule(eventId, items);

  Future<ScheduleItem> updateScheduleItem(
          int eventId, int itemId, UpdateScheduleItemRequest data) =>
      _repo.updateScheduleItem(eventId, itemId, data);

  Future<void> deleteScheduleItem(int eventId, int itemId) =>
      _repo.deleteScheduleItem(eventId, itemId);

  Future<ScheduleImageResult> uploadScheduleImage(
          int eventId, int itemId, dynamic fileBytes, String fileName,
          {String? caption}) =>
      _repo.uploadScheduleImage(eventId, itemId, fileBytes, fileName,
          caption: caption);

  Future<ScheduleItem> deleteScheduleImage(int eventId, int itemId) =>
      _repo.deleteScheduleImage(eventId, itemId);

  String getScheduleExportUrl(int eventId) =>
      _repo.getScheduleExportUrl(eventId);

  // -- Bookmarks --

  Future<BookmarkToggleResult> toggleBookmark(int eventId) =>
      _repo.toggleBookmark(eventId);

  Future<Map<int, bool>> checkBookmarks(List<int> eventIds) =>
      _repo.checkBookmarks(eventIds);

  Future<List<Event>> getBookmarkedEvents(
          {String? search, String? status, int offset = 0, int limit = 20}) =>
      _repo.getBookmarkedEvents(
          search: search, status: status, offset: offset, limit: limit);

  // -- Ratings --

  Future<MyRating> createRating(
    int eventId, {
    required String direction,
    int? ratedUserId,
    required int stars,
    String? description,
  }) =>
      _repo.createRating(eventId,
          direction: direction,
          ratedUserId: ratedUserId,
          stars: stars,
          description: description);

  Future<RatingsSummary> getEventRatingsSummary(int eventId) =>
      _repo.getEventRatingsSummary(eventId);

  Future<List<Rating>> getEventRatings(int eventId,
          {String? direction}) =>
      _repo.getEventRatings(eventId, direction: direction);

  // -- Registration --

  Future<Registration> register(int eventId) =>
      _repo.register(eventId);

  Future<UnregisterResult> unregister(int eventId) =>
      _repo.unregister(eventId);

  Future<Registration?> getMyRegistration(int eventId) =>
      _repo.getMyRegistration(eventId);

  Future<List<Registration>> getRegistrations(int eventId) =>
      _repo.getRegistrations(eventId);

  Future<Registration> decideRegistration(
          int eventId, int registrationId, String action) =>
      _repo.decideRegistration(eventId, registrationId, action);

  Future<CapacityInfo> getCapacityInfo(int eventId) =>
      _repo.getCapacityInfo(eventId);

  // -- Extension --

  Future<Event> extendFunding(
          int eventId, ExtendFundingInput data) =>
      _repo.extendFunding(eventId, data);

  Future<Event> setEventDate(
          int eventId, SetEventDateInput data) =>
      _repo.setEventDate(eventId, data);

  Future<Event> decideExtension(
          int eventId, String action) =>
      _repo.decideExtension(eventId, action);

  // -- Cities --

  Future<List<String>> getEventCities() => _repo.getEventCities();

  // -- Organizer Dashboard --

  Future<OrganizerDashboard> getOrganizerDashboard(
          {String? status, int? eventId, String? genre, String? period}) =>
      _repo.getOrganizerDashboard(
          status: status, eventId: eventId, genre: genre, period: period);

  Future<OrganizerTimeSeries> getOrganizerTimeSeries(
          {int days = 30, String? status, int? eventId, String? genre}) =>
      _repo.getOrganizerTimeSeries(
          days: days, status: status, eventId: eventId, genre: genre);

  Future<List<CustomerHistoryItem>> getOrganizerCustomers(
          {int offset = 0, int limit = 20}) =>
      _repo.getOrganizerCustomers(offset: offset, limit: limit);

  // -- Public Config --

  Future<PublicConfig> getPublicConfig() => _repo.getPublicConfig();

  // -- Calendar --

  String calendarUrl(int eventId) => _repo.calendarUrl(eventId);
}

class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  _CacheEntry(this.data, this.timestamp);
}
