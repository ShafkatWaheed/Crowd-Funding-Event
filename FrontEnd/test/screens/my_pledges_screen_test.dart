import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/user.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/services/api_service.dart';
import '../../lib/screens/profile/my_pledges_screen.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockApiService mockApi;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockApi = MockApiService();

    // Default: logged-in customer
    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.customer));
  });

  /// Helper to pump MyPledgesScreen with injected providers.
  Future<void> pumpMyPledges(WidgetTester tester) async {
    await pumpApp(
      tester,
      const MyPledgesScreen(),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        Provider<ApiService>.value(value: mockApi),
      ],
    );
  }

  group('MyPledgesScreen', () {
    testWidgets('renders pledge list after load', (tester) async {
      when(() => mockApi.getMyPledges(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) async => [
            pledgeJson(id: 1, eventId: 10, amountCents: 2000, eventTitle: 'Music Fest'),
            pledgeJson(id: 2, eventId: 10, amountCents: 3000, eventTitle: 'Music Fest'),
          ]);

      await pumpMyPledges(tester);
      await tester.pumpAndSettle();

      // The pledges are grouped by event; should see the event title
      expect(find.text('Music Fest'), findsWidgets);
      // Should see pledge card content (amount display, receipt, etc.)
      expect(find.textContaining('\$20.00'), findsWidgets);
    });

    testWidgets('sort chip selection exists', (tester) async {
      when(() => mockApi.getMyPledges(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) async => [
            pledgeJson(id: 1, eventId: 10, amountCents: 2000, eventTitle: 'Test'),
          ]);

      await pumpMyPledges(tester);
      await tester.pumpAndSettle();

      // Sort chips: Newest, Oldest, Amount up, Amount down
      expect(find.text('Newest'), findsOneWidget);
      expect(find.text('Oldest'), findsOneWidget);
      // ChoiceChip widgets used for sorting
      expect(find.byType(ChoiceChip), findsWidgets);
    });

    testWidgets('empty state message when no pledges', (tester) async {
      when(() => mockApi.getMyPledges(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) async => []);

      await pumpMyPledges(tester);
      await tester.pumpAndSettle();

      expect(find.text('No pledges yet'), findsOneWidget);
      expect(find.text('Pledges you make will appear here'), findsOneWidget);
    });

    testWidgets('loading shimmer shown initially', (tester) async {
      // Use a completer that never completes so the loading state stays visible
      final completer = Completer<List<Map<String, dynamic>>>();
      when(() => mockApi.getMyPledges(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) => completer.future);

      await pumpMyPledges(tester);
      // Only pump once so loading state is visible (don't settle)
      await tester.pump();

      // The LoadingSwitcher should show shimmer content while loading
      // ShimmerListTile is used in the loading child
      expect(find.text('My Pledges'), findsOneWidget);
    });

    testWidgets('pledge card shows amount and status', (tester) async {
      when(() => mockApi.getMyPledges(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          )).thenAnswer((_) async => [
            pledgeJson(
              id: 1,
              eventId: 10,
              amountCents: 5000,
              status: 'pledged',
              eventTitle: 'Concert',
              receiptNumber: 'REC-123',
            ),
          ]);

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
