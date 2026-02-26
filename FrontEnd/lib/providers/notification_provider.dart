import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiService _api;
  int _unreadCount = 0;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  Timer? _pollTimer;

  NotificationProvider(this._api);

  int get unreadCount => _unreadCount;
  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;

  void startPolling() {
    _pollTimer?.cancel();
    _fetchUnreadCount();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchUnreadCount());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final resp = await _api.dio.get('/me/notifications/unread-count');
      final count = resp.data['unread_count'] ?? 0;
      if (count != _unreadCount) {
        _unreadCount = count;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> loadNotifications({bool unreadOnly = false, int offset = 0}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final resp = await _api.dio.get('/me/notifications', queryParameters: {
        'unread_only': unreadOnly,
        'offset': offset,
        'limit': 20,
      });
      if (offset == 0) {
        _notifications = List<Map<String, dynamic>>.from(resp.data);
      } else {
        _notifications.addAll(List<Map<String, dynamic>>.from(resp.data));
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> markRead(int notificationId) async {
    try {
      await _api.dio.patch('/me/notifications/$notificationId/read');
      final idx = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (idx >= 0) {
        _notifications[idx]['is_read'] = true;
      }
      _unreadCount = (_unreadCount - 1).clamp(0, 999);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _api.dio.patch('/me/notifications/read-all');
      for (final n in _notifications) {
        n['is_read'] = true;
      }
      _unreadCount = 0;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> deleteNotification(int notificationId) async {
    try {
      await _api.dio.delete('/me/notifications/$notificationId');
      final wasUnread = _notifications.any(
          (n) => n['id'] == notificationId && n['is_read'] != true);
      _notifications.removeWhere((n) => n['id'] == notificationId);
      if (wasUnread) _unreadCount = (_unreadCount - 1).clamp(0, 999);
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
