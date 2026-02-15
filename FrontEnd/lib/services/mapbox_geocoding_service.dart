import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Geocoding result from Mapbox.
class GeocodingResult {
  final String fullAddress;
  final String? city;
  final String? province;
  final double lat;
  final double lng;

  GeocodingResult({
    required this.fullAddress,
    this.city,
    this.province,
    required this.lat,
    required this.lng,
  });
}

/// Forward geocoding using Mapbox Geocoding v6 API.
class MapboxGeocodingService {
  static String get _accessToken =>
      dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

  /// Search for address suggestions (forward geocoding).
  /// Returns up to [limit] results.
  static Future<List<GeocodingResult>> search(
    String query, {
    int limit = 5,
  }) async {
    if (query.trim().isEmpty || _accessToken.isEmpty) {
      debugPrint('[MapboxGeocoding] Skipped: query="${query.trim()}", tokenPresent=${_accessToken.isNotEmpty}');
      return [];
    }

    final uri = Uri.https(
      'api.mapbox.com',
      '/search/geocode/v6/forward',
      {
        'q': query,
        'access_token': _accessToken,
        'limit': '$limit',
        'types': 'address,place,street,locality',
        'language': 'en',
      },
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List? ?? [];

      return features.map<GeocodingResult>((f) {
        final props = f['properties'] as Map<String, dynamic>? ?? {};
        final context = props['context'] as Map<String, dynamic>? ?? {};

        // Extract city from place context
        final place = context['place'] as Map<String, dynamic>?;
        final region = context['region'] as Map<String, dynamic>?;

        final coords = f['geometry']?['coordinates'] as List?;
        final lng = coords != null && coords.isNotEmpty
            ? (coords[0] as num).toDouble()
            : 0.0;
        final lat = coords != null && coords.length > 1
            ? (coords[1] as num).toDouble()
            : 0.0;

        return GeocodingResult(
          fullAddress: props['full_address'] ?? props['name'] ?? query,
          city: place?['name'],
          province: region?['name'],
          lat: lat,
          lng: lng,
        );
      }).toList();
    } catch (e) {
      debugPrint('[MapboxGeocoding] Error: $e');
      return [];
    }
  }
}
