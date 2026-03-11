import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:crowd_funding_app/models/event.dart';
import 'package:crowd_funding_app/models/funding.dart';
import 'package:crowd_funding_app/models/user.dart';
import 'package:crowd_funding_app/providers/auth_provider.dart';
import 'package:crowd_funding_app/providers/event_provider.dart';
import 'package:crowd_funding_app/providers/pledge_provider.dart';
import 'package:crowd_funding_app/providers/ticket_provider.dart';
import 'package:crowd_funding_app/screens/event/event_detail/funding_card.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_funding_repository.dart';
import '../helpers/mock_ticket_repository.dart';
import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockEventProvider mockEventProvider;
  late MockFundingRepository mockFundingRepo;
  late MockTicketRepository mockTicketRepo;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockEventProvider = MockEventProvider();
    mockFundingRepo = MockFundingRepository();
    mockTicketRepo = MockTicketRepository();

    // EventProvider stubs needed by FundingCard._loadMilestones / register / unregister
    when(() => mockEventProvider.getMilestones(any())).thenAnswer((_) async => []);
    when(() => mockEventProvider.register(any())).thenAnswer(
      (_) async => Registration.fromJson({'id': 1, 'event_id': 1, 'user_id': 1, 'status': 'registered', 'created_at': DateTime.now().toIso8601String()}),
    );
    when(() => mockEventProvider.unregister(any())).thenAnswer(
      (_) async => UnregisterResult(),
    );
    when(() => mockEventProvider.addListener(any())).thenReturn(null);
    when(() => mockEventProvider.removeListener(any())).thenReturn(null);

    // Default: logged-in customer who is not organizer/admin
    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.customer));

    // Stub funding summary via FundingRepository
    when(() => mockFundingRepo.getFundingSummary(any())).thenAnswer((_) async =>
        FundingSummary.fromJson({
          'total_pledged_cents': 50000,
          'backers_count': 10,
          'goal_cents': 100000,
          'funding_commission_percent': 5,
          'total_reserved_spots': 3,
        }));

    // Stub early bird discounts via TicketRepository
    when(() => mockTicketRepo.getEarlyBirdDiscounts(any()))
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
        ChangeNotifierProvider<EventProvider>.value(value: mockEventProvider),
        ChangeNotifierProvider<PledgeProvider>.value(value: PledgeProvider(mockFundingRepo)),
        ChangeNotifierProvider<TicketProvider>.value(value: TicketProvider(mockTicketRepo)),
      ],
    );

    // Let FutureBuilder / initState settle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('FundingCard', () {
    testWidgets('renders funding progress bar', (tester) async {
      await pumpFundingCard(tester);

      // The card uses a custom arc painter (CustomPaint) — check the percentage is shown
      expect(find.textContaining('50%'), findsOneWidget);
    });

    testWidgets('renders pledge amount (total raised)', (tester) async {
      await pumpFundingCard(tester);

      // After API loads, the total pledged should be displayed.
      // The card renders the dollar sign and the amount in separate Text widgets.
      // 50000 cents = $500 → rendered as Text('500')
      expect(find.text('500'), findsWidgets);
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

      // The pledge button shows "Back this Event" for registered users
      expect(find.text('Back this Event'), findsOneWidget);
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

      // canPledge is false so no pledge/donate buttons
      expect(find.text('Back this Event'), findsNothing);
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

      // Unpledge link is shown for registered users when canPledge is true
      expect(find.textContaining('Remove my pledge'), findsOneWidget);
    });

    testWidgets('funding goal displayed', (tester) async {
      await pumpFundingCard(tester);

      // The goal is shown via _goalFormatted (format may or may not use commas)
      expect(find.textContaining('\$1000'), findsWidgets);
    });

    testWidgets('pledged amount displayed after API load', (tester) async {
      // After the funding summary API returns, the raised amount is updated
      when(() => mockFundingRepo.getFundingSummary(any())).thenAnswer((_) async =>
          FundingSummary.fromJson({
            'total_pledged_cents': 75000,
            'backers_count': 15,
            'goal_cents': 100000,
            'funding_commission_percent': 5,
            'total_reserved_spots': 0,
          }));

      final ev = Event.fromJson(eventJson(
        id: 1,
        status: 'approved',
        fundingGoalCents: 100000,
        totalPledgedCents: 0,
      ));

      await pumpFundingCard(tester, event: ev);

      // After API settles, the amount should reflect the API response
      // 75000 cents = $750 → rendered as Text('750') with separate '$' widget
      expect(find.text('750'), findsWidgets);
    });
  });

  group('FundingCard — optimistic state update after unpledge', () {
    /// Event that has canPledge == true (approved + fundingEndAt set).
    Event pledgableEvent() => Event.fromJson(eventJson(
          id: 1,
          status: 'approved',
          fundingGoalCents: 100000,
          totalPledgedCents: 0,
          fundingEndAt: DateTime.now()
              .toUtc()
              .add(const Duration(days: 7))
              .toIso8601String(),
        ));

    testWidgets(
        'total pledged decreases immediately after unpledge without waiting for background reload',
        (tester) async {
      // First call (initState _loadFunding) → resolves immediately with 50000
      // Second call (background sync after unpledge) → blocked via completer
      var fundingCallCount = 0;
      final backgroundCompleter = Completer<FundingSummary>();

      when(() => mockFundingRepo.getFundingSummary(any()))
          .thenAnswer((_) async {
        fundingCallCount++;
        if (fundingCallCount == 1) {
          return FundingSummary.fromJson(fundingSummaryJson(
            totalPledgedCents: 50000,
            backersCount: 10,
          ));
        }
        // Second call blocks — simulates slow background refresh
        return backgroundCompleter.future;
      });

      when(() => mockFundingRepo.unpledge(any()))
          .thenAnswer((_) async => UnpledgeResult(
                unpledgedAmountCents: 20000,
                remainingPledges: 0,
                refundedCents: 20000,
                status: 'completed',
              ));

      await pumpFundingCard(tester, event: pledgableEvent(), isRegistered: true);
      // Initial state: $500 raised (50000 cents → '500' in separate Text widget)
      expect(find.text('500'), findsWidgets);

      // Tap the card's "Remove my pledge" TextButton link.
      // The dialog confirm button also shows "Unpledge" text, so be specific.
      await tester.tap(find.text('Remove my pledge'));
      await tester.pump(); // show confirmation dialog

      // Dialog confirm button is an ElevatedButton labelled "Unpledge"
      await tester.tap(find.widgetWithText(ElevatedButton, 'Unpledge'));
      await tester.pump(); // execute unpledge
      await tester.pump(const Duration(milliseconds: 50)); // settle setState

      // Optimistic update: 50000 - 20000 = 30000 → $300 (rendered as Text('300'))
      // Background _loadFunding() is still blocked, so this verifies the
      // immediate setState, not the eventual API response.
      expect(find.text('300'), findsWidgets);

      // Unblock the background refresh so the test can clean up
      backgroundCompleter.complete(FundingSummary.fromJson(
          fundingSummaryJson(totalPledgedCents: 30000, backersCount: 9)));
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
        'backers count decreases immediately when user has no remaining pledges',
        (tester) async {
      var fundingCallCount = 0;
      final backgroundCompleter = Completer<FundingSummary>();

      when(() => mockFundingRepo.getFundingSummary(any()))
          .thenAnswer((_) async {
        fundingCallCount++;
        if (fundingCallCount == 1) {
          return FundingSummary.fromJson(fundingSummaryJson(
            totalPledgedCents: 50000,
            backersCount: 10,
          ));
        }
        return backgroundCompleter.future;
      });

      when(() => mockFundingRepo.unpledge(any()))
          .thenAnswer((_) async => UnpledgeResult(
                unpledgedAmountCents: 20000,
                remainingPledges: 0, // user has no pledges left → remove from backers
                refundedCents: 20000,
                status: 'completed',
              ));

      await pumpFundingCard(tester, event: pledgableEvent(), isRegistered: true);
      // Initial: 10 backers — rendered as Text('10') + separate Text('Backers') label
      expect(find.text('10'), findsOneWidget);

      await tester.tap(find.text('Remove my pledge'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Unpledge'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Optimistic update: 10 - 1 = 9 backers
      expect(find.text('9'), findsOneWidget);
      expect(find.text('10'), findsNothing);

      backgroundCompleter.complete(FundingSummary.fromJson(
          fundingSummaryJson(totalPledgedCents: 30000, backersCount: 9)));
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
