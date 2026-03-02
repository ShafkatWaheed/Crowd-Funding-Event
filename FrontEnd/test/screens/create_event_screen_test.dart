import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/user.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/services/api_service.dart';
import '../../lib/screens/event/create_event_screen.dart';
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

    // Default: organizer user
    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.organizer));

    // Stub all data-loading methods called in initState
    when(() => mockApi.getVenues()).thenAnswer((_) async => [
          venueJson(id: 1, name: 'Main Hall'),
          venueJson(id: 2, name: 'Outdoor Stage'),
        ]);
    when(() => mockApi.getTicketStrategies()).thenAnswer((_) async => [
          ticketStrategyJson(id: 1, name: 'Concert Standard'),
        ]);
    when(() => mockApi.getDiscountStrategies()).thenAnswer((_) async => []);
    when(() => mockApi.getSponsorCategoryTemplates())
        .thenAnswer((_) async => []);
    when(() => mockApi.getPublicConfig()).thenAnswer((_) async => {
          'feature_community_rules_enabled': true,
        });
  });

  Future<void> pumpCreateEvent(WidgetTester tester) async {
    await pumpApp(
      tester,
      const CreateEventScreen(),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        Provider<ApiService>.value(value: mockApi),
      ],
    );
  }

  group('CreateEventScreen', () {
    testWidgets('renders form with title field on first step', (tester) async {
      await pumpCreateEvent(tester);
      await tester.pumpAndSettle();

      // AppBar title
      expect(find.text('Create Event'), findsOneWidget);
      // StepBasics contains a title TextFormField — look for the step label
      expect(find.text('Basics'), findsWidgets);
      // TextFormField widgets for title and description should be present
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('title field validation - next button triggers validation',
        (tester) async {
      await pumpCreateEvent(tester);
      await tester.pumpAndSettle();

      // The Next button text is 'Next: Dates' on step 0
      final nextButton = find.textContaining('Next:');
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // The step validation should prevent advancement
      // We should still be on step 0 (Basics) — form fields still visible
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('venue selection label exists in step indicators',
        (tester) async {
      await pumpCreateEvent(tester);
      await tester.pumpAndSettle();

      // The Location step label exists in the step indicator
      expect(find.text('Location'), findsWidgets);
    });

    testWidgets('review step label exists in step indicator', (tester) async {
      await pumpCreateEvent(tester);
      await tester.pumpAndSettle();

      // The Review step label exists
      expect(find.text('Review'), findsWidgets);
      // The bottom nav has a Next button for step navigation (shows 'Next: Dates' on step 0)
      expect(find.textContaining('Next:'), findsOneWidget);
    });

    testWidgets('form renders all expected step sections', (tester) async {
      await pumpCreateEvent(tester);
      await tester.pumpAndSettle();

      // All step labels should be visible in the step indicator
      expect(find.text('Basics'), findsWidgets);
      expect(find.text('Dates'), findsWidgets);
      expect(find.text('Tickets'), findsWidgets);
      expect(find.text('Discounts'), findsWidgets);
      expect(find.text('Location'), findsWidgets);
      expect(find.text('Review'), findsWidgets);
    });
  });
}
