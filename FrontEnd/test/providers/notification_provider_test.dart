import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../lib/providers/notification_provider.dart';
import '../helpers/mock_api_service.dart';

/// Fake Response for Dio mocking.
class _FakeResponse extends Fake implements Response<dynamic> {
  @override
  final dynamic data;
  @override
  final int statusCode;
  _FakeResponse(this.data, {this.statusCode = 200});
}

class _FakeRequestOptions extends Fake implements RequestOptions {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiService mockApi;
  late NotificationProvider provider;

  setUpAll(() {
    registerFallbackValue(_FakeRequestOptions());
  });

  setUp(() {
    mockApi = MockApiService();
    provider = NotificationProvider(mockApi);
  });

  tearDown(() {
    provider.dispose();
  });

  group('NotificationProvider', () {
    test('initial state', () {
      expect(provider.unreadCount, 0);
      expect(provider.notifications, isEmpty);
      expect(provider.isLoading, false);
      expect(provider.fcmToken, isNull);
    });

    test('loadNotifications success', () async {
      when(() => mockApi.dio.get(
            '/me/notifications',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => _FakeResponse([
            {
              'id': 1,
              'type': 'pledge_confirmed',
              'title': 'Pledge Confirmed',
              'message': 'Your pledge was confirmed.',
              'is_read': false,
            },
            {
              'id': 2,
              'type': 'event_approved',
              'title': 'Event Approved',
              'message': 'Your event was approved.',
              'is_read': true,
            },
          ]));

      await provider.loadNotifications();

      expect(provider.notifications.length, 2);
      expect(provider.isLoading, false);
    });

    test('loadNotifications with offset appends', () async {
      // First load
      when(() => mockApi.dio.get(
            '/me/notifications',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => _FakeResponse([
            {'id': 1, 'type': 'test', 'title': 'N1', 'message': 'msg', 'is_read': false},
          ]));
      await provider.loadNotifications();
      expect(provider.notifications.length, 1);

      // Load more with offset
      when(() => mockApi.dio.get(
            '/me/notifications',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => _FakeResponse([
            {'id': 2, 'type': 'test', 'title': 'N2', 'message': 'msg', 'is_read': false},
          ]));
      await provider.loadNotifications(offset: 1);

      expect(provider.notifications.length, 2);
    });

    test('markRead updates local state', () async {
      // Setup with one notification
      when(() => mockApi.dio.get(
            '/me/notifications',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => _FakeResponse([
            {'id': 1, 'type': 'test', 'title': 'N1', 'message': 'msg', 'is_read': false},
          ]));
      await provider.loadNotifications();

      when(() => mockApi.dio.patch('/me/notifications/1/read'))
          .thenAnswer((_) async => _FakeResponse({'success': true}));

      // Set initial unread count
      when(() => mockApi.dio.get('/me/notifications/unread-count'))
          .thenAnswer((_) async => _FakeResponse({'unread_count': 1}));

      await provider.markRead(1);

      expect(provider.notifications[0]['is_read'], true);
    });

    test('markAllRead clears all unread', () async {
      when(() => mockApi.dio.get(
            '/me/notifications',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => _FakeResponse([
            {'id': 1, 'type': 'test', 'title': 'N1', 'message': 'msg', 'is_read': false},
            {'id': 2, 'type': 'test', 'title': 'N2', 'message': 'msg', 'is_read': false},
          ]));
      await provider.loadNotifications();

      when(() => mockApi.dio.patch('/me/notifications/read-all'))
          .thenAnswer((_) async => _FakeResponse({'marked_read': 2}));

      await provider.markAllRead();

      expect(provider.unreadCount, 0);
      expect(provider.notifications.every((n) => n['is_read'] == true), true);
    });

    test('deleteNotification removes from list', () async {
      when(() => mockApi.dio.get(
            '/me/notifications',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => _FakeResponse([
            {'id': 1, 'type': 'test', 'title': 'N1', 'message': 'msg', 'is_read': false},
            {'id': 2, 'type': 'test', 'title': 'N2', 'message': 'msg', 'is_read': true},
          ]));
      await provider.loadNotifications();

      when(() => mockApi.dio.delete('/me/notifications/1'))
          .thenAnswer((_) async => _FakeResponse(null, statusCode: 204));

      await provider.deleteNotification(1);

      expect(provider.notifications.length, 1);
      expect(provider.notifications[0]['id'], 2);
    });

    test('deleteNotification decrements unread count for unread item', () async {
      when(() => mockApi.dio.get(
            '/me/notifications',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => _FakeResponse([
            {'id': 1, 'type': 'test', 'title': 'N1', 'message': 'msg', 'is_read': false},
          ]));
      await provider.loadNotifications();

      when(() => mockApi.dio.delete('/me/notifications/1'))
          .thenAnswer((_) async => _FakeResponse(null, statusCode: 204));

      await provider.deleteNotification(1);

      // unreadCount should not go negative
      expect(provider.unreadCount, 0);
    });

    test('startPolling and stopPolling lifecycle', () {
      when(() => mockApi.dio.get('/me/notifications/unread-count'))
          .thenAnswer((_) async => _FakeResponse({'unread_count': 3}));

      provider.startPolling();
      provider.stopPolling(); // Should not throw
    });

    test('loadNotifications error does not throw', () async {
      when(() => mockApi.dio.get(
            '/me/notifications',
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(Exception('Network error'));

      await provider.loadNotifications();

      expect(provider.isLoading, false);
      // Should gracefully handle error
    });
  });
}
