import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/services/api_service.dart';
import '../../lib/screens/event/ticket_sales_screen.dart';
import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

void main() {
  late MockApiService mockApi;

  setUp(() {
    mockApi = MockApiService();
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
        'user_id': userId,
        'attendee_display_name': attendee,
        'tier_name': tierName,
        'ticket_code': ticketCode,
        'amount_paid_cents': amountPaidCents,
        'commission_cents': commissionCents,
        'net_to_organizer_cents': netToOrganizerCents,
        'scanned_at': scannedAt,
        'scanned_by_display_name': scannedBy,
        'created_at': createdAt,
      };

  void stubSales({
    List<dynamic>? sales,
    Map<String, dynamic>? stats,
    bool scannedOnly = false,
  }) {
    if (scannedOnly) {
      when(() => mockApi.getScannedTickets(any(),
              offset: any(named: 'offset'), limit: any(named: 'limit')))
          .thenAnswer((_) async => sales ?? []);
      when(() => mockApi.getScannedSponsorTickets(any()))
          .thenAnswer((_) async => []);
    } else {
      when(() => mockApi.getTicketSales(any(),
              offset: any(named: 'offset'), limit: any(named: 'limit')))
          .thenAnswer((_) async => sales ?? []);
    }
    when(() => mockApi.getTicketSalesStats(any()))
        .thenAnswer((_) async => stats ?? {'total_sold': 0, 'total_scanned': 0});
  }

  Future<void> pumpSales(
    WidgetTester tester, {
    bool scannedOnly = false,
  }) async {
    await pumpApp(
      tester,
      TicketSalesScreen(eventId: 1, scannedOnly: scannedOnly),
      overrides: [
        Provider<ApiService>.value(value: mockApi),
      ],
    );
  }

  group('TicketSalesScreen — loading & error', () {
    testWidgets('shows shimmer while loading', (tester) async {
      final completer = Completer<List<dynamic>>();
      when(() => mockApi.getTicketSales(any(),
              offset: any(named: 'offset'), limit: any(named: 'limit')))
          .thenAnswer((_) => completer.future);
      when(() => mockApi.getTicketSalesStats(any()))
          .thenAnswer((_) async => {'total_sold': 0, 'total_scanned': 0});

      await pumpSales(tester);
      await tester.pump();

      expect(find.text('Event Ticket Sales'), findsOneWidget);

      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('shows error state with retry', (tester) async {
      when(() => mockApi.getTicketSales(any(),
              offset: any(named: 'offset'), limit: any(named: 'limit')))
          .thenThrow(Exception('Network error'));
      when(() => mockApi.getTicketSalesStats(any()))
          .thenAnswer((_) async => {'total_sold': 0, 'total_scanned': 0});

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
        stats: {'total_sold': 10, 'total_scanned': 3},
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
