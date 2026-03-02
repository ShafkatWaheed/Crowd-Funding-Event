import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../lib/providers/notification_provider.dart';
import '../../lib/repositories/notification_repository.dart';

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNotificationRepository mockRepo;
  late NotificationProvider provider;

  setUp(() {
    mockRepo = MockNotificationRepository();
    provider = NotificationProvider(mockRepo);
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
      when(() => mockRepo.getNotifications(
            unreadOnly: any(named: 'unreadOnly'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
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
          ]);

      await provider.loadNotifications();

      expect(provider.notifications.length, 2);
      expect(provider.isLoading, false);
    });

    test('loadNotifications with offset appends', () async {
      // First load
      when(() => mockRepo.getNotifications(
            unreadOnly: any(named: 'unreadOnly'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            {'id': 1, 'type': 'test', 'title': 'N1', 'message': 'msg', 'is_read': false},
          ]);
      await provider.loadNotifications();
      expect(provider.notifications.length, 1);

      // Load more with offset
      when(() => mockRepo.getNotifications(
            unreadOnly: any(named: 'unreadOnly'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            {'id': 2, 'type': 'test', 'title': 'N2', 'message': 'msg', 'is_read': false},
          ]);
      await provider.loadNotifications(offset: 1);

      expect(provider.notifications.length, 2);
    });

    test('markRead updates local state', () async {
      // Setup with one notification
      when(() => mockRepo.getNotifications(
            unreadOnly: any(named: 'unreadOnly'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            {'id': 1, 'type': 'test', 'title': 'N1', 'message': 'msg', 'is_read': false},
          ]);
      await provider.loadNotifications();

      when(() => mockRepo.markRead(1)).thenAnswer((_) async {});
      when(() => mockRepo.getUnreadCount()).thenAnswer((_) async => 1);

      await provider.markRead(1);

      expect(provider.notifications[0]['is_read'], true);
    });

    test('markAllRead clears all unread', () async {
      when(() => mockRepo.getNotifications(
            unreadOnly: any(named: 'unreadOnly'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            {'id': 1, 'type': 'test', 'title': 'N1', 'message': 'msg', 'is_read': false},
            {'id': 2, 'type': 'test', 'title': 'N2', 'message': 'msg', 'is_read': false},
          ]);
      await provider.loadNotifications();

      when(() => mockRepo.markAllRead()).thenAnswer((_) async {});

      await provider.markAllRead();

      expect(provider.unreadCount, 0);
      expect(provider.notifications.every((n) => n['is_read'] == true), true);
    });

    test('deleteNotification removes from list', () async {
      when(() => mockRepo.getNotifications(
            unreadOnly: any(named: 'unreadOnly'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            {'id': 1, 'type': 'test', 'title': 'N1', 'message': 'msg', 'is_read': false},
            {'id': 2, 'type': 'test', 'title': 'N2', 'message': 'msg', 'is_read': true},
          ]);
      await provider.loadNotifications();

      when(() => mockRepo.deleteNotification(1)).thenAnswer((_) async {});

      await provider.deleteNotification(1);

      expect(provider.notifications.length, 1);
      expect(provider.notifications[0]['id'], 2);
    });

    test('deleteNotification decrements unread count for unread item', () async {
      when(() => mockRepo.getNotifications(
            unreadOnly: any(named: 'unreadOnly'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            {'id': 1, 'type': 'test', 'title': 'N1', 'message': 'msg', 'is_read': false},
          ]);
      await provider.loadNotifications();

      when(() => mockRepo.deleteNotification(1)).thenAnswer((_) async {});

      await provider.deleteNotification(1);

      expect(provider.unreadCount, 0);
    });

    test('startPolling and stopPolling lifecycle', () {
      when(() => mockRepo.getUnreadCount())
          .thenAnswer((_) async => 3);

      provider.startPolling();
      provider.stopPolling();
    });

    test('loadNotifications error does not throw', () async {
      when(() => mockRepo.getNotifications(
            unreadOnly: any(named: 'unreadOnly'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenThrow(Exception('Network error'));

      await provider.loadNotifications();

      expect(provider.isLoading, false);
    });
  });
}
