import 'base_repository.dart';

class NotificationRepository extends BaseRepository {
  NotificationRepository(super.dio);

  Future<int> getUnreadCount() async {
    final resp = await dio.get('/me/notifications/unread-count');
    return resp.data['unread_count'] ?? 0;
  }

  Future<List<dynamic>> getNotifications({bool unreadOnly = false, int offset = 0, int limit = 20}) async {
    final resp = await dio.get('/me/notifications', queryParameters: {
      if (unreadOnly) 'unread_only': true,
      'offset': offset,
      'limit': limit,
    });
    return resp.data as List<dynamic>;
  }

  Future<void> markRead(int notificationId) async {
    await dio.patch('/me/notifications/$notificationId/read');
  }

  Future<void> markAllRead() async {
    await dio.patch('/me/notifications/read-all');
  }

  Future<void> deleteNotification(int notificationId) async {
    await dio.delete('/me/notifications/$notificationId');
  }

  Future<void> registerDeviceToken(String token, String platform) async {
    await dio.post('/me/device-tokens', data: {'token': token, 'platform': platform});
  }

  Future<void> unregisterDeviceToken(String token) async {
    await dio.delete('/me/device-tokens/$token');
  }
}
