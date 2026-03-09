import 'package:flutter_test/flutter_test.dart';
import 'package:crowd_funding_app/models/map_event.dart';

void main() {
  group('EventMarker', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 42,
        'title': 'Street Fair',
        'lat': 40.7128,
        'lng': -74.0060,
        'start_time': '2025-06-01T18:00:00',
        'end_time': '2025-06-01T23:00:00',
        'status': 'approved',
        'is_live': true,
        'venue_id': 7,
        'venue_name': 'Central Park',
      };

      final marker = EventMarker.fromJson(json);

      expect(marker.id, 42);
      expect(marker.title, 'Street Fair');
      expect(marker.lat, 40.7128);
      expect(marker.lng, -74.0060);
      expect(marker.startTime, '2025-06-01T18:00:00');
      expect(marker.endTime, '2025-06-01T23:00:00');
      expect(marker.status, 'approved');
      expect(marker.isLive, true);
      expect(marker.venueId, 7);
      expect(marker.venueName, 'Central Park');
    });

    test('nullable fields default to null', () {
      final json = {
        'id': 1,
        'title': 'Minimal',
        'lat': 0.0,
        'lng': 0.0,
        'status': 'draft',
        'is_live': false,
      };

      final marker = EventMarker.fromJson(json);

      expect(marker.startTime, isNull);
      expect(marker.endTime, isNull);
      expect(marker.venueId, isNull);
      expect(marker.venueName, isNull);
    });

    test('isLive defaults to false when missing', () {
      final json = {
        'id': 2,
        'title': 'No Live Key',
        'lat': 10.0,
        'lng': 20.0,
        'status': 'approved',
        // is_live omitted
      };

      final marker = EventMarker.fromJson(json);

      expect(marker.isLive, false);
    });

    test('lat/lng parse from int values via num.toDouble()', () {
      final json = {
        'id': 3,
        'title': 'Int coords',
        'lat': 40, // int, not double
        'lng': -74, // int, not double
        'status': 'live',
        'is_live': true,
      };

      final marker = EventMarker.fromJson(json);

      expect(marker.lat, 40.0);
      expect(marker.lng, -74.0);
    });
  });
}
