/// Lightweight event marker model for map view.
class MapEvent {
  final int id;
  final String title;
  final double lat;
  final double lng;
  final String? startTime;
  final String? endTime;
  final String status;
  final bool isLive;
  final int? venueId;
  final String? venueName;

  MapEvent({
    required this.id,
    required this.title,
    required this.lat,
    required this.lng,
    this.startTime,
    this.endTime,
    required this.status,
    required this.isLive,
    this.venueId,
    this.venueName,
  });

  factory MapEvent.fromJson(Map<String, dynamic> json) {
    return MapEvent(
      id: json['id'],
      title: json['title'],
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      startTime: json['start_time'],
      endTime: json['end_time'],
      status: json['status'],
      isLive: json['is_live'] ?? false,
      venueId: json['venue_id'],
      venueName: json['venue_name'],
    );
  }
}
