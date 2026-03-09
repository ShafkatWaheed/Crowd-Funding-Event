import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:crowd_funding_app/models/notification_model.dart';
import 'package:crowd_funding_app/providers/notification_provider.dart';
import 'package:crowd_funding_app/screens/notification/notification_screen.dart';
import '../helpers/mock_providers.dart';
import '../helpers/pump_app.dart';

AppNotification _makeNotif({
  required int id,
  String type = 'test',
  String title = 'Test',
  String message = 'msg',
  bool isRead = false,
  DateTime? createdAt,
  NotificationPayload data = const NotificationPayload(),
}) =>
    AppNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      isRead: isRead,
      createdAt: createdAt ?? DateTime.now(),
      data: data,
    );

void main() {
  late MockNotificationProvider mockNotification;

  setUp(() {
    mockNotification = MockNotificationProvider();
  });

  /// Pump NotificationScreen with the mock notification provider.
  Future<void> pumpNotifications(
    WidgetTester tester, {
    List<AppNotification> notifications = const [],
    bool isLoading = false,
  }) async {
    when(() => mockNotification.notifications).thenReturn(notifications);
    when(() => mockNotification.isLoading).thenReturn(isLoading);
    when(() => mockNotification.unreadCount).thenReturn(
        notifications.where((n) => !n.isRead).length);
    when(() => mockNotification.loadNotifications(
          unreadOnly: any(named: 'unreadOnly'),
          offset: any(named: 'offset'),
        )).thenAnswer((_) async {});
    when(() => mockNotification.markAllRead()).thenAnswer((_) async {});
    when(() => mockNotification.markRead(any())).thenAnswer((_) async {});

    await pumpApp(
      tester,
      const NotificationScreen(),
      overrides: [
        ChangeNotifierProvider<NotificationProvider>.value(
            value: mockNotification),
      ],
    );
  }

  group('NotificationScreen', () {
    testWidgets('renders notification list with items', (tester) async {
      await pumpNotifications(tester, notifications: [
        _makeNotif(
          id: 1,
          type: 'ticket_purchased',
          title: 'Ticket Purchased',
          message: 'You bought a ticket for Music Fest',
          isRead: false,
        ),
        _makeNotif(
          id: 2,
          type: 'pledge_confirmed',
          title: 'Pledge Confirmed',
          message: 'Your pledge of \$20 was confirmed',
          isRead: true,
        ),
      ]);
      await tester.pump();

      // AppBar title
      expect(find.text('Notifications'), findsOneWidget);
      // Notification titles rendered in cards
      expect(find.text('Ticket Purchased'), findsOneWidget);
      expect(find.text('Pledge Confirmed'), findsOneWidget);
    });

    testWidgets('mark all read button exists in app bar', (tester) async {
      await pumpNotifications(tester, notifications: [
        _makeNotif(
          id: 1,
          type: 'ticket_purchased',
          title: 'Test',
          message: 'Test message',
          isRead: false,
        ),
      ]);
      await tester.pump();

      // Mark all read button in app bar actions
      expect(find.text('Mark all read'), findsOneWidget);

      // Tap it and verify the provider method was called
      await tester.tap(find.text('Mark all read'));
      await tester.pump();
      verify(() => mockNotification.markAllRead()).called(1);
    });

    testWidgets('mark all read button triggers provider call', (tester) async {
      await pumpNotifications(tester, notifications: [
        _makeNotif(
          id: 1,
          type: 'pledge_confirmed',
          title: 'Pledge',
          message: 'Pledge confirmed',
          isRead: false,
        ),
      ]);
      await tester.pump();

      await tester.tap(find.text('Mark all read'));
      await tester.pump();

      verify(() => mockNotification.markAllRead()).called(1);
    });

    testWidgets('empty state shown when no notifications', (tester) async {
      await pumpNotifications(tester, notifications: []);
      await tester.pump();

      // Empty state text from the screen
      expect(find.text("You're all caught up!"), findsOneWidget);
      expect(find.text('No notifications to show'), findsOneWidget);
      // Empty state icon
      expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
    });

    testWidgets('notification item shows title and message', (tester) async {
      await pumpNotifications(tester, notifications: [
        _makeNotif(
          id: 10,
          type: 'event_approved',
          title: 'Event Approved!',
          message: 'Your event "Music Fest" has been approved',
          isRead: false,
          data: NotificationPayload(type: 'event_approved', eventId: 5),
        ),
      ]);
      await tester.pump();

      expect(find.text('Event Approved!'), findsOneWidget);
      expect(
          find.text('Your event "Music Fest" has been approved'), findsOneWidget);
    });
  });
}
