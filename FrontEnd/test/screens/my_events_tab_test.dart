import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/user.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/services/api_service.dart';
import '../../lib/screens/home/tabs/my_events_tab.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockApiService mockApi;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockApi = MockApiService();

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
        Provider<ApiService>.value(value: mockApi),
      ],
    );
  }

  group('MyEventsTab', () {
    testWidgets('shows Manage header and quick action buttons', (tester) async {
      final eventsCompleter = Completer<List<dynamic>>();
      when(() => mockApi.getMyEvents(
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
      when(() => mockApi.getMyEvents(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) async => []);

      await pumpMyEventsTab(tester);
      await tester.pumpAndSettle();

      expect(find.text('No events yet'), findsOneWidget);
    });

    testWidgets('shows sort chips (Newest, Oldest, etc.)', (tester) async {
      when(() => mockApi.getMyEvents(
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
