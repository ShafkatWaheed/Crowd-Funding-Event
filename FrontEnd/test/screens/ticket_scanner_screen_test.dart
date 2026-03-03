import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/db/app_database.dart';
import '../../lib/services/sync_service.dart';
import '../../lib/repositories/ticket_repository.dart';
import '../../lib/providers/ticket_provider.dart';
import '../../lib/screens/event/ticket_scanner_screen.dart';
import '../helpers/mock_ticket_repository.dart';
import '../helpers/pump_app.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockSyncService extends Mock implements SyncService {}

void main() {
  late MockAppDatabase mockDb;
  late MockSyncService mockSync;
  late MockTicketRepository mockTicketRepo;

  setUp(() {
    mockDb = MockAppDatabase();
    mockSync = MockSyncService();
    mockTicketRepo = MockTicketRepository();

    when(() => mockDb.countOfflineTickets(any())).thenAnswer((_) async => 0);
    when(() => mockSync.pushOfflineScans()).thenAnswer((_) async {});
  });

  Future<void> pumpScanner(
    WidgetTester tester, {
    int eventId = 1,
    String? eventTitle,
  }) async {
    await pumpApp(
      tester,
      TicketScannerScreen(eventId: eventId, eventTitle: eventTitle),
      overrides: [
        Provider<AppDatabase>.value(value: mockDb),
        Provider<SyncService>.value(value: mockSync),
        ChangeNotifierProvider<TicketProvider>.value(value: TicketProvider(mockTicketRepo)),
      ],
    );
  }

  group('TicketScannerScreen', () {
    testWidgets('renders title "Scan Tickets"', (tester) async {
      await pumpScanner(tester);
      await tester.pump();

      expect(find.text('Scan Tickets'), findsOneWidget);
    });

    testWidgets('shows event title when provided', (tester) async {
      await pumpScanner(tester, eventTitle: 'Rock Concert');
      await tester.pump();

      expect(find.text('Rock Concert'), findsOneWidget);
    });

    testWidgets('renders Customer and Sponsor mode tabs', (tester) async {
      await pumpScanner(tester);
      await tester.pump();

      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Sponsor'), findsOneWidget);
    });

    testWidgets('shows "Ready to scan" in info bar', (tester) async {
      await pumpScanner(tester);
      await tester.pump();

      expect(find.text('Point camera at QR code'), findsOneWidget);
      expect(find.text('Ready to scan'), findsOneWidget);
    });

    testWidgets('renders close, torch, and camera-switch buttons',
        (tester) async {
      await pumpScanner(tester);
      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.flash_off), findsOneWidget);
      expect(find.byIcon(Icons.cameraswitch_rounded), findsOneWidget);
    });

    testWidgets('renders QR scanner icon in info bar', (tester) async {
      await pumpScanner(tester);
      await tester.pump();

      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
    });
  });
}
