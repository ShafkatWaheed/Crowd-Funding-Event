import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _repo;
  int _unreadCount = 0;
  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  Timer? _pollTimer;
  String? _fcmToken;
  StreamSubscription? _tokenRefreshSub;
  bool _notifyScheduled = false;

  NotificationProvider(this._repo);

  // ignore: unused_element
  /// Build-phase-safe notification. Defers if framework is currently building.
  void _safeNotify() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      if (_notifyScheduled) return;
      _notifyScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        super.notifyListeners();
      });
    } else {
      super.notifyListeners();
    }
  }

  int get unreadCount => _unreadCount;
  List<AppNotification> get notifications => _notifications;
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
      final count = await _repo.getUnreadCount();
      if (count != _unreadCount) {
        _unreadCount = count;
        _safeNotify();
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> loadNotifications({bool unreadOnly = false, int offset = 0}) async {
    _isLoading = true;
    _safeNotify();
    try {
      final data = await _repo.getNotifications(unreadOnly: unreadOnly, offset: offset);
      if (offset == 0) {
        _notifications = data;
      } else {
        _notifications.addAll(data);
      }
    } catch (e) { debugPrint(e.toString()); }
    _isLoading = false;
    _safeNotify();
  }

  Future<void> markRead(int notificationId) async {
    try {
      await _repo.markRead(notificationId);
      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx >= 0) {
        _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      }
      _unreadCount = (_unreadCount - 1).clamp(0, 999);
      _safeNotify();
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> markAllRead() async {
    try {
      await _repo.markAllRead();
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _unreadCount = 0;
      _safeNotify();
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> deleteNotification(int notificationId) async {
    try {
      await _repo.deleteNotification(notificationId);
      final wasUnread = _notifications.any(
          (n) => n.id == notificationId && !n.isRead);
      _notifications.removeWhere((n) => n.id == notificationId);
      if (wasUnread) _unreadCount = (_unreadCount - 1).clamp(0, 999);
      _safeNotify();
    } catch (e) { debugPrint(e.toString()); }
  }

  String? get fcmToken => _fcmToken;

  Future<void> initFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Push notification permission denied');
        return;
      }

      String? token;
      if (kIsWeb) {
        token = await messaging.getToken(vapidKey: null);
      } else {
        token = await messaging.getToken();
      }

      if (token != null) {
        _fcmToken = token;
        await _registerToken(token);
      }

      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        await _registerToken(newToken);
      });
    } catch (e) {
      debugPrint('FCM init failed: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    // Wait for Firebase Auth to be ready so the Dio interceptor can attach the ID token.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.getIdToken();
    } catch (_) {
      return;
    }
    final platform = kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
    try {
      await _repo.registerDeviceToken(token, platform);
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> unregisterDevice() async {
    if (_fcmToken != null) {
      try {
        await _repo.unregisterDeviceToken(_fcmToken!);
      } catch (e) { debugPrint(e.toString()); }
      _fcmToken = null;
    }
  }

  @override
  void dispose() {
    stopPolling();
    _tokenRefreshSub?.cancel();
    super.dispose();
  }
}
