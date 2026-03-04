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

// ─── Request Classes ───

/// Typed request for POST /venues.
class CreateVenueRequest {
  final String name;
  final String address;
  final String city;
  final String? province;
  final int maxCapacity;
  final double? lat;
  final double? lng;

  const CreateVenueRequest({
    required this.name,
    required this.address,
    required this.city,
    this.province,
    required this.maxCapacity,
    this.lat,
    this.lng,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'name': name,
      'address': address,
      'city': city,
      'max_capacity': maxCapacity,
    };
    if (province != null) json['province'] = province;
    if (lat != null) json['lat'] = lat;
    if (lng != null) json['lng'] = lng;
    return json;
  }
}

/// Typed request for PATCH /venues/:id — only non-null fields are sent.
class UpdateVenueRequest {
  final String? name;
  final String? address;
  final String? city;
  final String? province;
  final int? maxCapacity;
  final double? lat;
  final double? lng;

  const UpdateVenueRequest({
    this.name,
    this.address,
    this.city,
    this.province,
    this.maxCapacity,
    this.lat,
    this.lng,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (name != null) json['name'] = name;
    if (address != null) json['address'] = address;
    if (city != null) json['city'] = city;
    if (province != null) json['province'] = province;
    if (maxCapacity != null) json['max_capacity'] = maxCapacity;
    if (lat != null) json['lat'] = lat;
    if (lng != null) json['lng'] = lng;
    return json;
  }
}
