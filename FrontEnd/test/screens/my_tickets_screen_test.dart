import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/user.dart';
import '../../lib/models/ticket.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/providers/ticket_provider.dart';
import '../../lib/services/sync_service.dart';
import '../../lib/db/app_database.dart';
import '../../lib/repositories/ticket_repository.dart';
import '../../lib/repositories/base_repository.dart';
import '../../lib/screens/profile/my_tickets_screen.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_ticket_repository.dart';
import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

class MockSyncService extends Mock implements SyncService {}

class MockAppDatabase extends Mock implements AppDatabase {}

void main() {
  late MockAuthProvider mockAuth;
  late MockSyncService mockSync;
  late MockAppDatabase mockDb;
  late MockTicketRepository mockTicketRepo;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockSync = MockSyncService();
    mockDb = MockAppDatabase();
    mockTicketRepo = MockTicketRepository();

    // Default: logged-in customer
    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.customer));

    // Stub pullMyTickets (background sync, returns void)
    when(() => mockSync.pullMyTickets()).thenAnswer((_) async {});

    // Stub offline cache (returns empty by default)
    when(() => mockDb.getMyTicketsFromCache()).thenAnswer((_) async => <CachedMyTicket>[]);
  });

  /// Helper to pump MyTicketsScreen with injected providers.
  Future<void> pumpMyTickets(WidgetTester tester) async {
    await pumpApp(
      tester,
      const MyTicketsScreen(),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        Provider<SyncService>.value(value: mockSync),
        Provider<AppDatabase>.value(value: mockDb),
        ChangeNotifierProvider<TicketProvider>.value(value: TicketProvider(mockTicketRepo)),
      ],
    );
  }

  group('MyTicketsScreen', () {
    testWidgets('renders ticket list after load', (tester) async {
      when(() => mockTicketRepo.getMyTickets(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) async => PaginatedResult(
            items: [
              TicketSale.fromJson(ticketSaleJson(
                id: 1,
                eventId: 10,
                amountPaidCents: 5000,
                tierName: 'General',
                eventTitle: 'Rock Show',
                ticketCode: 'TKT-AAA',
              )),
              TicketSale.fromJson(ticketSaleJson(
                id: 2,
                eventId: 10,
                amountPaidCents: 15000,
                tierName: 'VIP',
                eventTitle: 'Rock Show',
                ticketCode: 'TKT-BBB',
              )),
            ],
            hasMore: false,
          ));

      await pumpMyTickets(tester);
      await tester.pumpAndSettle();

      // Event group header should show event title
      expect(find.text('Rock Show'), findsWidgets);
      // Ticket cards should be rendered
      expect(find.textContaining('TKT-AAA'), findsOneWidget);
    });

    testWidgets('sort chips exist', (tester) async {
      when(() => mockTicketRepo.getMyTickets(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) async => PaginatedResult(
            items: [TicketSale.fromJson(ticketSaleJson(id: 1, eventTitle: 'Test'))],
            hasMore: false,
          ));

      await pumpMyTickets(tester);
      await tester.pumpAndSettle();

      // Sort chips: Newest, Oldest, Price up, Price down
      expect(find.text('Newest'), findsOneWidget);
      expect(find.text('Oldest'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsWidgets);
    });

    testWidgets('empty state message when no tickets', (tester) async {
      when(() => mockTicketRepo.getMyTickets(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) async => PaginatedResult(
            items: <TicketSale>[],
            hasMore: false,
          ));

      await pumpMyTickets(tester);
      await tester.pumpAndSettle();

      expect(find.text('No tickets yet'), findsOneWidget);
      expect(
          find.text('Tickets you purchase will appear here'), findsOneWidget);
    });

    testWidgets('loading state shown initially', (tester) async {
      final completer = Completer<PaginatedResult<TicketSale>>();
      when(() => mockTicketRepo.getMyTickets(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) => completer.future);

      await pumpMyTickets(tester);
      await tester.pump();

      // AppBar title should be visible during loading
      expect(find.text('My Tickets'), findsOneWidget);
    });

    testWidgets('ticket card shows details', (tester) async {
      when(() => mockTicketRepo.getMyTickets(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) async => PaginatedResult(
            items: [
              TicketSale.fromJson(ticketSaleJson(
                id: 1,
                eventId: 10,
                amountPaidCents: 7500,
                tierName: 'Premium',
                eventTitle: 'Jazz Night',
                ticketCode: 'TKT-XYZ',
                receiptNumber: 'REC-TKT-XYZ',
                status: 'purchased',
              )),
            ],
            hasMore: false,
          ));

      await pumpMyTickets(tester);
      await tester.pumpAndSettle();

      // Event title shown in card header
      expect(find.text('Jazz Night'), findsWidgets);
      // Tier name shown in the card
      expect(find.text('Premium'), findsOneWidget);
      // Amount displayed as $75.00
      expect(find.textContaining('\$75.00'), findsWidgets);
      // Ticket code shown
      expect(find.text('TKT-XYZ'), findsOneWidget);
      // Status badge
      expect(find.text('PURCHASED'), findsOneWidget);
    });
  });
}
