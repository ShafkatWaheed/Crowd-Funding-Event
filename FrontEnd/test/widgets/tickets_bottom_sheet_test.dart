import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/services/api_service.dart';
import '../../lib/widgets/tickets_bottom_sheet.dart';
import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

Map<String, dynamic> _ticketJson({
  int id = 1,
  int eventId = 1,
  String ticketCode = 'TKT-001',
  String? receiptNumber = 'REC-001',
  String? tierName = 'General',
  String? eventTitle = 'Concert Night',
  String? eventStatus = 'selling_tickets',
  int amountPaidCents = 5000,
  String status = 'purchased',
  String createdAt = '2025-02-01T10:00:00',
}) =>
    {
      'id': id,
      'event_id': eventId,
      'user_id': 1,
      'ticket_tier_id': 1,
      'ticket_code': ticketCode,
      'receipt_number': receiptNumber,
      'tier_name': tierName,
      'event_title': eventTitle,
      'event_status': eventStatus,
      'amount_paid_cents': amountPaidCents,
      'discount_applied_cents': 0,
      'status': status,
      'created_at': createdAt,
    };

void main() {
  late MockApiService mockApi;

  setUp(() {
    mockApi = MockApiService();
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    // TicketsBottomSheet uses DraggableScrollableSheet which needs a bottom-sheet host.
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showModalBottomSheet(
              context: ctx,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => Provider<ApiService>.value(
                value: mockApi,
                child: const SizedBox(
                  height: 500,
                  child: TicketsBottomSheet(),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
      overrides: [Provider<ApiService>.value(value: mockApi)],
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group('TicketsBottomSheet', () {
    testWidgets('shows loading then renders ticket list', (tester) async {
      when(() => mockApi.getMyTickets(offset: 0, limit: 100)).thenAnswer(
        (_) async => [
          _ticketJson(id: 1, eventTitle: 'Concert Night', eventStatus: 'selling_tickets'),
          _ticketJson(id: 2, eventTitle: 'Jazz Fest', ticketCode: 'TKT-002', eventStatus: 'live'),
        ],
      );

      await pumpSheet(tester);

      expect(find.text('My Tickets'), findsOneWidget);
      expect(find.text('2 tickets'), findsOneWidget);
      expect(find.text('Concert Night'), findsOneWidget);
      expect(find.text('Jazz Fest'), findsOneWidget);
    });

    testWidgets('shows empty state when no tickets', (tester) async {
      when(() => mockApi.getMyTickets(offset: 0, limit: 100))
          .thenAnswer((_) async => []);

      await pumpSheet(tester);

      expect(find.text('No tickets yet'), findsOneWidget);
      expect(find.text('Tickets you purchase will appear here'), findsOneWidget);
    });

    testWidgets('filters tickets by status — excludes non-purchased and non-active events', (tester) async {
      when(() => mockApi.getMyTickets(offset: 0, limit: 100)).thenAnswer(
        (_) async => [
          _ticketJson(id: 1, eventTitle: 'Active', eventStatus: 'selling_tickets', status: 'purchased'),
          _ticketJson(id: 2, eventTitle: 'Refunded', eventStatus: 'selling_tickets', status: 'refunded'),
          _ticketJson(id: 3, eventTitle: 'Completed Event', eventStatus: 'completed', status: 'purchased'),
        ],
      );

      await pumpSheet(tester);

      // Only the active + purchased ticket should appear
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('1 ticket'), findsOneWidget);
      expect(find.text('Refunded'), findsNothing);
      expect(find.text('Completed Event'), findsNothing);
    });

    testWidgets('search filters tickets by event title', (tester) async {
      when(() => mockApi.getMyTickets(offset: 0, limit: 100)).thenAnswer(
        (_) async => [
          _ticketJson(id: 1, eventTitle: 'Rock Concert', eventStatus: 'live'),
          _ticketJson(id: 2, eventTitle: 'Jazz Night', ticketCode: 'TKT-002', eventStatus: 'live'),
        ],
      );

      await pumpSheet(tester);

      expect(find.text('Rock Concert'), findsOneWidget);
      expect(find.text('Jazz Night'), findsOneWidget);

      // Type search query
      await tester.enterText(find.byType(TextField), 'jazz');
      await tester.pump();

      expect(find.text('Rock Concert'), findsNothing);
      expect(find.text('Jazz Night'), findsOneWidget);
    });

    testWidgets('search filters by ticket code', (tester) async {
      when(() => mockApi.getMyTickets(offset: 0, limit: 100)).thenAnswer(
        (_) async => [
          _ticketJson(id: 1, eventTitle: 'Event A', ticketCode: 'ABC-123', eventStatus: 'live'),
          _ticketJson(id: 2, eventTitle: 'Event B', ticketCode: 'XYZ-999', eventStatus: 'live'),
        ],
      );

      await pumpSheet(tester);

      await tester.enterText(find.byType(TextField), 'XYZ');
      await tester.pump();

      expect(find.text('Event A'), findsNothing);
      expect(find.text('Event B'), findsOneWidget);
    });

    testWidgets('shows "No matches" when search yields no results', (tester) async {
      when(() => mockApi.getMyTickets(offset: 0, limit: 100)).thenAnswer(
        (_) async => [
          _ticketJson(id: 1, eventTitle: 'Concert', eventStatus: 'live'),
        ],
      );

      await pumpSheet(tester);

      await tester.enterText(find.byType(TextField), 'zzzzz');
      await tester.pump();

      expect(find.text('No matches'), findsOneWidget);
      expect(find.text('Try a different search term'), findsOneWidget);
    });

    testWidgets('handles API error gracefully', (tester) async {
      when(() => mockApi.getMyTickets(offset: 0, limit: 100))
          .thenThrow(Exception('Network error'));

      await pumpSheet(tester);

      // Should show empty state (loading finishes, tickets list is empty)
      expect(find.text('No tickets yet'), findsOneWidget);
    });

    testWidgets('displays tier name and receipt number', (tester) async {
      when(() => mockApi.getMyTickets(offset: 0, limit: 100)).thenAnswer(
        (_) async => [
          _ticketJson(tierName: 'VIP', receiptNumber: 'REC-VIP-42', eventStatus: 'live'),
        ],
      );

      await pumpSheet(tester);

      expect(find.text('VIP'), findsOneWidget);
      expect(find.text('REC-VIP-42'), findsOneWidget);
    });
  });
}
