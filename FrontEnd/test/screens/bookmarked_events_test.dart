import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/providers/auth_provider.dart';
import '../../lib/services/api_service.dart';
import '../../lib/screens/bookmark/bookmarked_events_screen.dart';
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

    when(() => mockAuth.user).thenReturn(makeUser());
  });

  Future<void> pumpBookmarks(WidgetTester tester) async {
    await pumpApp(
      tester,
      const BookmarkedEventsScreen(),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        Provider<ApiService>.value(value: mockApi),
      ],
    );
  }

  group('BookmarkedEventsScreen', () {
    testWidgets('renders bookmarked events list after load', (tester) async {
      when(() => mockApi.getBookmarkedEvents(
            search: any(named: 'search'),
            status: any(named: 'status'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            eventJson(id: 1, title: 'Music Fest', status: 'approved'),
            eventJson(id: 2, title: 'Tech Conf', status: 'selling_tickets'),
          ]);

      await pumpBookmarks(tester);
      await tester.pumpAndSettle();

      // AppBar title
      expect(find.text('Bookmarks'), findsOneWidget);
      // Event titles in the bookmark cards
      expect(find.text('Music Fest'), findsOneWidget);
      expect(find.text('Tech Conf'), findsOneWidget);
    });

    testWidgets('empty state when no bookmarks', (tester) async {
      when(() => mockApi.getBookmarkedEvents(
            search: any(named: 'search'),
            status: any(named: 'status'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => []);

      await pumpBookmarks(tester);
      await tester.pumpAndSettle();

      // Empty state messages from the screen
      expect(find.text('No bookmarked events'), findsOneWidget);
      expect(find.text('Bookmark events from cards or event details.'),
          findsOneWidget);
      // Empty state icon
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    });

    testWidgets('search field and filter chips present', (tester) async {
      when(() => mockApi.getBookmarkedEvents(
            search: any(named: 'search'),
            status: any(named: 'status'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [
            eventJson(id: 1, title: 'Demo Event'),
          ]);

      await pumpBookmarks(tester);
      await tester.pumpAndSettle();

      // Search text field with hint
      expect(find.text('Search bookmarked events...'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Filter chips: All + status options
      expect(find.text('All'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsWidgets);
      // Some specific status filter labels
      expect(find.text('Funding'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });
  });
}
