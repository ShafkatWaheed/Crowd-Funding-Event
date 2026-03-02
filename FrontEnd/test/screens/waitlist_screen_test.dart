import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/providers/event_provider.dart';
import '../../lib/services/api_service.dart';
import '../../lib/screens/event/waitlist_screen.dart';
import '../helpers/mock_api_service.dart';
import '../helpers/mock_providers.dart';
import '../helpers/pump_app.dart';

void main() {
  late MockApiService mockApi;
  late MockEventProvider mockEvent;

  setUp(() {
    mockApi = MockApiService();
    mockEvent = MockEventProvider();

    // EventProvider.loadEvent is fire-and-forget; just stub it.
    when(() => mockEvent.loadEvent(any())).thenAnswer((_) async {});
  });

  Map<String, dynamic> capInfo({
    int maxCapacity = 100,
    int ticketsSold = 40,
    int totalReservedSpots = 10,
    int registrationCount = 5,
  }) =>
      {
        'max_capacity': maxCapacity,
        'tickets_sold': ticketsSold,
        'total_reserved_spots': totalReservedSpots,
        'registration_count': registrationCount,
      };

  Map<String, dynamic> fundReg({
    int id = 1,
    int userId = 100,
    String status = 'waitlist',
  }) =>
      {'id': id, 'user_id': userId, 'status': status};

  Map<String, dynamic> ticketWait({
    int id = 1,
    int userId = 200,
    int amountPaidCents = 5000,
    Map<String, dynamic>? tier,
    String? ticketCode,
  }) =>
      {
        'id': id,
        'user_id': userId,
        'amount_paid_cents': amountPaidCents,
        'tier': tier ?? {'name': 'General'},
        'ticket_code': ticketCode ?? 'TKT-$id',
      };

  void stubAll({
    List<dynamic>? regs,
    List<dynamic>? tickets,
    Map<String, dynamic>? cap,
  }) {
    when(() => mockApi.getRegistrations(any()))
        .thenAnswer((_) async => regs ?? []);
    when(() => mockApi.getWaitlistedTickets(any()))
        .thenAnswer((_) async => tickets ?? []);
    when(() => mockApi.getCapacityInfo(any()))
        .thenAnswer((_) async => cap ?? capInfo());
  }

  Future<void> pumpWaitlist(
    WidgetTester tester, {
    bool initialTicketView = false,
  }) async {
    await pumpApp(
      tester,
      WaitlistScreen(eventId: 1, initialTicketView: initialTicketView),
      overrides: [
        Provider<ApiService>.value(value: mockApi),
        ChangeNotifierProvider<EventProvider>.value(value: mockEvent),
      ],
    );
  }

  group('WaitlistScreen — loading & error', () {
    testWidgets('shows shimmer while loading', (tester) async {
      final completer = Completer<List<dynamic>>();
      when(() => mockApi.getRegistrations(any()))
          .thenAnswer((_) => completer.future);
      when(() => mockApi.getWaitlistedTickets(any()))
          .thenAnswer((_) async => []);
      when(() => mockApi.getCapacityInfo(any()))
          .thenAnswer((_) async => capInfo());

      await pumpWaitlist(tester);
      await tester.pump();

      // ShimmerListTile is the loading placeholder
      expect(find.text('Waitlist'), findsOneWidget);

      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('shows error state with retry button', (tester) async {
      when(() => mockApi.getRegistrations(any()))
          .thenThrow(Exception('Network error'));
      when(() => mockApi.getWaitlistedTickets(any()))
          .thenAnswer((_) async => []);
      when(() => mockApi.getCapacityInfo(any()))
          .thenAnswer((_) async => capInfo());

      await pumpWaitlist(tester);
      await tester.pumpAndSettle();

      expect(find.text('Failed to load'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('WaitlistScreen — Fund Waitlist tab', () {
    testWidgets('renders fund waitlist cards', (tester) async {
      stubAll(regs: [
        fundReg(id: 1, userId: 100),
        fundReg(id: 2, userId: 101),
      ]);

      await pumpWaitlist(tester);
      await tester.pumpAndSettle();

      expect(find.text('Fund Waitlist'), findsOneWidget);
      expect(find.text('Ticket Waitlist'), findsOneWidget);
      expect(find.text('User #100'), findsOneWidget);
      expect(find.text('User #101'), findsOneWidget);
      expect(find.text('Registration #1'), findsOneWidget);
      expect(find.text('Registration #2'), findsOneWidget);
    });

    testWidgets('shows waiting approval count', (tester) async {
      stubAll(regs: [
        fundReg(id: 1, userId: 100),
        fundReg(id: 2, userId: 101),
        fundReg(id: 3, userId: 102),
      ]);

      await pumpWaitlist(tester);
      await tester.pumpAndSettle();

      expect(find.text('3 waiting approval'), findsOneWidget);
    });

    testWidgets('shows empty state when no fund waitlist', (tester) async {
      stubAll(regs: [], cap: capInfo());

      await pumpWaitlist(tester);
      await tester.pumpAndSettle();

      expect(find.text('No pending fund waitlist requests'), findsOneWidget);
    });

    testWidgets('filters by non-waitlist status', (tester) async {
      // Only 'waitlist' status registrations should appear
      stubAll(regs: [
        fundReg(id: 1, userId: 100, status: 'waitlist'),
        fundReg(id: 2, userId: 101, status: 'approved'),
      ]);

      await pumpWaitlist(tester);
      await tester.pumpAndSettle();

      expect(find.text('User #100'), findsOneWidget);
      // approved registration is filtered out
      expect(find.text('User #101'), findsNothing);
    });

    testWidgets('approve button calls decideRegistration', (tester) async {
      stubAll(regs: [fundReg(id: 42, userId: 100)]);
      when(() => mockApi.decideRegistration(1, 42, 'approve'))
          .thenAnswer((_) async => {});

      await pumpWaitlist(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      verify(() => mockApi.decideRegistration(1, 42, 'approve')).called(1);
    });

    testWidgets('reject button calls decideRegistration', (tester) async {
      stubAll(regs: [fundReg(id: 42, userId: 100)]);
      when(() => mockApi.decideRegistration(1, 42, 'reject'))
          .thenAnswer((_) async => {});

      await pumpWaitlist(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      verify(() => mockApi.decideRegistration(1, 42, 'reject')).called(1);
    });

    testWidgets('search filters fund waitlist by user ID', (tester) async {
      stubAll(regs: [
        fundReg(id: 1, userId: 100),
        fundReg(id: 2, userId: 201),
      ]);

      await pumpWaitlist(tester);
      await tester.pumpAndSettle();

      expect(find.text('User #100'), findsOneWidget);
      expect(find.text('User #201'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '201');
      await tester.pump();

      expect(find.text('User #100'), findsNothing);
      expect(find.text('User #201'), findsOneWidget);
    });
  });

  group('WaitlistScreen — Ticket Waitlist tab', () {
    testWidgets('switches to ticket waitlist tab', (tester) async {
      stubAll(
        regs: [fundReg(id: 1, userId: 100)],
        tickets: [ticketWait(id: 10, userId: 200)],
      );

      await pumpWaitlist(tester);
      await tester.pumpAndSettle();

      // Switch tab
      await tester.tap(find.text('Ticket Waitlist'));
      await tester.pump();

      expect(find.text('User #200'), findsOneWidget);
      expect(find.textContaining('General'), findsWidgets);
    });

    testWidgets('opens on ticket tab when initialTicketView is true',
        (tester) async {
      stubAll(
        regs: [],
        tickets: [ticketWait(id: 10, userId: 300)],
      );

      await pumpWaitlist(tester, initialTicketView: true);
      await tester.pumpAndSettle();

      expect(find.text('User #300'), findsOneWidget);
    });

    testWidgets('shows empty state for ticket waitlist', (tester) async {
      stubAll(regs: [], tickets: []);

      await pumpWaitlist(tester, initialTicketView: true);
      await tester.pumpAndSettle();

      expect(find.text('No tickets waiting approval'), findsOneWidget);
    });

    testWidgets('approve ticket calls approveWaitlistedTicket',
        (tester) async {
      stubAll(tickets: [ticketWait(id: 55, userId: 300)]);
      when(() => mockApi.approveWaitlistedTicket(1, 55))
          .thenAnswer((_) async => {});

      await pumpWaitlist(tester, initialTicketView: true);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      verify(() => mockApi.approveWaitlistedTicket(1, 55)).called(1);
    });

    testWidgets('reject ticket calls rejectWaitlistedTicket', (tester) async {
      stubAll(tickets: [ticketWait(id: 55, userId: 300)]);
      when(() => mockApi.rejectWaitlistedTicket(1, 55))
          .thenAnswer((_) async => {});

      await pumpWaitlist(tester, initialTicketView: true);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      verify(() => mockApi.rejectWaitlistedTicket(1, 55)).called(1);
    });

    testWidgets('search filters ticket waitlist by tier name', (tester) async {
      stubAll(tickets: [
        ticketWait(id: 1, userId: 200, tier: {'name': 'General'}),
        ticketWait(id: 2, userId: 201, tier: {'name': 'VIP'}),
      ]);

      await pumpWaitlist(tester, initialTicketView: true);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'VIP');
      await tester.pump();

      expect(find.text('User #200'), findsNothing);
      expect(find.text('User #201'), findsOneWidget);
    });
  });

  group('WaitlistScreen — Capacity bar', () {
    testWidgets('renders capacity bar with correct numbers', (tester) async {
      stubAll(
        regs: [fundReg(id: 1, userId: 100)],
        cap: capInfo(
          maxCapacity: 200,
          ticketsSold: 80,
          totalReservedSpots: 20,
          registrationCount: 10,
        ),
      );

      await pumpWaitlist(tester);
      await tester.pumpAndSettle();

      expect(find.text('Capacity'), findsOneWidget);
      expect(find.text('100 / 200 occupied'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows "If approved" preview on fund card', (tester) async {
      stubAll(
        regs: [fundReg(id: 1, userId: 100)],
        cap: capInfo(registrationCount: 5, maxCapacity: 200),
      );

      await pumpWaitlist(tester);
      await tester.pumpAndSettle();

      // registrationCount + 1 = 6
      expect(find.text('If approved: Registered 6 / 200'), findsOneWidget);
    });
  });
}
