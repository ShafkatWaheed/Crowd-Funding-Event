import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/event.dart';
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
  Map<String, dynamic>? _lastFilters;

  // In-memory cache: event id → (Event, timestamp)
  final Map<int, _CacheEntry<Event>> _eventCache = {};
  static const Duration _cacheTtl = Duration(seconds: 60);

  EventProvider(this._repo);

  List<Event> get events => _events;
  Event? get selectedEvent => _selectedEvent;
  Event? get event => _selectedEvent;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  Future<void> loadEvents({Map<String, dynamic>? filters}) async {
    _isLoading = true;
    _error = null;
    _nextCursor = null;
    _hasMore = true;
    _lastFilters = filters;
    notifyListeners();

    try {
      final result = await _repo.getEvents(params: filters, limit: _pageSize);
      final items = (result['items'] as List?) ?? [];
      _events = items.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
      _nextCursor = result['next_cursor'] as String?;
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
        params: _lastFilters,
        limit: _pageSize,
        cursor: _nextCursor,
      );
      final items = (result['items'] as List?) ?? [];
      final newEvents = items.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
      _events.addAll(newEvents);
      _nextCursor = result['next_cursor'] as String?;
      _hasMore = _nextCursor != null;
    } catch (e) {
      _error = ApiError.extractMessage(e, fallback: 'Failed to load more events.');
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> loadEvent(int id, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
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
      final data = await _repo.getEvent(id);
      _selectedEvent = Event.fromJson(data);
      _eventCache[id] = _CacheEntry(_selectedEvent!, DateTime.now());
    } catch (e) {
      _error = ApiError.extractMessage(e, fallback: 'Failed to load event details.');
    }

    _isLoading = false;
    notifyListeners();
  }

  void invalidateCache(int id) {
    _eventCache.remove(id);
  }

  void clearCache() {
    _eventCache.clear();
  }

  Future<bool> createEvent(Map<String, dynamic> data) async {
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
}

class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  _CacheEntry(this.data, this.timestamp);
}
