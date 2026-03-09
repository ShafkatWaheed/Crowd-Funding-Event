import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:crowd_funding_app/models/notification_model.dart';
import 'package:crowd_funding_app/providers/notification_provider.dart';
import 'package:crowd_funding_app/repositories/notification_repository.dart';

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

AppNotification _makeNotification({
  required int id,
  String type = 'test',
  String title = 'Test',
  String message = 'msg',
  bool isRead = false,
  String createdAt = '2025-01-01T00:00:00',
}) =>
    AppNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      isRead: isRead,
      createdAt: DateTime.parse(createdAt),
    );

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
            _makeNotification(id: 1, type: 'pledge_confirmed', title: 'Pledge Confirmed', message: 'Your pledge was confirmed.'),
            _makeNotification(id: 2, type: 'event_approved', title: 'Event Approved', message: 'Your event was approved.', isRead: true),
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
            _makeNotification(id: 1),
          ]);
      await provider.loadNotifications();
      expect(provider.notifications.length, 1);

      // Load more with offset
      when(() => mockRepo.getNotifications(
            unreadOnly: any(named: 'unreadOnly'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            _makeNotification(id: 2),
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
            _makeNotification(id: 1, isRead: false),
          ]);
      await provider.loadNotifications();

      when(() => mockRepo.markRead(1)).thenAnswer((_) async {});
      when(() => mockRepo.getUnreadCount()).thenAnswer((_) async => 1);

      await provider.markRead(1);

      expect(provider.notifications[0].isRead, true);
    });

    test('markAllRead clears all unread', () async {
      when(() => mockRepo.getNotifications(
            unreadOnly: any(named: 'unreadOnly'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            _makeNotification(id: 1, isRead: false),
            _makeNotification(id: 2, isRead: false),
          ]);
      await provider.loadNotifications();

      when(() => mockRepo.markAllRead()).thenAnswer((_) async {});

      await provider.markAllRead();

      expect(provider.unreadCount, 0);
      expect(provider.notifications.every((n) => n.isRead), true);
    });

    test('deleteNotification removes from list', () async {
      when(() => mockRepo.getNotifications(
            unreadOnly: any(named: 'unreadOnly'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            _makeNotification(id: 1, isRead: false),
            _makeNotification(id: 2, isRead: true),
          ]);
      await provider.loadNotifications();

      when(() => mockRepo.deleteNotification(1)).thenAnswer((_) async {});

      await provider.deleteNotification(1);

      expect(provider.notifications.length, 1);
      expect(provider.notifications[0].id, 2);
    });

    test('deleteNotification decrements unread count for unread item', () async {
      when(() => mockRepo.getNotifications(
            unreadOnly: any(named: 'unreadOnly'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            _makeNotification(id: 1, isRead: false),
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
