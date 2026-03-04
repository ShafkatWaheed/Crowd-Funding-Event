import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/sponsor.dart';
import '../../lib/providers/sponsor_provider.dart';
import '../../lib/repositories/sponsor_repository.dart';
import '../../lib/screens/sponsor/organizer_sponsors_screen.dart';
import '../helpers/mock_sponsor_repository.dart';
import '../helpers/pump_app.dart';

void main() {
  late MockSponsorRepository mockSponsorRepo;

  setUp(() {
    mockSponsorRepo = MockSponsorRepository();
  });

  OrganizerSponsorItem makeSponsor({
    int sponsorUserId = 1,
    String companyName = 'Acme Corp',
    String contactName = 'Alice',
    int totalBids = 3,
    int totalAmountCents = 50000,
    String? logoUrl,
  }) =>
      OrganizerSponsorItem.fromJson({
        'sponsor_user_id': sponsorUserId,
        'company_name': companyName,
        'contact_name': contactName,
        'total_bids': totalBids,
        'total_amount_cents': totalAmountCents,
        'logo_url': logoUrl,
      });

  void stubSponsors({List<OrganizerSponsorItem>? data}) {
    when(() => mockSponsorRepo.getOrganizerSponsors(
          eventStatus: any(named: 'eventStatus'),
          genre: any(named: 'genre'),
          eventId: any(named: 'eventId'),
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => data ?? []);
  }

  Future<void> pumpScreen(WidgetTester tester, {int? eventId}) async {
    await pumpApp(
      tester,
      OrganizerSponsorsScreen(eventId: eventId),
      overrides: [ChangeNotifierProvider<SponsorProvider>.value(value: SponsorProvider(mockSponsorRepo))],
    );
  }

  group('OrganizerSponsorsScreen', () {
    testWidgets('shows title', (tester) async {
      stubSponsors();
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('My Sponsors'), findsOneWidget);
    });

    testWidgets('renders sponsor cards with company name and bids',
        (tester) async {
      stubSponsors(data: [
        makeSponsor(companyName: 'Acme Corp', contactName: 'Alice', totalBids: 3, totalAmountCents: 50000),
        makeSponsor(sponsorUserId: 2, companyName: 'Beta Inc', contactName: 'Bob', totalBids: 1, totalAmountCents: 10000),
      ]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Acme Corp'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('3 bids'), findsOneWidget);
      expect(find.text('Beta Inc'), findsOneWidget);
      expect(find.text('1 bid'), findsOneWidget);
      expect(find.text('2 sponsors'), findsOneWidget);
    });

    testWidgets('shows empty state when no sponsors', (tester) async {
      stubSponsors(data: []);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('No sponsors yet'), findsOneWidget);
    });

    testWidgets('search filters sponsors by name', (tester) async {
      stubSponsors(data: [
        makeSponsor(companyName: 'Acme Corp'),
        makeSponsor(sponsorUserId: 2, companyName: 'Beta Inc'),
      ]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'beta');
      await tester.pump();

      expect(find.text('Acme Corp'), findsNothing);
      expect(find.text('Beta Inc'), findsOneWidget);
      expect(find.text('1 sponsor'), findsOneWidget);
    });

    testWidgets('search shows "No sponsors match" when no results',
        (tester) async {
      stubSponsors(data: [
        makeSponsor(companyName: 'Acme Corp'),
      ]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzzzz');
      await tester.pump();

      expect(find.text('No sponsors match your search'), findsOneWidget);
    });

    testWidgets('shows sponsor amount', (tester) async {
      stubSponsors(data: [
        makeSponsor(totalAmountCents: 75000),
      ]);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('\$750.00'), findsOneWidget);
    });
  });
}
