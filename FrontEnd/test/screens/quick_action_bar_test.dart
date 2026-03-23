/// Widget tests for QuickActionBar.
///
/// Covers:
///   - Button label rendering (Register / Registered / Waiting Approval)
///   - Immediate callback invocation after register/unregister — the fix for
///     the stale-UI bug where the screen required a manual refresh to show the
///     updated button state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:crowd_funding_app/models/event.dart';
import 'package:crowd_funding_app/models/user.dart';
import 'package:crowd_funding_app/providers/auth_provider.dart';
import 'package:crowd_funding_app/providers/event_provider.dart';
import 'package:crowd_funding_app/screens/event/event_detail/quick_action_bar.dart';
import '../helpers/mock_providers.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockEventProvider mockEvent;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockEvent = MockEventProvider();

    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.customer));
    when(() => mockAuth.addListener(any())).thenReturn(null);
    when(() => mockAuth.removeListener(any())).thenReturn(null);

    // selectedEvent used in _unregister() for refund eligibility check
    when(() => mockEvent.selectedEvent).thenReturn(null);
    // loadEvent is called after register/unregister for a background refresh
    when(() => mockEvent.loadEvent(any(),
            forceRefresh: any(named: 'forceRefresh'),
            shareToken: any(named: 'shareToken')))
        .thenAnswer((_) async {});
    when(() => mockEvent.addListener(any())).thenReturn(null);
    when(() => mockEvent.removeListener(any())).thenReturn(null);
  });

  /// Event with `canUnregister == true` (status approved) and a funding
  /// deadline so the widget renders correctly.
  Event makeApprovedEvent() => Event.fromJson(eventJson(
        id: 1,
        status: 'approved',
        fundingEndAt: DateTime.now()
            .toUtc()
            .add(const Duration(days: 7))
            .toIso8601String(),
      ));

  Future<void> pumpBar(
    WidgetTester tester, {
    required bool isRegistered,
    String? regStatus,
    required void Function(bool, String?) onChanged,
    Event? event,
  }) async {
    await pumpApp(
      tester,
      Scaffold(
        body: QuickActionBar(
          event: event ?? makeApprovedEvent(),
          isRegistered: isRegistered,
          regStatus: regStatus,
          onRegistrationChanged: onChanged,
        ),
      ),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<EventProvider>.value(value: mockEvent),
      ],
    );
    await tester.pump();
  }

  group('QuickActionBar — button labels', () {
    testWidgets('shows Register when not registered', (tester) async {
      await pumpBar(
        tester,
        isRegistered: false,
        regStatus: null,
        onChanged: (_, __) {},
      );

      expect(find.text('Register'), findsOneWidget);
      expect(find.text('Registered'), findsNothing);
      expect(find.text('Waiting Approval'), findsNothing);
    });

    testWidgets('shows Registered when already registered', (tester) async {
      await pumpBar(
        tester,
        isRegistered: true,
        regStatus: 'registered',
        onChanged: (_, __) {},
      );

      expect(find.text('Registered'), findsOneWidget);
      expect(find.text('Register'), findsNothing);
    });

    testWidgets('shows Waiting Approval when waitlisted', (tester) async {
      await pumpBar(
        tester,
        isRegistered: false,
        regStatus: 'waitlisted',
        onChanged: (_, __) {},
      );

      expect(find.text('Waiting Approval'), findsOneWidget);
      expect(find.text('Register'), findsNothing);
    });
  });

  group('QuickActionBar — immediate callback on register', () {
    testWidgets(
        'callback receives (true, registered) immediately after successful register',
        (tester) async {
      when(() => mockEvent.register(any())).thenAnswer((_) async => Registration(
            id: 1,
            eventId: 1,
            userId: 1,
            status: 'registered',
            createdAt: DateTime.now(),
          ));

      bool? capturedIsRegistered;
      String? capturedStatus;

      await pumpBar(
        tester,
        isRegistered: false,
        regStatus: null,
        onChanged: (isReg, status) {
          capturedIsRegistered = isReg;
          capturedStatus = status;
        },
      );

      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      // Callback must have fired with the correct state — no extra API round-trip
      expect(capturedIsRegistered, isTrue);
      expect(capturedStatus, 'registered');
    });

    testWidgets(
        'callback receives (true, waitlisted) when register places user on waitlist',
        (tester) async {
      when(() => mockEvent.register(any())).thenAnswer((_) async => Registration(
            id: 2,
            eventId: 1,
            userId: 1,
            status: 'waitlisted',
            createdAt: DateTime.now(),
          ));

      String? capturedStatus;

      await pumpBar(
        tester,
        isRegistered: false,
        regStatus: null,
        onChanged: (_, status) => capturedStatus = status,
      );

      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(capturedStatus, 'waitlisted');
    });
  });

  group('QuickActionBar — immediate callback on unregister', () {
    testWidgets(
        'callback receives (false, null) immediately after confirming unregister',
        (tester) async {
      // selectedEvent needed in _unregister() for refund eligibility messaging
      when(() => mockEvent.selectedEvent).thenReturn(makeEvent(id: 1, status: 'approved'));
      when(() => mockEvent.unregister(any())).thenAnswer((_) async => UnregisterResult(
            refundedCents: 1000,
            pledgesRefunded: 1,
            refundEligible: true,
          ));

      bool? capturedIsRegistered;
      String? capturedStatus;
      var callbackInvoked = false;

      await pumpBar(
        tester,
        isRegistered: true,
        regStatus: 'registered',
        onChanged: (isReg, status) {
          callbackInvoked = true;
          capturedIsRegistered = isReg;
          capturedStatus = status;
        },
      );

      // Tap the "Registered" button — this opens the unregister confirmation dialog
      await tester.tap(find.text('Registered'));
      await tester.pump(); // show dialog

      // The dialog has title "Unregister" AND a button labelled "Unregister".
      // Use ElevatedButton as a discriminator to target the confirm button.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Unregister'));
      await tester.pumpAndSettle();

      expect(callbackInvoked, isTrue);
      expect(capturedIsRegistered, isFalse);
      expect(capturedStatus, isNull);
    });

    testWidgets('callback is NOT invoked when unregister dialog is cancelled',
        (tester) async {
      when(() => mockEvent.selectedEvent).thenReturn(makeEvent(id: 1, status: 'approved'));

      var callbackInvoked = false;

      await pumpBar(
        tester,
        isRegistered: true,
        regStatus: 'registered',
        onChanged: (_, __) => callbackInvoked = true,
      );

      await tester.tap(find.text('Registered'));
      await tester.pump(); // show dialog

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(callbackInvoked, isFalse);
    });
  });
}
