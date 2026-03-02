import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/venue.dart';
import '../helpers/fixtures.dart';

void main() {
  group('Venue', () {
    test('fromJson parses all fields', () {
      final json = venueJson(
        id: 5,
        name: 'Grand Arena',
        address: '456 Elm St',
        city: 'Chicago',
        province: 'IL',
        lat: 41.8781,
        lng: -87.6298,
        maxCapacity: 10000,
      );
      final venue = Venue.fromJson(json);

      expect(venue.id, 5);
      expect(venue.name, 'Grand Arena');
      expect(venue.address, '456 Elm St');
      expect(venue.city, 'Chicago');
      expect(venue.province, 'IL');
      expect(venue.lat, 41.8781);
      expect(venue.lng, -87.6298);
      expect(venue.maxCapacity, 10000);
    });

    test('nullable lat/lng', () {
      final json = venueJson(lat: null, lng: null);
      final venue = Venue.fromJson(json);
      expect(venue.lat, isNull);
      expect(venue.lng, isNull);
    });

    test('fullAddress without province', () {
      final venue = Venue.fromJson(venueJson(
        address: '123 Main St',
        city: 'Boston',
        province: null,
      ));
      expect(venue.fullAddress, '123 Main St, Boston');
    });

    test('fullAddress with province', () {
      final venue = Venue.fromJson(venueJson(
        address: '123 Main St',
        city: 'Boston',
        province: 'MA',
      ));
      expect(venue.fullAddress, '123 Main St, Boston, MA');
    });

    test('fullAddress with empty province', () {
      final venue = Venue.fromJson(venueJson(
        address: '123 Main St',
        city: 'Boston',
        province: '',
      ));
      // Empty province should not be included
      expect(venue.fullAddress, '123 Main St, Boston');
    });

    test('defaults for nullable/missing fields', () {
      final json = {'id': 1};
      final venue = Venue.fromJson(json);
      expect(venue.name, '');
      expect(venue.address, '');
      expect(venue.city, '');
      expect(venue.maxCapacity, 0);
    });
  });
}
