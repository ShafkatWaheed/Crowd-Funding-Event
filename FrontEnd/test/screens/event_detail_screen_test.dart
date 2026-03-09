/// Widget tests for EventDetailScreen — loading, error, content, and age
/// restriction rendering.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';

import 'package:crowd_funding_app/models/event.dart';
import 'package:crowd_funding_app/models/event_image.dart';
import 'package:crowd_funding_app/models/funding.dart';
import 'package:crowd_funding_app/models/ticket.dart';
import 'package:crowd_funding_app/models/user.dart';
import 'package:crowd_funding_app/repositories/base_repository.dart';
import 'package:crowd_funding_app/providers/auth_provider.dart';
import 'package:crowd_funding_app/providers/event_provider.dart';
import 'package:crowd_funding_app/repositories/funding_repository.dart';
import 'package:crowd_funding_app/providers/ticket_provider.dart';
import 'package:crowd_funding_app/providers/pledge_provider.dart';
import 'package:crowd_funding_app/providers/config_provider.dart';
import 'package:crowd_funding_app/repositories/payment_repository.dart';
import 'package:crowd_funding_app/services/sync_service.dart';
import 'package:crowd_funding_app/screens/event/event_detail_screen.dart';
import 'package:crowd_funding_app/widgets/shimmer_loaders.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_payment_repository.dart';
import '../helpers/mock_event_repository.dart';
import '../helpers/mock_ticket_repository.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

class MockSyncService extends Mock implements SyncService {}

class MockFundingRepository extends Mock implements FundingRepository {}

void main() {
  late MockAuthProvider mockAuth;
  late MockEventProvider mockEvent;
  late MockConfigProvider mockConfig;
  late MockPaymentRepository mockPaymentRepo;
  late MockSyncService mockSync;
  late MockEventRepository mockEventRepo;
  late MockTicketRepository mockTicketRepo;
  late MockFundingRepository mockFundingRepo;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockEvent = MockEventProvider();
    mockConfig = MockConfigProvider();
    mockPaymentRepo = MockPaymentRepository();
    mockSync = MockSyncService();

    // ConfigProvider stubs
    when(() => mockConfig.stripeEnabled).thenReturn(false);
    when(() => mockConfig.addListener(any())).thenReturn(null);
    when(() => mockConfig.removeListener(any())).thenReturn(null);
    mockEventRepo = MockEventRepository();
    mockTicketRepo = MockTicketRepository();
    mockFundingRepo = MockFundingRepository();

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

    // EventRepository stubs for EventDetailScreen's initState calls
    when(() => mockEventRepo.getEventImages(any()))
        .thenAnswer((_) async => <EventImage>[]);
    when(() => mockEventRepo.getMyRegistration(any()))
        .thenAnswer((_) async => null);
    when(() => mockEventRepo.checkBookmarks(any()))
        .thenAnswer((_) async => <int, bool>{});

    // TicketRepository stubs
    when(() => mockTicketRepo.getMyTickets(
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
          sortBy: any(named: 'sortBy'),
        )).thenAnswer((_) async => PaginatedResult<TicketSale>(items: [], hasMore: false));
    when(() => mockTicketRepo.getTicketSales(any(),
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => <TicketSale>[]);

    // FundingRepository stubs
    when(() => mockFundingRepo.getMyPledges(
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
          sortBy: any(named: 'sortBy'),
        )).thenAnswer((_) async => PaginatedResult<Pledge>(items: [], hasMore: false));

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
        ChangeNotifierProvider<ConfigProvider>.value(value: mockConfig),
        Provider<PaymentRepository>.value(value: mockPaymentRepo),
        Provider<SyncService>.value(value: mockSync),
        ChangeNotifierProvider<TicketProvider>.value(value: TicketProvider(mockTicketRepo)),
        ChangeNotifierProvider<PledgeProvider>.value(value: PledgeProvider(mockFundingRepo)),
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
