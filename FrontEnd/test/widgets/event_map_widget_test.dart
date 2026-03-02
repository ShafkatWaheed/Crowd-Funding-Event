import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../lib/services/api_service.dart';
import '../../lib/widgets/event_map_widget.dart';
import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

Map<String, dynamic> _markerJson({
  int id = 1,
  String title = 'Test Event',
  double lat = 45.4215,
  double lng = -75.6972,
  String status = 'approved',
  bool isLive = false,
  int? venueId = 1,
  String? venueName = 'Grand Hall',
  String? startTime,
}) =>
    {
      'id': id,
      'title': title,
      'lat': lat,
      'lng': lng,
      'status': status,
      'is_live': isLive,
      'venue_id': venueId,
      'venue_name': venueName,
      'start_time': startTime,
    };

void main() {
  late MockApiService mockApi;

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
    mockApi = MockApiService();
  });

  /// Stub all getMapEvents named params.
  void stubMapEvents(MockApiService api, FutureOr<List<dynamic>> Function() result) {
    when(() => api.getMapEvents(
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
      overrides: [Provider<ApiService>.value(value: mockApi)],
    );
  }

  group('EventMapWidget', () {
    testWidgets('builds without error and shows loading indicator', (tester) async {
      final completer = Completer<List<dynamic>>();
      stubMapEvents(mockApi, () => completer.future);

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
      stubMapEvents(mockApi, () => [
            _markerJson(id: 1, title: 'Event A'),
            _markerJson(id: 2, title: 'Event B', venueId: 2, venueName: 'Arena'),
          ]);

      await pumpMap(tester);
      await tester.pumpAndSettle();

      verify(() => mockApi.getMapEvents(
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
      stubMapEvents(mockApi, () => throw Exception('Network error'));

      await pumpMap(tester);
      await tester.pumpAndSettle();

      // Should not crash — loading indicator gone
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('hides loading indicator after data loads', (tester) async {
      stubMapEvents(mockApi, () => [_markerJson()]);

      await pumpMap(tester);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
