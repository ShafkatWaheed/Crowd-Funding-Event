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

  EventProvider(this._api);

  List<Event> get events => _events;
  Event? get selectedEvent => _selectedEvent;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadEvents({Map<String, dynamic>? filters}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.getEvents(params: filters);
      _events = data.map((e) => Event.fromJson(e)).toList();
    } catch (e) {
      _error = 'Failed to load events.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadEvent(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.getEvent(id);
      _selectedEvent = Event.fromJson(data);
    } catch (e) {
      _error = 'Failed to load event details.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createEvent(Map<String, dynamic> data) async {
    try {
      await _api.createEvent(data);
      await loadEvents();
      return true;
    } catch (e) {
      _error = 'Failed to create event.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> publishEvent(int id) async {
    try {
      await _api.publishEvent(id);
      await loadEvent(id);
      return true;
    } catch (e) {
      _error = 'Failed to publish event.';
      notifyListeners();
      return false;
    }
  }

  /// Cancel or request cancellation.
  /// Returns a message string on success / pending-request, or null on failure.
  Future<String?> cancelEvent(int id, {required String reason}) async {
    try {
      await _api.cancelEvent(id, reason: reason);
      await loadEvent(id);
      return 'Event cancelled successfully.';
    } on DioException catch (e) {
      final detail = e.response?.data;
      final msg = (detail is Map ? detail['detail'] : null) as String?;
      // 409 with "sent to admin" means the request was registered, not a real error
      if (e.response?.statusCode == 409 && msg != null && msg.contains('admin')) {
        await loadEvent(id);
        return msg;
      }
      _error = msg ?? 'Failed to cancel event.';
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Failed to cancel event.';
      notifyListeners();
      return null;
    }
  }

  Future<bool> reactivateEvent(int id) async {
    try {
      await _api.reactivateEvent(id);
      await loadEvent(id);
      return true;
    } catch (e) {
      _error = 'Failed to reactivate event.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> startSellingTickets(int id) async {
    try {
      await _api.startSellingTickets(id);
      await loadEvent(id);
      return true;
    } catch (e) {
      _error = 'Failed to start selling tickets.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteEvent(int id) async {
    try {
      await _api.deleteEvent(id);
      _selectedEvent = null;
      await loadEvents();
      return true;
    } catch (e) {
      _error = 'Failed to delete event.';
      notifyListeners();
      return false;
    }
  }

  void clearSelected() {
    _selectedEvent = null;
    notifyListeners();
  }
}
