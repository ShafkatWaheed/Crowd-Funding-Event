import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/event.dart';
import '../../lib/models/user.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/services/api_service.dart';
import '../../lib/screens/event/event_detail/funding_card.dart';
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

    // Default: logged-in customer who is not organizer/admin
    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.customer));

    // Stub funding summary API
    when(() => mockApi.getFundingSummary(any())).thenAnswer((_) async => {
          'total_pledged_cents': 50000,
          'backers_count': 10,
          'goal_cents': 100000,
          'funding_commission_percent': 5,
          'total_reserved_spots': 3,
        });

    // Stub early bird discounts API
    when(() => mockApi.getEarlyBirdDiscounts(any()))
        .thenAnswer((_) async => []);
  });

  /// Helper to build the FundingCard within a provider-injected MaterialApp.
  Future<void> pumpFundingCard(
    WidgetTester tester, {
    Event? event,
    bool isRegistered = true,
  }) async {
    final ev = event ??
        makeEvent(
          id: 1,
          status: 'approved',
          fundingGoalCents: 100000,
          totalPledgedCents: 50000,
        );

    await pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: FundingCard(
            eventId: ev.id,
            event: ev,
            isRegistered: isRegistered,
          ),
        ),
      ),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        Provider<ApiService>.value(value: mockApi),
      ],
    );

    // Let FutureBuilder / initState settle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('FundingCard', () {
    testWidgets('renders funding progress bar', (tester) async {
      await pumpFundingCard(tester);

      // The card uses LinearProgressIndicator for the funding bar
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('renders pledge amount (total raised)', (tester) async {
      await pumpFundingCard(tester);

      // After API loads, the total pledged should be displayed.
      // The card shows _totalFormatted which is e.g. "\$500.00"
      expect(find.textContaining('\$500.00'), findsWidgets);
    });

    testWidgets('pledge button visible when canPledge', (tester) async {
      // Event with status approved and fundingEndAt set enables canPledge
      final ev = Event.fromJson(eventJson(
        id: 1,
        status: 'approved',
        fundingGoalCents: 100000,
        totalPledgedCents: 50000,
        fundingEndAt: DateTime.now()
            .toUtc()
            .add(const Duration(days: 7))
            .toIso8601String(),
      ));

      await pumpFundingCard(tester, event: ev, isRegistered: true);

      // The pledge button shows "Pledge" text for registered users
      expect(find.text('Pledge'), findsOneWidget);
    });

    testWidgets('pledge button hidden when cannot pledge', (tester) async {
      // Event with status that does not allow pledging (e.g. selling_tickets)
      final ev = Event.fromJson(eventJson(
        id: 1,
        status: 'selling_tickets',
        fundingGoalCents: 100000,
        totalPledgedCents: 50000,
      ));

      await pumpFundingCard(tester, event: ev);

      // canPledge is false so no Pledge/Donate button
      expect(find.text('Pledge'), findsNothing);
      expect(find.text('Donate'), findsNothing);
    });

    testWidgets('unpledge button visible when registered and canPledge',
        (tester) async {
      final ev = Event.fromJson(eventJson(
        id: 1,
        status: 'approved',
        fundingGoalCents: 100000,
        totalPledgedCents: 50000,
        fundingEndAt: DateTime.now()
            .toUtc()
            .add(const Duration(days: 7))
            .toIso8601String(),
      ));

      await pumpFundingCard(tester, event: ev, isRegistered: true);

      // Unpledge button is shown for registered users when canPledge is true
      expect(find.text('Unpledge'), findsOneWidget);
    });

    testWidgets('funding goal displayed', (tester) async {
      await pumpFundingCard(tester);

      // The goal is shown via _goalFormatted (format may or may not use commas)
      expect(find.textContaining('\$1000'), findsWidgets);
    });

    testWidgets('pledged amount displayed after API load', (tester) async {
      // After the funding summary API returns, the raised amount is updated
      when(() => mockApi.getFundingSummary(any())).thenAnswer((_) async => {
            'total_pledged_cents': 75000,
            'backers_count': 15,
            'goal_cents': 100000,
            'funding_commission_percent': 5,
            'total_reserved_spots': 0,
          });

      final ev = Event.fromJson(eventJson(
        id: 1,
        status: 'approved',
        fundingGoalCents: 100000,
        totalPledgedCents: 0,
      ));

      await pumpFundingCard(tester, event: ev);

      // After API settles, the amount should reflect the API response
      expect(find.textContaining('\$750.00'), findsWidgets);
    });
  });
}
