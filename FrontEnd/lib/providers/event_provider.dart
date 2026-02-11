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

  Future<bool> submitEvent(int id) async {
    try {
      await _api.submitEvent(id);
      await loadEvent(id);
      return true;
    } catch (e) {
      _error = 'Failed to submit event.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelEvent(int id) async {
    try {
      await _api.cancelEvent(id);
      await loadEvent(id);
      return true;
    } catch (e) {
      _error = 'Failed to cancel event.';
      notifyListeners();
      return false;
    }
  }

  void clearSelected() {
    _selectedEvent = null;
    notifyListeners();
  }
}
