import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/funding.dart';
import '../../lib/models/user.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/providers/pledge_provider.dart';
import '../../lib/repositories/base_repository.dart';
import '../../lib/repositories/funding_repository.dart';
import '../../lib/screens/profile/my_pledges_screen.dart';
import '../helpers/mock_providers.dart';
import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

class MockFundingRepository extends Mock implements FundingRepository {}

void main() {
  late MockAuthProvider mockAuth;
  late MockFundingRepository mockFundingRepo;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockFundingRepo = MockFundingRepository();

    // Default: logged-in customer
    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.customer));
  });

  Pledge _makePledge({
    int id = 1,
    int eventId = 10,
    int amountCents = 2000,
    String status = 'pledged',
    String? eventTitle,
    String? receiptNumber,
  }) {
    return Pledge(
      id: id,
      eventId: eventId,
      userId: 1,
      amountCents: amountCents,
      status: PledgeStatus.values.firstWhere(
        (s) => s.name == status,
        orElse: () => PledgeStatus.pledged,
      ),
      createdAt: DateTime.now(),
      eventTitle: eventTitle,
      receiptNumber: receiptNumber,
    );
  }

  /// Helper to pump MyPledgesScreen with injected providers.
  Future<void> pumpMyPledges(WidgetTester tester) async {
    final provider = PledgeProvider(mockFundingRepo);

    await pumpApp(
      tester,
      const MyPledgesScreen(),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<PledgeProvider>.value(value: provider),
      ],
    );
  }

  group('MyPledgesScreen', () {
    testWidgets('renders pledge list after load', (tester) async {
      when(() => mockFundingRepo.getMyPledges(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) async => PaginatedResult(
            items: [
              _makePledge(id: 1, eventId: 10, amountCents: 2000, eventTitle: 'Music Fest'),
              _makePledge(id: 2, eventId: 10, amountCents: 3000, eventTitle: 'Music Fest'),
            ],
            hasMore: false,
          ));

      await pumpMyPledges(tester);
      await tester.pumpAndSettle();

      // The pledges are grouped by event; should see the event title
      expect(find.text('Music Fest'), findsWidgets);
      // Should see pledge card content (amount display)
      expect(find.textContaining('\$20.00'), findsWidgets);
    });

    testWidgets('sort chip selection exists', (tester) async {
      when(() => mockFundingRepo.getMyPledges(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) async => PaginatedResult(
            items: [_makePledge(id: 1, eventId: 10, amountCents: 2000, eventTitle: 'Test')],
            hasMore: false,
          ));

      await pumpMyPledges(tester);
      await tester.pumpAndSettle();

      // Sort chips: Newest, Oldest, Amount up, Amount down
      expect(find.text('Newest'), findsOneWidget);
      expect(find.text('Oldest'), findsOneWidget);
      // ChoiceChip widgets used for sorting
      expect(find.byType(ChoiceChip), findsWidgets);
    });

    testWidgets('empty state message when no pledges', (tester) async {
      when(() => mockFundingRepo.getMyPledges(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) async => PaginatedResult(items: [], hasMore: false));

      await pumpMyPledges(tester);
      await tester.pumpAndSettle();

      expect(find.text('No pledges yet'), findsOneWidget);
      expect(find.text('Pledges you make will appear here'), findsOneWidget);
    });

    testWidgets('screen title shown', (tester) async {
      when(() => mockFundingRepo.getMyPledges(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) async => PaginatedResult(items: [], hasMore: false));

      await pumpMyPledges(tester);
      await tester.pumpAndSettle();

      // The screen title should be visible
      expect(find.text('My Pledges'), findsOneWidget);
    });

    testWidgets('pledge card shows amount and status', (tester) async {
      when(() => mockFundingRepo.getMyPledges(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) async => PaginatedResult(
            items: [
              _makePledge(
                id: 1,
                eventId: 10,
                amountCents: 5000,
                status: 'pledged',
                eventTitle: 'Concert',
                receiptNumber: 'REC-123',
              ),
            ],
            hasMore: false,
          ));

      await pumpMyPledges(tester);
      await tester.pumpAndSettle();

      // Pledge card displays amount formatted as $50.00
      expect(find.textContaining('\$50.00'), findsWidgets);
      // Status label "PLEDGED" shown in the card header badge
      expect(find.text('PLEDGED'), findsOneWidget);
      // Receipt number displayed in the card
      expect(find.text('REC-123'), findsOneWidget);
    });
  });
}
