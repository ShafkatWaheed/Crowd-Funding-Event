import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:crowd_funding_app/models/event.dart';
import 'package:crowd_funding_app/models/ticket.dart';
import 'package:crowd_funding_app/models/user.dart';
import 'package:crowd_funding_app/providers/auth_provider.dart';
import 'package:crowd_funding_app/providers/event_provider.dart';
import 'package:crowd_funding_app/providers/config_provider.dart';
import 'package:crowd_funding_app/repositories/payment_repository.dart';
import 'package:crowd_funding_app/providers/ticket_provider.dart';
import 'package:crowd_funding_app/screens/event/event_detail/ticket_tiers_section.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_payment_repository.dart';
import '../helpers/mock_ticket_repository.dart';
import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockConfigProvider mockConfig;
  late MockPaymentRepository mockPaymentRepo;
  late MockEventProvider mockEvent;
  late MockTicketRepository mockTicketRepo;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockConfig = MockConfigProvider();
    mockPaymentRepo = MockPaymentRepository();
    mockEvent = MockEventProvider();
    mockTicketRepo = MockTicketRepository();

    when(() => mockConfig.stripeEnabled).thenReturn(false);
    when(() => mockConfig.addListener(any())).thenReturn(null);
    when(() => mockConfig.removeListener(any())).thenReturn(null);

    // Default: logged-in customer (not organizer/admin)
    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.customer));
  });

  /// Helper to pump TicketTiersSection with injected providers.
  Future<void> pumpTiersSection(
    WidgetTester tester, {
    Event? event,
    int myTicketCount = 0,
    int myReservedSpots = 0,
    List<TicketSale>? myEventTickets,
    bool isOrganizer = false,
    bool isAdmin = false,
    bool isRegistered = true,
  }) async {
    // Event with ticketStrategyId set so tiers section is visible
    final ev = event ??
        Event.fromJson(eventJson(
          id: 1,
          status: 'selling_tickets',
          fundingGoalCents: 100000,
          totalPledgedCents: 50000,
        )..['ticket_strategy_id'] = 1);

    await pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: TicketTiersSection(
            event: ev,
            myTicketCount: myTicketCount,
            myReservedSpots: myReservedSpots,
            myEventTickets: myEventTickets ?? [],
            isOrganizer: isOrganizer,
            isAdmin: isAdmin,
            isRegistered: isRegistered,
            onPurchaseComplete: () {},
          ),
        ),
      ),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<EventProvider>.value(value: mockEvent),
        ChangeNotifierProvider<ConfigProvider>.value(value: mockConfig),
        Provider<PaymentRepository>.value(value: mockPaymentRepo),
        ChangeNotifierProvider<TicketProvider>.value(value: TicketProvider(mockTicketRepo)),
      ],
    );
  }

  /// Stubs the MockTicketRepository to return [tiers] when getTicketTiers is called.
  void stubTiers(MockTicketRepository repo, List<Map<String, dynamic>> tiers) {
    when(() => repo.getTicketTiers(any()))
        .thenAnswer((_) async => tiers.map((t) => TicketTier.fromJson({
              'id': t['id'],
              'event_id': 1,
              'name': t['name'],
              'price_cents': t['price_cents'],
              'max_reserved_spots': t['max_reserved_spots'] ?? 0,
              'display_order': 0,
              ...t,
            })).toList());
  }

  group('TicketTiersSection', () {
    testWidgets('renders tier list', (tester) async {
      stubTiers(mockTicketRepo, [
        {
          'id': 1,
          'name': 'General',
          'price_cents': 5000,
          'max_reserved_spots': 100,
          'tickets_sold': 20,
          'spots_reserved': 5,
        },
        {
          'id': 2,
          'name': 'VIP',
          'price_cents': 15000,
          'max_reserved_spots': 20,
          'tickets_sold': 5,
          'spots_reserved': 2,
        },
      ]);

      await pumpTiersSection(tester);
      await tester.pumpAndSettle();

      expect(find.text('General'), findsOneWidget);
      expect(find.text('VIP'), findsOneWidget);
    });

    testWidgets('shows tier name and price', (tester) async {
      stubTiers(mockTicketRepo, [
        {
          'id': 1,
          'name': 'Standard',
          'price_cents': 7500,
          'max_reserved_spots': 0,
          'tickets_sold': 0,
          'spots_reserved': 0,
        },
      ]);

      await pumpTiersSection(tester);
      await tester.pumpAndSettle();

      expect(find.text('Standard'), findsOneWidget);
      // Price shown as "$75.00"
      expect(find.text('\$75.00'), findsOneWidget);
    });

    testWidgets('free tier shows FREE label', (tester) async {
      stubTiers(mockTicketRepo, [
        {
          'id': 1,
          'name': 'Community',
          'price_cents': 0,
          'max_reserved_spots': 50,
          'tickets_sold': 10,
          'spots_reserved': 0,
        },
      ]);

      await pumpTiersSection(tester);
      await tester.pumpAndSettle();

      expect(find.text('Community'), findsOneWidget);
      expect(find.text('FREE'), findsOneWidget);
    });

    testWidgets('sold-out state handling', (tester) async {
      stubTiers(mockTicketRepo, [
        {
          'id': 1,
          'name': 'Limited',
          'price_cents': 10000,
          'max_reserved_spots': 10,
          'tickets_sold': 8,
          'spots_reserved': 2,
        },
      ]);

      await pumpTiersSection(tester);
      await tester.pumpAndSettle();

      // spotsLeft = 10 - 8 - 2 = 0 => "Sold out"
      expect(find.text('Sold out'), findsOneWidget);
    });

    testWidgets('buy button exists for customer on selling_tickets event',
        (tester) async {
      stubTiers(mockTicketRepo, [
        {
          'id': 1,
          'name': 'General',
          'price_cents': 5000,
          'max_reserved_spots': 0,
          'tickets_sold': 0,
          'spots_reserved': 0,
        },
      ]);

      await pumpTiersSection(tester);
      await tester.pumpAndSettle();

      // The "Buy Tickets" button is rendered for customer on selling_tickets events
      expect(find.text('Buy Tickets'), findsOneWidget);
    });

    testWidgets('quantity display when spots are available', (tester) async {
      stubTiers(mockTicketRepo, [
        {
          'id': 1,
          'name': 'General',
          'price_cents': 5000,
          'max_reserved_spots': 50,
          'tickets_sold': 10,
          'spots_reserved': 5,
        },
      ]);

      await pumpTiersSection(tester);
      await tester.pumpAndSettle();

      // Should show available spots text "35 of 50 spots available"
      expect(find.textContaining('35 of 50 spots available'), findsOneWidget);
    });
  });
}
