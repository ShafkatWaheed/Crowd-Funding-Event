import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/models/user.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/providers/event_provider.dart';
import '../../lib/screens/event/edit_event_screen.dart';
import '../../lib/repositories/event_repository.dart';
import '../../lib/repositories/ticket_repository.dart';
import '../../lib/repositories/venue_repository.dart';
import '../helpers/mock_providers.dart';
import '../helpers/mock_event_repository.dart';
import '../helpers/mock_ticket_repository.dart';
import '../helpers/mock_venue_repository.dart';
import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockEventProvider mockEvent;
  late MockEventRepository mockEventRepo;
  late MockTicketRepository mockTicketRepo;
  late MockVenueRepository mockVenueRepo;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockEvent = MockEventProvider();
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
        ChangeNotifierProvider<EventProvider>.value(value: mockEvent),
        Provider<EventRepository>.value(value: mockEventRepo),
        Provider<TicketRepository>.value(value: mockTicketRepo),
        Provider<VenueRepository>.value(value: mockVenueRepo),
      ],
    );
  }

  group('EditEventScreen', () {
    testWidgets('shows loading indicator initially', (tester) async {
      // Use completers so the API calls never complete during this test
      final eventCompleter = Completer<Map<String, dynamic>>();
      final strategiesCompleter = Completer<List<dynamic>>();
      final venuesCompleter = Completer<List<dynamic>>();
      final configCompleter = Completer<Map<String, dynamic>>();

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
      eventCompleter.complete(eventJson());
      strategiesCompleter.complete([]);
      venuesCompleter.complete([]);
      configCompleter.complete({});
      await tester.pumpAndSettle();
    });

    testWidgets('renders form after event loads', (tester) async {
      when(() => mockEventRepo.getEvent(1))
          .thenAnswer((_) async => eventJson(title: 'My Event', status: 'draft'));
      when(() => mockTicketRepo.getTicketStrategies())
          .thenAnswer((_) async => []);
      when(() => mockVenueRepo.getVenues())
          .thenAnswer((_) async => [venueJson()]);
      when(() => mockEventRepo.getPublicConfig())
          .thenAnswer((_) async => {});

      await pumpEditEvent(tester);
      await tester.pumpAndSettle();

      // The form should be visible with the title populated
      expect(find.text('Edit Event'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('shows AppBar with close button', (tester) async {
      when(() => mockEventRepo.getEvent(1))
          .thenAnswer((_) async => eventJson());
      when(() => mockTicketRepo.getTicketStrategies())
          .thenAnswer((_) async => []);
      when(() => mockVenueRepo.getVenues())
          .thenAnswer((_) async => []);
      when(() => mockEventRepo.getPublicConfig())
          .thenAnswer((_) async => {});

      await pumpEditEvent(tester);
      await tester.pumpAndSettle();

      // Close icon in leading position
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}
