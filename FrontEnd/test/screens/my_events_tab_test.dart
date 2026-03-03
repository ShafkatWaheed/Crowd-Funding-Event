import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/event.dart';
import '../../lib/models/user.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/providers/event_provider.dart';
import '../../lib/repositories/event_repository.dart';
import '../../lib/screens/home/tabs/my_events_tab.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_event_repository.dart';
import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockEventRepository mockEventRepo;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockEventRepo = MockEventRepository();

    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.organizer));
  });

  Future<void> pumpMyEventsTab(
    WidgetTester tester, {
    Set<int> bookmarkedIds = const {},
  }) async {
    // MyEventsTab is a tab widget (Column), not a Scaffold.
    // Wrap in Scaffold to provide Material ancestor for TextField.
    await pumpApp(
      tester,
      Scaffold(
        body: MyEventsTab(
          bookmarkedIds: bookmarkedIds,
          onToggleBookmark: (_) {},
          genres: const ['music', 'tech'],
        ),
      ),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<EventProvider>.value(value: EventProvider(mockEventRepo)),
      ],
    );
  }

  group('MyEventsTab', () {
    testWidgets('shows Manage header and quick action buttons', (tester) async {
      final eventsCompleter = Completer<List<Event>>();
      when(() => mockEventRepo.getMyEvents(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) => eventsCompleter.future);

      await pumpMyEventsTab(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Manage'), findsOneWidget);
      expect(find.text('My Tickets'), findsOneWidget);
      expect(find.text('My Pledges'), findsOneWidget);

      eventsCompleter.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('shows empty state when no events', (tester) async {
      when(() => mockEventRepo.getMyEvents(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) async => []);

      await pumpMyEventsTab(tester);
      await tester.pumpAndSettle();

      expect(find.text('No events yet'), findsOneWidget);
    });

    testWidgets('shows sort chips (Newest, Oldest, etc.)', (tester) async {
      when(() => mockEventRepo.getMyEvents(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) async => []);

      await pumpMyEventsTab(tester);
      await tester.pumpAndSettle();

      expect(find.text('Newest'), findsOneWidget);
      expect(find.text('Oldest'), findsOneWidget);
      expect(find.text('Name A-Z'), findsOneWidget);
    });
  });
}
