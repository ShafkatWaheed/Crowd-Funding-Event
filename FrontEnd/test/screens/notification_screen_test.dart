import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/providers/notification_provider.dart';
import '../../lib/screens/notification/notification_screen.dart';
import '../helpers/mock_providers.dart';
import '../helpers/pump_app.dart';

void main() {
  late MockNotificationProvider mockNotification;

  setUp(() {
    mockNotification = MockNotificationProvider();
  });

  /// Pump NotificationScreen with the mock notification provider.
  Future<void> pumpNotifications(
    WidgetTester tester, {
    List<Map<String, dynamic>> notifications = const [],
    bool isLoading = false,
  }) async {
    when(() => mockNotification.notifications).thenReturn(notifications);
    when(() => mockNotification.isLoading).thenReturn(isLoading);
    when(() => mockNotification.unreadCount).thenReturn(
        notifications.where((n) => n['is_read'] != true).length);
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
      final now = DateTime.now().toIso8601String();
      await pumpNotifications(tester, notifications: [
        {
          'id': 1,
          'type': 'ticket_purchased',
          'title': 'Ticket Purchased',
          'message': 'You bought a ticket for Music Fest',
          'is_read': false,
          'created_at': now,
          'data': '{}',
        },
        {
          'id': 2,
          'type': 'pledge_confirmed',
          'title': 'Pledge Confirmed',
          'message': 'Your pledge of \$20 was confirmed',
          'is_read': true,
          'created_at': now,
          'data': '{}',
        },
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
        {
          'id': 1,
          'type': 'ticket_purchased',
          'title': 'Test',
          'message': 'Test message',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
          'data': '{}',
        },
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
        {
          'id': 1,
          'type': 'pledge_confirmed',
          'title': 'Pledge',
          'message': 'Pledge confirmed',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
          'data': '{}',
        },
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
      final now = DateTime.now().toIso8601String();
      await pumpNotifications(tester, notifications: [
        {
          'id': 10,
          'type': 'event_approved',
          'title': 'Event Approved!',
          'message': 'Your event "Music Fest" has been approved',
          'is_read': false,
          'created_at': now,
          'data': '{"event_id": 5}',
        },
      ]);
      await tester.pump();

      expect(find.text('Event Approved!'), findsOneWidget);
      expect(
          find.text('Your event "Music Fest" has been approved'), findsOneWidget);
    });
  });
}
