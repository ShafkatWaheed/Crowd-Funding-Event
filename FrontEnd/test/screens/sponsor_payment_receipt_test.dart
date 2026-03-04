import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/sponsor.dart';
import '../../lib/providers/sponsor_provider.dart';
import '../../lib/repositories/sponsor_repository.dart';
import '../../lib/screens/sponsor/sponsor_payment_receipt_screen.dart';
import '../helpers/mock_sponsor_repository.dart';
import '../helpers/pump_app.dart';

void main() {
  late MockSponsorRepository mockSponsorRepo;

  setUp(() {
    mockSponsorRepo = MockSponsorRepository();
  });

  SponsorPaymentReceipt makeReceipt({
    String type = 'payment',
    String receiptNumber = 'REC-SP-001',
    int amountCents = 50000,
    int platformCutCents = 5000,
    int netToOrganizerCents = 45000,
    int taxCents = 0,
    double taxRate = 0.0,
    String status = 'completed',
    String categoryName = 'Gold Sponsor',
    String eventTitle = 'Rock Concert',
    String? sponsorName = 'Acme Corp',
    String createdAt = '2025-02-01T10:00:00',
    String? eventStartTime,
    String? venueName,
    String? venueCity,
  }) =>
      SponsorPaymentReceipt.fromJson({
        'payment_id': 1,
        'receipt_number': receiptNumber,
        'type': type,
        'amount_cents': amountCents,
        'platform_cut_cents': platformCutCents,
        'net_to_organizer_cents': netToOrganizerCents,
        'subtotal_cents': amountCents,
        'tax_cents': taxCents,
        'tax_rate': taxRate,
        'status': status,
        'category_name': categoryName,
        'event_title': eventTitle,
        'sponsor_name': sponsorName,
        'created_at': createdAt,
        'event_start_time': eventStartTime,
        'venue_name': venueName,
        'venue_city': venueCity,
        'bid_id': 1,
        'bid_amount_cents': amountCents,
      });

  Future<void> pumpReceipt(WidgetTester tester) async {
    await pumpApp(
      tester,
      const SponsorPaymentReceiptScreen(paymentId: 1),
      overrides: [ChangeNotifierProvider<SponsorProvider>.value(value: SponsorProvider(mockSponsorRepo))],
    );
  }

  group('SponsorPaymentReceiptScreen', () {
    testWidgets('shows loading then renders payment receipt', (tester) async {
      when(() => mockSponsorRepo.getSponsorPaymentReceipt(1))
          .thenAnswer((_) async => makeReceipt());

      await pumpReceipt(tester);
      await tester.pumpAndSettle();

      expect(find.text('Payment Receipt'), findsOneWidget);
      expect(find.text('Payment Confirmed'), findsOneWidget);
      expect(find.text('REC-SP-001'), findsOneWidget);
      expect(find.text('Rock Concert'), findsOneWidget);
      expect(find.text('Gold Sponsor'), findsWidgets);
      expect(find.text('Acme Corp'), findsOneWidget);
    });

    testWidgets('shows fee breakdown', (tester) async {
      when(() => mockSponsorRepo.getSponsorPaymentReceipt(1)).thenAnswer((_) async =>
          makeReceipt(
            amountCents: 50000,
            platformCutCents: 5000,
            netToOrganizerCents: 45000,
          ));

      await pumpReceipt(tester);
      await tester.pumpAndSettle();

      expect(find.text('FEE BREAKDOWN'), findsOneWidget);
      expect(find.text('\$500.00'), findsWidgets);
      expect(find.text('\$50.00'), findsWidgets);
      expect(find.text('\$450.00'), findsOneWidget);
    });

    testWidgets('shows refund receipt with refund UI', (tester) async {
      when(() => mockSponsorRepo.getSponsorPaymentReceipt(1)).thenAnswer((_) async =>
          makeReceipt(type: 'refund', amountCents: 30000));

      await pumpReceipt(tester);
      await tester.pumpAndSettle();

      expect(find.text('Refund Receipt'), findsOneWidget);
      expect(find.text('Refund Processed'), findsOneWidget);
      expect(find.textContaining('refunded'), findsOneWidget);
    });

    testWidgets('shows error state with retry', (tester) async {
      when(() => mockSponsorRepo.getSponsorPaymentReceipt(1))
          .thenThrow(Exception('Network error'));

      await pumpReceipt(tester);
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows copy receipt number button', (tester) async {
      when(() => mockSponsorRepo.getSponsorPaymentReceipt(1))
          .thenAnswer((_) async => makeReceipt());

      await pumpReceipt(tester);
      await tester.pumpAndSettle();

      expect(find.text('Copy Receipt Number'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('renders receipt even when venue fields are set', (tester) async {
      when(() => mockSponsorRepo.getSponsorPaymentReceipt(1)).thenAnswer(
          (_) async => makeReceipt(venueName: 'Grand Hall', venueCity: 'NYC'));

      await pumpReceipt(tester);
      await tester.pumpAndSettle();

      // Screen renders the receipt normally — venue fields are stored
      // on the model but not currently displayed in the receipt UI.
      expect(find.text('Payment Confirmed'), findsOneWidget);
      expect(find.text('Rock Concert'), findsOneWidget);
    });

    testWidgets('shows tax when present', (tester) async {
      when(() => mockSponsorRepo.getSponsorPaymentReceipt(1)).thenAnswer(
          (_) async => makeReceipt(taxCents: 2500, taxRate: 5.0));

      await pumpReceipt(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('Tax'), findsOneWidget);
      expect(find.text('\$25.00'), findsWidgets);
    });
  });
}
