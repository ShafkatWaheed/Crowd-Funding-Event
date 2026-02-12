class Venue {
  final int id;
  final String name;
  final String address;
  final String city;
  final String? province;
  final double? lat;
  final double? lng;
  final int maxCapacity;

  Venue({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    this.province,
    this.lat,
    this.lng,
    required this.maxCapacity,
  });

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'],
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      province: json['province'],
      lat: json['lat']?.toDouble(),
      lng: json['lng']?.toDouble(),
      maxCapacity: json['max_capacity'] ?? 0,
    );
  }

  String get fullAddress {
    final parts = [address, city];
    if (province != null && province!.isNotEmpty) parts.add(province!);
    return parts.join(', ');
  }
}
