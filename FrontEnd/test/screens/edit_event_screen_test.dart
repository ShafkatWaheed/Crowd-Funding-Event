import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:crowd_funding_app/models/event.dart';
import 'package:crowd_funding_app/models/user.dart';
import 'package:crowd_funding_app/providers/auth_provider.dart';
import 'package:crowd_funding_app/providers/event_provider.dart';
import 'package:crowd_funding_app/screens/event/edit_event_screen.dart';
import 'package:crowd_funding_app/models/venue.dart';
import 'package:crowd_funding_app/models/ticket_strategy.dart';
import 'package:crowd_funding_app/providers/ticket_provider.dart';
import 'package:crowd_funding_app/providers/venue_provider.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_event_repository.dart';
import '../helpers/mock_ticket_repository.dart';
import '../helpers/mock_venue_repository.dart';
import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockEventRepository mockEventRepo;
  late MockTicketRepository mockTicketRepo;
  late MockVenueRepository mockVenueRepo;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockEventRepo = MockEventRepository();
    mockTicketRepo = MockTicketRepository();
    mockVenueRepo = MockVenueRepository();

    when(() => mockAuth.user).thenReturn(makeUser(role: UserRole.organizer));
  });

  Future<void> pumpEditEvent(WidgetTester tester) async {
    await pumpApp(
      tester,
      const EditEventScreen(eventId: 1),
      overrides: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<EventProvider>.value(value: EventProvider(mockEventRepo)),
        ChangeNotifierProvider<TicketProvider>.value(value: TicketProvider(mockTicketRepo)),
        ChangeNotifierProvider<VenueProvider>.value(value: VenueProvider(mockVenueRepo)),
      ],
    );
  }

  group('EditEventScreen', () {
    testWidgets('shows loading indicator initially', (tester) async {
      // Use completers so the API calls never complete during this test
      final eventCompleter = Completer<Event>();
      final strategiesCompleter = Completer<List<TicketStrategy>>();
      final venuesCompleter = Completer<List<Venue>>();
      final configCompleter = Completer<PublicConfig>();

      when(() => mockEventRepo.getEvent(1))
          .thenAnswer((_) => eventCompleter.future);
      when(() => mockTicketRepo.getTicketStrategies())
          .thenAnswer((_) => strategiesCompleter.future);
      when(() => mockVenueRepo.getVenues())
          .thenAnswer((_) => venuesCompleter.future);
      when(() => mockEventRepo.getPublicConfig())
          .thenAnswer((_) => configCompleter.future);

      await pumpEditEvent(tester);
      // Trigger the addPostFrameCallback
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Edit Event'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete to avoid pending timer issues
      eventCompleter.complete(Event.fromJson(eventJson()));
      strategiesCompleter.complete([]);
      venuesCompleter.complete([]);
      configCompleter.complete(PublicConfig());
      await tester.pumpAndSettle();
    });

    testWidgets('renders form after event loads', (tester) async {
      when(() => mockEventRepo.getEvent(1))
          .thenAnswer((_) async => Event.fromJson(eventJson(title: 'My Event', status: 'draft')));
      when(() => mockTicketRepo.getTicketStrategies())
          .thenAnswer((_) async => []);
      when(() => mockVenueRepo.getVenues())
          .thenAnswer((_) async => [Venue.fromJson(venueJson())]);
      when(() => mockEventRepo.getPublicConfig())
          .thenAnswer((_) async => PublicConfig());

      await pumpEditEvent(tester);
      await tester.pumpAndSettle();

      // The form should be visible with the title populated
      expect(find.text('Edit Event'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('shows AppBar with close button', (tester) async {
      when(() => mockEventRepo.getEvent(1))
          .thenAnswer((_) async => Event.fromJson(eventJson()));
      when(() => mockTicketRepo.getTicketStrategies())
          .thenAnswer((_) async => []);
      when(() => mockVenueRepo.getVenues())
          .thenAnswer((_) async => []);
      when(() => mockEventRepo.getPublicConfig())
          .thenAnswer((_) async => PublicConfig());

      await pumpEditEvent(tester);
      await tester.pumpAndSettle();

      // Close icon in leading position
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}
