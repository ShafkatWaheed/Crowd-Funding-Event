import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:crowd_funding_app/db/app_database.dart';
import 'package:crowd_funding_app/models/sponsor.dart';
import 'package:crowd_funding_app/providers/sponsor_provider.dart';
import 'package:crowd_funding_app/services/sync_service.dart';
import 'package:crowd_funding_app/screens/sponsor/sponsor_ticket_screen.dart';
import '../helpers/mock_sponsor_repository.dart';
import '../helpers/pump_app.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockSyncService extends Mock implements SyncService {}

void main() {
  late MockSponsorRepository mockSponsorRepo;
  late MockAppDatabase mockDb;
  late MockSyncService mockSync;

  setUp(() {
    mockSponsorRepo = MockSponsorRepository();
    mockDb = MockAppDatabase();
    mockSync = MockSyncService();

    when(() => mockSync.pullSponsorTickets()).thenAnswer((_) async {});
  });

  SponsorTicketModel makeTicket({
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
    List<SponsorTicketCategory>? categories,
    List<String>? categoryNames,
  }) =>
      SponsorTicketModel(
        id: id,
        eventId: eventId,
        sponsorUserId: sponsorUserId,
        receiptNumber: receiptNumber,
        encryptedQrPayload: encryptedQrPayload,
        scannedAt: scannedAt,
        createdAt: createdAt,
        eventTitle: eventTitle,
        eventStatus: eventStatus,
        eventStartTime: eventStartTime,
        venueName: venueName,
        venueAddress: venueAddress,
        venueCity: venueCity,
        categoryCount: categoryCount,
        scanCount: scanCount,
        categories: categories ?? [
          SponsorTicketCategory(name: 'Gold Sponsor', amountCents: 10000, status: 'accepted'),
        ],
        categoryNames: categoryNames ?? ['Gold Sponsor'],
      );

  Future<void> pumpScreen(WidgetTester tester) async {
    await pumpApp(
      tester,
      const SponsorTicketScreen(),
      overrides: [
        ChangeNotifierProvider<SponsorProvider>.value(value: SponsorProvider(mockSponsorRepo)),
        Provider<AppDatabase>.value(value: mockDb),
        Provider<SyncService>.value(value: mockSync),
      ],
    );
  }

  group('SponsorTicketScreen', () {
    testWidgets('shows title', (tester) async {
      when(() => mockSponsorRepo.getMySponsorTickets())
          .thenAnswer((_) async => [makeTicket()]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Sponsor Tickets'), findsOneWidget);
    });

    testWidgets('shows empty state when no tickets', (tester) async {
      when(() => mockSponsorRepo.getMySponsorTickets())
          .thenAnswer((_) async => []);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('No sponsor tickets yet'), findsOneWidget);
      expect(find.text('Tickets are created when your bids are accepted.'),
          findsOneWidget);
    });

    testWidgets('renders ticket list after load', (tester) async {
      when(() => mockSponsorRepo.getMySponsorTickets()).thenAnswer((_) async => [
            makeTicket(id: 1, eventTitle: 'Rock Concert'),
            makeTicket(id: 2, eventTitle: 'Jazz Night', receiptNumber: 'REC-SP-002'),
          ]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Rock Concert'), findsOneWidget);
      expect(find.text('Jazz Night'), findsOneWidget);
    });

    testWidgets('falls back to offline cache on API error', (tester) async {
      when(() => mockSponsorRepo.getMySponsorTickets())
          .thenThrow(Exception('Network error'));
      when(() => mockDb.getSponsorTicketsFromCache())
          .thenAnswer((_) async => []);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      verify(() => mockDb.getSponsorTicketsFromCache()).called(1);
    });

    testWidgets('syncs tickets in background after load', (tester) async {
      when(() => mockSponsorRepo.getMySponsorTickets())
          .thenAnswer((_) async => [makeTicket()]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      verify(() => mockSync.pullSponsorTickets()).called(1);
    });
  });
}
