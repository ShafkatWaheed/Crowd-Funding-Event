/// Widget tests for ExploreTab — search, filters, loading, empty, error, and
/// event list rendering.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';

import '../../lib/models/event.dart';
import '../../lib/models/user.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/providers/event_provider.dart';
import '../../lib/screens/home/tabs/explore_tab.dart';
import '../../lib/widgets/shimmer_loaders.dart';
import '../helpers/mock_providers.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockEventProvider mockEvent;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockEvent = MockEventProvider();

    // Default stubs
    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.customer));
    when(() => mockAuth.isAuthenticated).thenReturn(true);
    when(() => mockAuth.isLoading).thenReturn(false);
    when(() => mockAuth.addListener(any())).thenReturn(null);
    when(() => mockAuth.removeListener(any())).thenReturn(null);

    when(() => mockEvent.events).thenReturn([]);
    when(() => mockEvent.isLoading).thenReturn(false);
    when(() => mockEvent.isLoadingMore).thenReturn(false);
    when(() => mockEvent.hasMore).thenReturn(false);
    when(() => mockEvent.error).thenReturn(null);
    when(() => mockEvent.loadEvents(filters: any(named: 'filters')))
        .thenAnswer((_) async {});
    when(() => mockEvent.addListener(any())).thenReturn(null);
    when(() => mockEvent.removeListener(any())).thenReturn(null);
  });

  List<SingleChildWidget> buildProviders() => [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<EventProvider>.value(value: mockEvent),
      ];

  Widget _buildExploreTab() {
    return Scaffold(
      body: ExploreTab(
        bookmarkedIds: const {},
        onToggleBookmark: (_) {},
        cities: const [],
        genres: const ['music', 'tech', 'sports'],
      ),
    );
  }

  group('ExploreTab', () {
    testWidgets('renders search field', (tester) async {
      await pumpApp(tester, _buildExploreTab(), overrides: buildProviders());
      await tester.pump();

      // The search TextField should have the hint text
      expect(find.widgetWithText(TextField, 'Search events...'), findsOneWidget);

      // Consume remaining flutter_animate timers.
      await tester.pumpAndSettle();
    });

    testWidgets('search field accepts text input', (tester) async {
      await pumpApp(tester, _buildExploreTab(), overrides: buildProviders());
      await tester.pump();

      final searchField = find.widgetWithText(TextField, 'Search events...');
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'concert');
      await tester.pump();

      expect(find.text('concert'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('renders filter chips for visible statuses', (tester) async {
      await pumpApp(tester, _buildExploreTab(), overrides: buildProviders());
      await tester.pump();

      // Customer sees: Funding, Awaiting Date, Selling Tickets, Live
      // These are ChoiceChip widgets in a horizontal ListView
      expect(find.byType(ChoiceChip), findsWidgets);
      // Check at least one status chip is present
      expect(find.text('Funding'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('shows shimmer loading state when isLoading is true',
        (tester) async {
      when(() => mockEvent.isLoading).thenReturn(true);

      await pumpApp(tester, _buildExploreTab(), overrides: buildProviders());
      await tester.pump();

      // ShimmerEventList is rendered during loading
      expect(find.byType(ShimmerEventList), findsOneWidget);
    });

    testWidgets('shows empty state when no events found', (tester) async {
      when(() => mockEvent.isLoading).thenReturn(false);
      when(() => mockEvent.events).thenReturn([]);
      when(() => mockEvent.error).thenReturn(null);

      await pumpApp(tester, _buildExploreTab(), overrides: buildProviders());
      await tester.pump();

      expect(find.text('No events found'), findsOneWidget);
      expect(find.text('Try adjusting your filters'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('shows error state when error is set', (tester) async {
      when(() => mockEvent.isLoading).thenReturn(false);
      when(() => mockEvent.error).thenReturn('Network error');
      when(() => mockEvent.events).thenReturn([]);
      when(() => mockEvent.loadEvents()).thenAnswer((_) async {});

      await pumpApp(tester, _buildExploreTab(), overrides: buildProviders());
      await tester.pump();

      expect(find.text('Network error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('renders event list when events are present', (tester) async {
      final events = [
        makeEvent(id: 1, title: 'Music Fest'),
        makeEvent(id: 2, title: 'Tech Summit'),
      ];
      when(() => mockEvent.isLoading).thenReturn(false);
      when(() => mockEvent.events).thenReturn(events);
      when(() => mockEvent.error).thenReturn(null);

      await pumpApp(tester, _buildExploreTab(), overrides: buildProviders());
      await tester.pump();

      // Events should be rendered (not empty state, not shimmer)
      expect(find.text('No events found'), findsNothing);
      // The section heading "All Events" should be visible
      expect(find.text('All Events'), findsOneWidget);

      await tester.pumpAndSettle();
    });
  });

  group('ExploreTab — infinite scroll', () {
    testWidgets('shows bottom loading spinner when isLoadingMore is true',
        (tester) async {
      when(() => mockEvent.isLoading).thenReturn(false);
      when(() => mockEvent.error).thenReturn(null);
      when(() => mockEvent.events)
          .thenReturn([makeEvent(id: 1, title: 'Music Fest')]);
      when(() => mockEvent.isLoadingMore).thenReturn(true);

      await pumpApp(tester, _buildExploreTab(), overrides: buildProviders());
      await tester.pump();

      // The SliverToBoxAdapter rendered when isLoadingMore is true contains a
      // CircularProgressIndicator — distinct from the ShimmerEventList shown
      // during the initial load.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Drain flutter_animate timers with a fixed-duration pump instead of
      // pumpAndSettle — the CircularProgressIndicator repeats indefinitely
      // and would cause pumpAndSettle to time out.
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('hides bottom spinner when isLoadingMore is false',
        (tester) async {
      when(() => mockEvent.isLoading).thenReturn(false);
      when(() => mockEvent.error).thenReturn(null);
      when(() => mockEvent.events)
          .thenReturn([makeEvent(id: 1, title: 'Music Fest')]);
      when(() => mockEvent.isLoadingMore).thenReturn(false);
      when(() => mockEvent.hasMore).thenReturn(false);

      await pumpApp(tester, _buildExploreTab(), overrides: buildProviders());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpAndSettle();
    });

    testWidgets(
        'loadMoreEvents is called when scrolled to bottom and hasMore is true',
        (tester) async {
      // Use enough events to make the list overflow the 1920 px test viewport
      final manyEvents = List.generate(
        16,
        (i) => makeEvent(id: i + 1, title: 'Event ${i + 1}'),
      );

      when(() => mockEvent.isLoading).thenReturn(false);
      when(() => mockEvent.error).thenReturn(null);
      when(() => mockEvent.events).thenReturn(manyEvents);
      when(() => mockEvent.isLoadingMore).thenReturn(false);
      when(() => mockEvent.hasMore).thenReturn(true);
      when(() => mockEvent.loadMoreEvents()).thenAnswer((_) async {});

      await pumpApp(tester, _buildExploreTab(), overrides: buildProviders());
      await tester.pump();

      // Scroll all the way to the bottom to trigger the NotificationListener
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -8000),
      );
      await tester.pump();

      verify(() => mockEvent.loadMoreEvents()).called(greaterThanOrEqualTo(1));

      await tester.pumpAndSettle();
    });

    testWidgets(
        'loadMoreEvents is NOT called when isLoadingMore is already true',
        (tester) async {
      when(() => mockEvent.isLoading).thenReturn(false);
      when(() => mockEvent.error).thenReturn(null);
      when(() => mockEvent.events)
          .thenReturn([makeEvent(id: 1, title: 'Event 1')]);
      // Already loading more — the NotificationListener guard checks
      // `!events.isLoadingMore` before calling loadMoreEvents.
      when(() => mockEvent.isLoadingMore).thenReturn(true);
      when(() => mockEvent.hasMore).thenReturn(true);

      await pumpApp(tester, _buildExploreTab(), overrides: buildProviders());
      await tester.pump();

      // The loading-more spinner is visible (isLoadingMore: true)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // loadMoreEvents must never be called in this state — the guard in
      // NotificationListener blocks it when isLoadingMore is already true.
      verifyNever(() => mockEvent.loadMoreEvents());

      // Drain flutter_animate timers without blocking on the infinite spinner.
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
