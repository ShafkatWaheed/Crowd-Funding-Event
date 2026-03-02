import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/db/app_database.dart';
import '../../lib/services/api_service.dart';
import '../../lib/services/sync_service.dart';
import '../../lib/screens/sponsor/sponsor_ticket_screen.dart';
import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockSyncService extends Mock implements SyncService {}

void main() {
  late MockApiService mockApi;
  late MockAppDatabase mockDb;
  late MockSyncService mockSync;

  setUp(() {
    mockApi = MockApiService();
    mockDb = MockAppDatabase();
    mockSync = MockSyncService();

    when(() => mockSync.pullSponsorTickets()).thenAnswer((_) async {});
  });

  Map<String, dynamic> ticketJson({
    int id = 1,
    int eventId = 10,
    int sponsorUserId = 5,
    String receiptNumber = 'REC-SP-001',
    String? encryptedQrPayload = 'encrypted-payload',
    String? scannedAt,
    String createdAt = '2025-02-01T10:00:00',
    String? eventTitle = 'Rock Concert',
    String? eventStatus = 'approved',
    String? eventStartTime,
    String? venueName = 'Grand Hall',
    String? venueAddress,
    String? venueCity = 'NYC',
    int categoryCount = 1,
    int scanCount = 0,
    List<Map<String, dynamic>>? categories,
    List<String>? categoryNames,
  }) =>
      {
        'id': id,
        'event_id': eventId,
        'sponsor_user_id': sponsorUserId,
        'receipt_number': receiptNumber,
        'encrypted_qr_payload': encryptedQrPayload,
        'scanned_at': scannedAt,
        'created_at': createdAt,
        'event_title': eventTitle,
        'event_status': eventStatus,
        'event_start_time': eventStartTime,
        'venue_name': venueName,
        'venue_address': venueAddress,
        'venue_city': venueCity,
        'category_count': categoryCount,
        'scan_count': scanCount,
        'categories': categories ?? [
          {'id': 1, 'name': 'Gold Sponsor', 'min_bid_cents': 10000}
        ],
        'category_names': categoryNames ?? ['Gold Sponsor'],
      };

  Future<void> pumpScreen(WidgetTester tester) async {
    await pumpApp(
      tester,
      const SponsorTicketScreen(),
      overrides: [
        Provider<ApiService>.value(value: mockApi),
        Provider<AppDatabase>.value(value: mockDb),
        Provider<SyncService>.value(value: mockSync),
      ],
    );
  }

  group('SponsorTicketScreen', () {
    testWidgets('shows title', (tester) async {
      when(() => mockApi.getMySponsorTickets())
          .thenAnswer((_) async => [ticketJson()]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Sponsor Tickets'), findsOneWidget);
    });

    testWidgets('shows empty state when no tickets', (tester) async {
      when(() => mockApi.getMySponsorTickets())
          .thenAnswer((_) async => []);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('No sponsor tickets yet'), findsOneWidget);
      expect(find.text('Tickets are created when your bids are accepted.'),
          findsOneWidget);
    });

    testWidgets('renders ticket list after load', (tester) async {
      when(() => mockApi.getMySponsorTickets()).thenAnswer((_) async => [
            ticketJson(id: 1, eventTitle: 'Rock Concert'),
            ticketJson(id: 2, eventTitle: 'Jazz Night', receiptNumber: 'REC-SP-002'),
          ]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Rock Concert'), findsOneWidget);
      expect(find.text('Jazz Night'), findsOneWidget);
    });

    testWidgets('falls back to offline cache on API error', (tester) async {
      when(() => mockApi.getMySponsorTickets())
          .thenThrow(Exception('Network error'));
      when(() => mockDb.getSponsorTicketsFromCache())
          .thenAnswer((_) async => []);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      verify(() => mockDb.getSponsorTicketsFromCache()).called(1);
    });

    testWidgets('syncs tickets in background after load', (tester) async {
      when(() => mockApi.getMySponsorTickets())
          .thenAnswer((_) async => [ticketJson()]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      verify(() => mockSync.pullSponsorTickets()).called(1);
    });
  });
}
