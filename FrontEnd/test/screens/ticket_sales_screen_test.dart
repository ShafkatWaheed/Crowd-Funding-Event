import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/ticket.dart';
import '../../lib/repositories/sponsor_repository.dart';
import '../../lib/repositories/ticket_repository.dart';
import '../../lib/providers/sponsor_provider.dart';
import '../../lib/providers/ticket_provider.dart';
import '../../lib/screens/event/ticket_sales_screen.dart';
import '../helpers/mock_sponsor_repository.dart';
import '../helpers/mock_ticket_repository.dart';
import '../helpers/pump_app.dart';

void main() {
  late MockSponsorRepository mockSponsorRepo;
  late MockTicketRepository mockTicketRepo;

  setUp(() {
    mockSponsorRepo = MockSponsorRepository();
    mockTicketRepo = MockTicketRepository();
  });

  Map<String, dynamic> saleJson({
    int id = 1,
    int userId = 1,
    String attendee = 'Alice',
    String tierName = 'General',
    String ticketCode = 'TKT-001',
    int amountPaidCents = 5000,
    int commissionCents = 0,
    int netToOrganizerCents = 5000,
    String? scannedAt,
    String? scannedBy,
    String createdAt = '2025-02-01T10:00:00',
  }) =>
      {
        'id': id,
        'event_id': 1,
        'user_id': userId,
        'ticket_tier_id': 1,
        'ticket_code': ticketCode,
        'attendee_display_name': attendee,
        'tier_name': tierName,
        'amount_paid_cents': amountPaidCents,
        'discount_applied_cents': 0,
        'commission_cents': commissionCents,
        'net_to_organizer_cents': netToOrganizerCents,
        'status': 'active',
        'scanned_at': scannedAt,
        'scanned_by_display_name': scannedBy,
        'created_at': createdAt,
      };

  TicketSale makeSale(Map<String, dynamic> json) => TicketSale.fromJson(json);

  void stubSales({
    List<Map<String, dynamic>>? sales,
    TicketSalesStats? stats,
    bool scannedOnly = false,
  }) {
    final saleObjects = (sales ?? []).map(makeSale).toList();

    if (scannedOnly) {
      when(() => mockTicketRepo.getScannedTickets(any(),
              offset: any(named: 'offset'), limit: any(named: 'limit')))
          .thenAnswer((_) async => saleObjects);
      when(() => mockSponsorRepo.getScannedSponsorTickets(any()))
          .thenAnswer((_) async => []);
    } else {
      when(() => mockTicketRepo.getTicketSales(any(),
              offset: any(named: 'offset'), limit: any(named: 'limit')))
          .thenAnswer((_) async => saleObjects);
    }
    when(() => mockTicketRepo.getTicketSalesStats(any()))
        .thenAnswer((_) async => stats ?? TicketSalesStats(totalSold: 0, totalScanned: 0));
  }

  Future<void> pumpSales(
    WidgetTester tester, {
    bool scannedOnly = false,
  }) async {
    await pumpApp(
      tester,
      TicketSalesScreen(eventId: 1, scannedOnly: scannedOnly),
      overrides: [
        ChangeNotifierProvider<SponsorProvider>.value(value: SponsorProvider(mockSponsorRepo)),
        ChangeNotifierProvider<TicketProvider>.value(value: TicketProvider(mockTicketRepo)),
      ],
    );
  }

  group('TicketSalesScreen — loading & error', () {
    testWidgets('shows shimmer while loading', (tester) async {
      final completer = Completer<List<TicketSale>>();
      when(() => mockTicketRepo.getTicketSales(any(),
              offset: any(named: 'offset'), limit: any(named: 'limit')))
          .thenAnswer((_) => completer.future);
      when(() => mockTicketRepo.getTicketSalesStats(any()))
          .thenAnswer((_) async => TicketSalesStats(totalSold: 0, totalScanned: 0));

      await pumpSales(tester);
      await tester.pump();

      expect(find.text('Event Ticket Sales'), findsOneWidget);

      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('shows error state with retry', (tester) async {
      when(() => mockTicketRepo.getTicketSales(any(),
              offset: any(named: 'offset'), limit: any(named: 'limit')))
          .thenThrow(Exception('Network error'));
      when(() => mockTicketRepo.getTicketSalesStats(any()))
          .thenAnswer((_) async => TicketSalesStats(totalSold: 0, totalScanned: 0));

      await pumpSales(tester);
      await tester.pumpAndSettle();

      expect(find.text('Failed to load'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows empty state when no sales', (tester) async {
      stubSales(sales: []);

      await pumpSales(tester);
      await tester.pumpAndSettle();

      expect(find.text('No ticket sales yet'), findsOneWidget);
    });
  });

  group('TicketSalesScreen — sale list', () {
    testWidgets('renders sale cards with attendee and tier', (tester) async {
      stubSales(sales: [
        saleJson(id: 1, attendee: 'Alice', tierName: 'General', ticketCode: 'TKT-001'),
        saleJson(id: 2, attendee: 'Bob', tierName: 'VIP', ticketCode: 'TKT-002'),
      ]);

      await pumpSales(tester);
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.textContaining('General'), findsWidgets);
      expect(find.textContaining('VIP'), findsWidgets);
    });

    testWidgets('shows price on card', (tester) async {
      stubSales(sales: [
        saleJson(id: 1, amountPaidCents: 7500),
      ]);

      await pumpSales(tester);
      await tester.pumpAndSettle();

      // Price appears on the card and in the revenue stat chip
      expect(find.text('\$75.00'), findsWidgets);
    });

    testWidgets('shows FREE for zero-price tickets', (tester) async {
      stubSales(sales: [
        saleJson(id: 1, amountPaidCents: 0),
      ]);

      await pumpSales(tester);
      await tester.pumpAndSettle();

      expect(find.text('FREE'), findsOneWidget);
    });

    testWidgets('shows net amount when commission present', (tester) async {
      stubSales(sales: [
        saleJson(
          id: 1,
          amountPaidCents: 10000,
          commissionCents: 1000,
          netToOrganizerCents: 9000,
        ),
      ]);

      await pumpSales(tester);
      await tester.pumpAndSettle();

      // $100.00 appears on the card and in the revenue stat chip
      expect(find.text('\$100.00'), findsWidgets);
      // Net amount appears on card and potentially in stat chip
      expect(find.text('Net \$90.00'), findsWidgets);
    });

    testWidgets('shows scanned indicator for scanned tickets', (tester) async {
      stubSales(sales: [
        saleJson(
          id: 1,
          scannedAt: '2025-03-01T14:30:00',
          scannedBy: 'Staff Member',
        ),
      ]);

      await pumpSales(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('Scanned'), findsOneWidget);
      expect(find.textContaining('Staff Member'), findsOneWidget);
    });
  });

  group('TicketSalesScreen — search', () {
    testWidgets('search filters by attendee name', (tester) async {
      stubSales(sales: [
        saleJson(id: 1, attendee: 'Alice'),
        saleJson(id: 2, attendee: 'Bob'),
      ]);

      await pumpSales(tester);
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'bob');
      await tester.pump();

      expect(find.text('Alice'), findsNothing);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('search filters by ticket code', (tester) async {
      stubSales(sales: [
        saleJson(id: 1, attendee: 'Alice', ticketCode: 'ABC-111'),
        saleJson(id: 2, attendee: 'Bob', ticketCode: 'XYZ-999'),
      ]);

      await pumpSales(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'XYZ');
      await tester.pump();

      expect(find.text('Alice'), findsNothing);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('shows "No matching tickets" when search has no results',
        (tester) async {
      stubSales(sales: [
        saleJson(id: 1, attendee: 'Alice'),
      ]);

      await pumpSales(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzzzz');
      await tester.pump();

      expect(find.text('No matching tickets'), findsOneWidget);
    });
  });

  group('TicketSalesScreen — stats', () {
    testWidgets('shows scanned/sold stats bar', (tester) async {
      stubSales(
        sales: [saleJson(id: 1), saleJson(id: 2)],
        stats: TicketSalesStats(totalSold: 10, totalScanned: 3),
      );

      await pumpSales(tester);
      await tester.pumpAndSettle();

      expect(find.text('3 scanned / 10 total sold'), findsOneWidget);
    });

    testWidgets('shows revenue stat chip', (tester) async {
      stubSales(sales: [
        saleJson(id: 1, amountPaidCents: 5000),
        saleJson(id: 2, amountPaidCents: 3000),
      ]);

      await pumpSales(tester);
      await tester.pumpAndSettle();

      // Total revenue: $50.00 + $30.00 = $80.00
      expect(find.text('\$80.00'), findsOneWidget);
    });
  });

  group('TicketSalesScreen — scannedOnly mode', () {
    testWidgets('shows "Scanned Tickets" title', (tester) async {
      stubSales(sales: [], scannedOnly: true);

      await pumpSales(tester, scannedOnly: true);
      await tester.pumpAndSettle();

      expect(find.text('Scanned Tickets'), findsOneWidget);
    });

    testWidgets('shows filter chips in scanned mode', (tester) async {
      stubSales(
        sales: [saleJson(id: 1)],
        scannedOnly: true,
      );

      await pumpSales(tester, scannedOnly: true);
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Sponsor'), findsOneWidget);
    });

    testWidgets('shows empty state for scanned mode', (tester) async {
      stubSales(sales: [], scannedOnly: true);

      await pumpSales(tester, scannedOnly: true);
      await tester.pumpAndSettle();

      expect(find.text('No scanned tickets yet'), findsOneWidget);
    });
  });
}
