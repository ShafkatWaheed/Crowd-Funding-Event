import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/event.dart';
import '../../lib/models/user.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/repositories/event_repository.dart';
import '../../lib/repositories/ticket_repository.dart';
import '../../lib/repositories/venue_repository.dart';
import '../../lib/repositories/sponsor_repository.dart';
import '../../lib/providers/event_provider.dart';
import '../../lib/providers/ticket_provider.dart';
import '../../lib/providers/venue_provider.dart';
import '../../lib/providers/sponsor_provider.dart';
import '../../lib/models/venue.dart';
import '../../lib/models/ticket_strategy.dart';
import '../../lib/screens/event/create_event_screen.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_event_repository.dart';
import '../helpers/mock_ticket_repository.dart';
import '../helpers/mock_venue_repository.dart';
import '../helpers/mock_sponsor_repository.dart';
import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockEventRepository mockEventRepo;
  late MockTicketRepository mockTicketRepo;
  late MockVenueRepository mockVenueRepo;
  late MockSponsorRepository mockSponsorRepo;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockEventRepo = MockEventRepository();
    mockTicketRepo = MockTicketRepository();
    mockVenueRepo = MockVenueRepository();
    mockSponsorRepo = MockSponsorRepository();

    // Default: organizer user
    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.organizer));

    // Stub all data-loading methods called in initState
    when(() => mockVenueRepo.getVenues()).thenAnswer((_) async => [
          Venue.fromJson(venueJson(id: 1, name: 'Main Hall')),
          Venue.fromJson(venueJson(id: 2, name: 'Outdoor Stage')),
        ]);
    when(() => mockTicketRepo.getTicketStrategies()).thenAnswer((_) async => [
          TicketStrategy.fromJson(ticketStrategyJson(id: 1, name: 'Concert Standard')),
        ]);
    when(() => mockTicketRepo.getDiscountStrategies()).thenAnswer((_) async => []);
    when(() => mockSponsorRepo.getSponsorCategoryTemplates())
        .thenAnswer((_) async => []);
    when(() => mockEventRepo.getPublicConfig()).thenAnswer((_) async =>
        PublicConfig(featureCommunityRulesEnabled: true));
  });

  Future<void> pumpCreateEvent(WidgetTester tester) async {
    await pumpApp(
      tester,
      const CreateEventScreen(),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<EventProvider>.value(value: EventProvider(mockEventRepo)),
        ChangeNotifierProvider<TicketProvider>.value(value: TicketProvider(mockTicketRepo)),
        ChangeNotifierProvider<VenueProvider>.value(value: VenueProvider(mockVenueRepo)),
        ChangeNotifierProvider<SponsorProvider>.value(value: SponsorProvider(mockSponsorRepo)),
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
