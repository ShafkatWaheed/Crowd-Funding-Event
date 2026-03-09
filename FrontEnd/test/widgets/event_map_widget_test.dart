import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:crowd_funding_app/models/map_event.dart';
import 'package:crowd_funding_app/providers/event_provider.dart';
import 'package:crowd_funding_app/widgets/event_map_widget.dart';
import '../helpers/mock_event_repository.dart';
import '../helpers/pump_app.dart';

EventMarker _markerEvent({
  int id = 1,
  String title = 'Test Event',
  String status = 'approved',
}) =>
    EventMarker(
      id: id,
      title: title,
      lat: 45.4215,
      lng: -75.6972,
      status: status,
      isLive: false,
    );

void main() {
  late MockEventRepository mockEventRepo;

  setUpAll(() async {
    // dotenv must be initialized before the widget reads env vars.
    // Load with empty file and inject the token via mergeWith.
    await dotenv.load(
      fileName: '.env',
      mergeWith: {'MAPBOX_ACCESS_TOKEN': 'test_token'},
      isOptional: true,
    );
  });

  setUp(() {
    mockEventRepo = MockEventRepository();
  });

  /// Stub all getMapEvents named params.
  void stubMapEvents(MockEventRepository repo, FutureOr<List<EventMarker>> Function() result) {
    when(() => repo.getMapEvents(
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
          radiusKm: any(named: 'radiusKm'),
          organizerId: any(named: 'organizerId'),
          sponsorshipOnly: any(named: 'sponsorshipOnly'),
          search: any(named: 'search'),
          genre: any(named: 'genre'),
          status: any(named: 'status'),
          city: any(named: 'city'),
        )).thenAnswer((_) async => result());
  }

  Future<void> pumpMap(WidgetTester tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: SizedBox(
          width: 400,
          height: 600,
          child: EventMapWidget(),
        ),
      ),
      overrides: [ChangeNotifierProvider<EventProvider>.value(value: EventProvider(mockEventRepo))],
    );
  }

  group('EventMapWidget', () {
    testWidgets('builds without error and shows loading indicator', (tester) async {
      final completer = Completer<List<EventMarker>>();
      stubMapEvents(mockEventRepo, () => completer.future);

      await pumpMap(tester);
      await tester.pump();
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete to avoid async leaks.
      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('calls getMapEvents on load', (tester) async {
      stubMapEvents(mockEventRepo, () => [
            _markerEvent(id: 1, title: 'Event A'),
            _markerEvent(id: 2, title: 'Event B'),
          ]);

      await pumpMap(tester);
      await tester.pumpAndSettle();

      verify(() => mockEventRepo.getMapEvents(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            radiusKm: any(named: 'radiusKm'),
            organizerId: any(named: 'organizerId'),
            sponsorshipOnly: any(named: 'sponsorshipOnly'),
            search: any(named: 'search'),
            genre: any(named: 'genre'),
            status: any(named: 'status'),
            city: any(named: 'city'),
          )).called(greaterThanOrEqualTo(1));
    });

    testWidgets('handles API error gracefully', (tester) async {
      stubMapEvents(mockEventRepo, () => throw Exception('Network error'));

      await pumpMap(tester);
      await tester.pumpAndSettle();

      // Should not crash — loading indicator gone
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('hides loading indicator after data loads', (tester) async {
      stubMapEvents(mockEventRepo, () => [_markerEvent()]);

      await pumpMap(tester);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
