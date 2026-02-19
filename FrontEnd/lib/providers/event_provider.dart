import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/api_service.dart';

class EventProvider extends ChangeNotifier {
  final ApiService _api;

  List<Event> _events = [];
  Event? _selectedEvent;
  bool _isLoading = false;
  String? _error;

  // Pagination state
  static const int _pageSize = 20;
  int _currentOffset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  Map<String, dynamic>? _lastFilters;

  // In-memory cache: event id → (Event, timestamp)
  final Map<int, _CacheEntry<Event>> _eventCache = {};
  static const Duration _cacheTtl = Duration(seconds: 60);

  EventProvider(this._api);

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
    _currentOffset = 0;
    _hasMore = true;
    _lastFilters = filters;
    notifyListeners();

    try {
      final data = await _api.getEvents(params: filters, offset: 0, limit: _pageSize);
      _events = data.map((e) => Event.fromJson(e)).toList();
      _hasMore = data.length >= _pageSize;
      _currentOffset = _events.length;
    } catch (e) {
      _error = ApiService.extractError(e, fallback: 'Failed to load events.');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreEvents() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final data = await _api.getEvents(
        params: _lastFilters,
        offset: _currentOffset,
        limit: _pageSize,
      );
      final newEvents = data.map((e) => Event.fromJson(e)).toList();
      _events.addAll(newEvents);
      _hasMore = newEvents.length >= _pageSize;
      _currentOffset += newEvents.length;
    } catch (e) {
      _error = ApiService.extractError(e, fallback: 'Failed to load more events.');
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
      final data = await _api.getEvent(id);
      _selectedEvent = Event.fromJson(data);
      _eventCache[id] = _CacheEntry(_selectedEvent!, DateTime.now());
    } catch (e) {
      _error = ApiService.extractError(e, fallback: 'Failed to load event details.');
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
      await _api.createEvent(data);
      await loadEvents();
      return true;
    } catch (e) {
      _error = ApiService.extractError(e, fallback: 'Failed to create event.');
      notifyListeners();
      return false;
    }
  }

  Future<bool> publishEvent(int id) async {
    try {
      await _api.publishEvent(id);
      invalidateCache(id);
      await loadEvent(id, forceRefresh: true);
      return true;
    } catch (e) {
      _error = ApiService.extractError(e, fallback: 'Failed to publish event.');
      notifyListeners();
      return false;
    }
  }

  Future<String?> cancelEvent(int id, {required String reason}) async {
    try {
      await _api.cancelEvent(id, reason: reason);
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
      _error = msg ?? ApiService.extractError(e, fallback: 'Failed to cancel event.');
      notifyListeners();
      return null;
    } catch (e) {
      _error = ApiService.extractError(e, fallback: 'Failed to cancel event.');
      notifyListeners();
      return null;
    }
  }

  Future<bool> reactivateEvent(int id) async {
    try {
      await _api.reactivateEvent(id);
      invalidateCache(id);
      await loadEvent(id, forceRefresh: true);
      return true;
    } catch (e) {
      _error = ApiService.extractError(e, fallback: 'Failed to reactivate event.');
      notifyListeners();
      return false;
    }
  }

  Future<bool> startSellingTickets(int id) async {
    try {
      await _api.startSellingTickets(id);
      invalidateCache(id);
      await loadEvent(id, forceRefresh: true);
      return true;
    } catch (e) {
      _error = ApiService.extractError(e, fallback: 'Failed to start selling tickets.');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteEvent(int id) async {
    try {
      await _api.deleteEvent(id);
      _selectedEvent = null;
      invalidateCache(id);
      await loadEvents();
      return true;
    } catch (e) {
      _error = ApiService.extractError(e, fallback: 'Failed to delete event.');
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
