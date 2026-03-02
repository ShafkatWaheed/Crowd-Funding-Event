import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import '../../lib/models/event.dart';
import '../../lib/widgets/event_card.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  group('EventCard', () {
    testWidgets('renders event title', (tester) async {
      final event = makeEvent(title: 'Summer Music Festival');

      await mockNetworkImagesFor(() => pumpApp(
            tester,
            Scaffold(body: EventCard(event: event)),
          ));
      await tester.pump();

      expect(find.text('Summer Music Festival'), findsOneWidget);
    });

    testWidgets('renders event date when start time is set', (tester) async {
      final event = Event.fromJson(eventJson(
        startTime: '2025-06-15T18:00:00',
      ));

      await mockNetworkImagesFor(() => pumpApp(
            tester,
            Scaffold(body: EventCard(event: event)),
          ));
      await tester.pump();

      // Should show formatted date (not "TBD")
      expect(find.text('Event date: TBD'), findsNothing);
    });

    testWidgets('renders "Event date: TBD" when no start time', (tester) async {
      final event = Event.fromJson(eventJson(startTime: null));

      await mockNetworkImagesFor(() => pumpApp(
            tester,
            Scaffold(body: EventCard(event: event)),
          ));
      await tester.pump();

      expect(find.text('Event date: TBD'), findsOneWidget);
    });

    testWidgets('renders venue name and city', (tester) async {
      final event = Event.fromJson(eventJson(
        venue: venueJson(name: 'Grand Hall', city: 'Toronto'),
      ));

      await mockNetworkImagesFor(() => pumpApp(
            tester,
            Scaffold(body: EventCard(event: event)),
          ));
      await tester.pump();

      expect(find.text('Grand Hall, Toronto'), findsOneWidget);
    });

    testWidgets('renders genre when present', (tester) async {
      final event = Event.fromJson(eventJson(genre: 'jazz'));

      await mockNetworkImagesFor(() => pumpApp(
            tester,
            Scaffold(body: EventCard(event: event)),
          ));
      await tester.pump();

      expect(find.text('Jazz'), findsOneWidget);
    });

    testWidgets('renders funding progress when goal is set', (tester) async {
      final event = Event.fromJson(eventJson(
        fundingGoalCents: 100000,
        totalPledgedCents: 75000,
      ));

      await mockNetworkImagesFor(() => pumpApp(
            tester,
            Scaffold(body: EventCard(event: event)),
          ));
      await tester.pump();

      expect(find.textContaining('75%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('does not render funding bar when no goal', (tester) async {
      final event = Event.fromJson(eventJson(
        fundingGoalCents: null,
        totalPledgedCents: null,
      ));

      await mockNetworkImagesFor(() => pumpApp(
            tester,
            Scaffold(body: EventCard(event: event)),
          ));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('renders age restriction badge', (tester) async {
      final event = Event.fromJson(eventJson(
        ageRestricted: true,
        minAge: 21,
      ));

      await mockNetworkImagesFor(() => pumpApp(
            tester,
            Scaffold(body: EventCard(event: event)),
          ));
      await tester.pump();

      expect(find.text('21+'), findsOneWidget);
    });

    testWidgets('shows bookmark button and fires callback', (tester) async {
      bool bookmarkTapped = false;
      final event = makeEvent();

      await mockNetworkImagesFor(() => pumpApp(
            tester,
            Scaffold(
              body: EventCard(
                event: event,
                isBookmarked: false,
                onBookmarkToggle: () => bookmarkTapped = true,
              ),
            ),
          ));
      await tester.pump();

      // Find the bookmark icon
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
      await tester.pump();

      expect(bookmarkTapped, isTrue);
    });

    testWidgets('shows filled bookmark when bookmarked', (tester) async {
      final event = makeEvent();

      await mockNetworkImagesFor(() => pumpApp(
            tester,
            Scaffold(
              body: EventCard(
                event: event,
                isBookmarked: true,
                onBookmarkToggle: () {},
              ),
            ),
          ));
      await tester.pump();

      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    });

    testWidgets('fires onTap callback', (tester) async {
      bool tapped = false;
      final event = makeEvent();

      await mockNetworkImagesFor(() => pumpApp(
            tester,
            Scaffold(
              body: EventCard(
                event: event,
                onTap: () => tapped = true,
              ),
            ),
          ));
      await tester.pump();

      await tester.tap(find.byType(EventCard));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('shows "FULL" when capacity is reached', (tester) async {
      final json = eventJson(maxCapacity: 100);
      // Override to fill capacity — need totalReservedSpots + ticketsSoldCount >= maxCapacity
      json['total_reserved_spots'] = 60;
      json['tickets_sold_count'] = 40;
      final event = Event.fromJson(json);

      await mockNetworkImagesFor(() => pumpApp(
            tester,
            Scaffold(body: EventCard(event: event)),
          ));
      await tester.pump();

      expect(find.text('FULL'), findsOneWidget);
    });

    testWidgets('shows spots left when not full', (tester) async {
      final json = eventJson(maxCapacity: 200);
      json['total_reserved_spots'] = 30;
      json['tickets_sold_count'] = 20;
      final event = Event.fromJson(json);

      await mockNetworkImagesFor(() => pumpApp(
            tester,
            Scaffold(body: EventCard(event: event)),
          ));
      await tester.pump();

      expect(find.text('150 spots left'), findsOneWidget);
    });

    testWidgets('hides bookmark button when no callback', (tester) async {
      final event = makeEvent();

      await mockNetworkImagesFor(() => pumpApp(
            tester,
            Scaffold(body: EventCard(event: event)),
          ));
      await tester.pump();

      expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
      expect(find.byIcon(Icons.bookmark_rounded), findsNothing);
    });
  });
}
