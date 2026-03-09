import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:crowd_funding_app/models/event.dart';
import 'package:crowd_funding_app/providers/event_provider.dart';
import 'package:crowd_funding_app/widgets/calendar_bottom_sheet.dart';
import '../helpers/fixtures.dart';
import '../helpers/mock_event_repository.dart';
import '../helpers/pump_app.dart';

void main() {
  late MockEventRepository mockEventRepo;

  setUp(() {
    mockEventRepo = MockEventRepository();
    when(() => mockEventRepo.calendarUrl(any())).thenReturn('https://example.com/cal/1.ics');
  });

  Future<void> pumpCalendarSheet(WidgetTester tester, Event event) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showCalendarSheet(ctx, event),
            child: const Text('Open'),
          ),
        ),
      ),
      overrides: [ChangeNotifierProvider<EventProvider>.value(value: EventProvider(mockEventRepo))],
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group('CalendarBottomSheet', () {
    testWidgets('renders both calendar options', (tester) async {
      final event = makeEvent();
      await pumpCalendarSheet(tester, event);

      expect(find.text('Add to Calendar'), findsOneWidget);
      expect(find.text('Google Calendar'), findsOneWidget);
      expect(find.text('Open in Google Calendar'), findsOneWidget);
      expect(find.text('Download .ics'), findsOneWidget);
      expect(find.text('Works with Outlook, Apple Calendar, etc.'), findsOneWidget);
    });

    testWidgets('renders calendar icons', (tester) async {
      final event = makeEvent();
      await pumpCalendarSheet(tester, event);

      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    });

    testWidgets('tapping Google Calendar dismisses the sheet', (tester) async {
      final event = makeEvent();
      await pumpCalendarSheet(tester, event);

      await tester.tap(find.text('Google Calendar'));
      await tester.pumpAndSettle();

      // Sheet should be dismissed
      expect(find.text('Add to Calendar'), findsNothing);
    });

    testWidgets('tapping Download .ics dismisses the sheet', (tester) async {
      final event = makeEvent();
      await pumpCalendarSheet(tester, event);

      await tester.tap(find.text('Download .ics'));
      await tester.pumpAndSettle();

      // Sheet should be dismissed
      expect(find.text('Add to Calendar'), findsNothing);
      // calendarUrl was accessed
      verify(() => mockEventRepo.calendarUrl(event.id)).called(1);
    });
  });
}
