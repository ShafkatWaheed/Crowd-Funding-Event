import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:crowd_funding_app/models/event.dart';
import 'package:crowd_funding_app/widgets/event/event_card.dart';
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

    testWidgets('renders funding progress when goal is set', (tester) async {
      final event = Event.fromJson(eventJson(
        fundingGoalCents: 100000,
        totalPledgedCents: 75000,
        fundingEndAt: DateTime.now()
            .toUtc()
            .add(const Duration(days: 7))
            .toIso8601String(),
      ));

      await mockNetworkImagesFor(() => pumpApp(
            tester,
            Scaffold(body: EventCard(event: event)),
          ));
      await tester.pump();

      expect(find.textContaining('75%'), findsOneWidget);
      // Card uses a custom FractionallySizedBox-based bar, not LinearProgressIndicator
      expect(find.byType(FractionallySizedBox), findsWidgets);
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

      expect(find.textContaining('% raised'), findsNothing);
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

    testWidgets('shows "Sold Out" when ticket capacity is reached', (tester) async {
      final json = eventJson(status: 'selling_tickets', maxCapacity: 100);
      // Set tier capacity (distinct from venue maxCapacity) and fill it
      json['total_tier_capacity'] = 100;
      json['tickets_sold_count'] = 100;
      final event = Event.fromJson(json);

      await mockNetworkImagesFor(() => pumpApp(
            tester,
            // isOrganizerOrAdmin: false so ticket stats chip is shown instead of attendee count
            Scaffold(body: EventCard(event: event, isOrganizerOrAdmin: false)),
          ));
      await tester.pump();

      expect(find.textContaining('Sold Out'), findsOneWidget);
    });

    testWidgets('shows ticket count when not full', (tester) async {
      final json = eventJson(status: 'selling_tickets', maxCapacity: 200);
      json['total_tier_capacity'] = 200;
      json['tickets_sold_count'] = 20;
      final event = Event.fromJson(json);

      await mockNetworkImagesFor(() => pumpApp(
            tester,
            Scaffold(body: EventCard(event: event, isOrganizerOrAdmin: false)),
          ));
      await tester.pump();

      expect(find.textContaining('20/200'), findsOneWidget);
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
