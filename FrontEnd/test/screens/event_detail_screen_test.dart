/// Widget tests for EventDetailScreen — loading, error, content, and age
/// restriction rendering.
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
import '../../lib/services/api_service.dart';
import '../../lib/services/sync_service.dart';
import '../../lib/screens/event/event_detail_screen.dart';
import '../../lib/widgets/shimmer_loaders.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_api_service.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

class MockSyncService extends Mock implements SyncService {}

void main() {
  late MockAuthProvider mockAuth;
  late MockEventProvider mockEvent;
  late MockApiService mockApi;
  late MockSyncService mockSync;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockEvent = MockEventProvider();
    mockApi = MockApiService();
    mockSync = MockSyncService();

    // Unstubbed API methods should throw (caught by widget try/catch)
    // rather than returning null which causes type errors.
    throwOnMissingStub(mockApi);

    // Auth defaults
    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.customer));
    when(() => mockAuth.isAuthenticated).thenReturn(true);
    when(() => mockAuth.isLoading).thenReturn(false);
    when(() => mockAuth.addListener(any())).thenReturn(null);
    when(() => mockAuth.removeListener(any())).thenReturn(null);

    // Event provider defaults
    when(() => mockEvent.events).thenReturn([]);
    when(() => mockEvent.isLoading).thenReturn(false);
    when(() => mockEvent.isLoadingMore).thenReturn(false);
    when(() => mockEvent.hasMore).thenReturn(false);
    when(() => mockEvent.error).thenReturn(null);
    when(() => mockEvent.selectedEvent).thenReturn(null);
    when(() => mockEvent.loadEvent(any(), forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async {});
    when(() => mockEvent.addListener(any())).thenReturn(null);
    when(() => mockEvent.removeListener(any())).thenReturn(null);

    // ApiService stubs for EventDetailScreen's initState calls
    when(() => mockApi.getEventImages(any()))
        .thenAnswer((_) async => <Map<String, dynamic>>[]);
    when(() => mockApi.getMyRegistration(any()))
        .thenAnswer((_) async => {'registered': false});
    when(() => mockApi.getMyTickets(
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
          sortBy: any(named: 'sortBy'),
        )).thenAnswer((_) async => <dynamic>[]);
    when(() => mockApi.getMyPledges(
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
          sortBy: any(named: 'sortBy'),
        )).thenAnswer((_) async => <dynamic>[]);
    when(() => mockApi.checkBookmarks(any()))
        .thenAnswer((_) async => {'bookmarked_ids': <int>[]});
    when(() => mockApi.getTicketSales(any(),
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => <dynamic>[]);

    // SyncService stubs
    when(() => mockSync.cacheTransportForEvent(
          eventId: any(named: 'eventId'),
          parkingInfo: any(named: 'parkingInfo'),
          transitInfo: any(named: 'transitInfo'),
          rideshareInfo: any(named: 'rideshareInfo'),
          accessibilityInfo: any(named: 'accessibilityInfo'),
          directionsUrl: any(named: 'directionsUrl'),
        )).thenAnswer((_) async {});
    when(() => mockSync.cacheScheduleForEvent(any()))
        .thenAnswer((_) async {});
  });

  List<SingleChildWidget> buildProviders() => [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<EventProvider>.value(value: mockEvent),
        Provider<ApiService>.value(value: mockApi),
        Provider<SyncService>.value(value: mockSync),
      ];

  group('EventDetailScreen', () {
    testWidgets('shows shimmer loading state when isLoading is true',
        (tester) async {
      when(() => mockEvent.isLoading).thenReturn(true);
      when(() => mockEvent.selectedEvent).thenReturn(null);

      await pumpApp(
        tester,
        const EventDetailScreen(eventId: 1),
        overrides: buildProviders(),
      );
      await tester.pump();

      expect(find.byType(ShimmerDetailHeader), findsOneWidget);
    });

    testWidgets('shows error state with message when error is set',
        (tester) async {
      when(() => mockEvent.isLoading).thenReturn(false);
      when(() => mockEvent.error).thenReturn('Failed to load event details.');
      when(() => mockEvent.selectedEvent).thenReturn(null);

      await pumpApp(
        tester,
        const EventDetailScreen(eventId: 1),
        overrides: buildProviders(),
      );
      await tester.pump();

      expect(find.text('Failed to load event details.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('renders event title and description when loaded',
        (tester) async {
      final event = makeEvent(
        id: 1,
        title: 'Amazing Concert',
        status: 'approved',
      );
      // The fixture makeEvent uses eventJson which sets description to
      // 'A test event' by default.
      when(() => mockEvent.isLoading).thenReturn(false);
      when(() => mockEvent.error).thenReturn(null);
      when(() => mockEvent.selectedEvent).thenReturn(event);

      await pumpApp(
        tester,
        const EventDetailScreen(eventId: 1),
        overrides: buildProviders(),
      );
      await tester.pump();

      // Title appears twice: once in AppBar (may be invisible), once in body
      expect(find.text('Amazing Concert'), findsWidgets);
      // Description appears in the About section
      expect(find.text('A test event'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('shows age restriction banner when event is age restricted',
        (tester) async {
      final event = Event.fromJson(eventJson(
        id: 1,
        title: 'Adult Event',
        ageRestricted: true,
        minAge: 21,
      ));
      when(() => mockEvent.isLoading).thenReturn(false);
      when(() => mockEvent.error).thenReturn(null);
      when(() => mockEvent.selectedEvent).thenReturn(event);

      // The customer user has no birthday set, so isBlocked = true
      await pumpApp(
        tester,
        const EventDetailScreen(eventId: 1),
        overrides: buildProviders(),
      );
      await tester.pump();

      // AgeRestrictionBanner should show the age pill "21+"
      expect(find.text('21+'), findsOneWidget);
      // And the blocked message
      expect(
        find.textContaining('at least 21 years old'),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
    });

    testWidgets('renders key sections when event has funding',
        (tester) async {
      final event = makeEvent(
        id: 1,
        title: 'Funded Event',
        status: 'approved',
        fundingGoalCents: 100000,
        totalPledgedCents: 50000,
      );
      when(() => mockEvent.isLoading).thenReturn(false);
      when(() => mockEvent.error).thenReturn(null);
      when(() => mockEvent.selectedEvent).thenReturn(event);

      await pumpApp(
        tester,
        const EventDetailScreen(eventId: 1),
        overrides: buildProviders(),
      );
      await tester.pump();

      // Title should render
      expect(find.text('Funded Event'), findsWidgets);
      // About section should be present (description is "A test event")
      expect(find.text('About'), findsOneWidget);
      // The funding section renders a FundingCard — we check that the
      // overall Scaffold rendered successfully with content
      expect(find.byType(Scaffold), findsOneWidget);

      await tester.pumpAndSettle();
    });
  });
}
