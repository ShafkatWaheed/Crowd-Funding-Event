class Venue {
  final int id;
  final int organizerId;
  final String name;
  final String address;
  final String city;
  final String? province;
  final double? lat;
  final double? lng;
  final int maxCapacity;
  final DateTime createdAt;

  Venue({
    required this.id,
    required this.organizerId,
    required this.name,
    required this.address,
    required this.city,
    this.province,
    this.lat,
    this.lng,
    required this.maxCapacity,
    required this.createdAt,
  });

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'],
      organizerId: json['organizer_id'],
      name: json['name'],
      address: json['address'],
      city: json['city'],
      province: json['province'],
      lat: json['lat']?.toDouble(),
      lng: json['lng']?.toDouble(),
      maxCapacity: json['max_capacity'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get fullAddress {
    final parts = [address, city];
    if (province != null && province!.isNotEmpty) parts.add(province!);
    return parts.join(', ');
  }
}
