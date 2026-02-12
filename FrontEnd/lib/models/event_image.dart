class EventImage {
  final int id;
  final int eventId;
  final String imageUrl;
  final String? caption;
  final int displayOrder;
  final DateTime createdAt;

  EventImage({
    required this.id,
    required this.eventId,
    required this.imageUrl,
    this.caption,
    this.displayOrder = 0,
    required this.createdAt,
  });

  factory EventImage.fromJson(Map<String, dynamic> json) {
    return EventImage(
      id: json['id'],
      eventId: json['event_id'],
      imageUrl: json['image_url'] ?? '',
      caption: json['caption'],
      displayOrder: json['display_order'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
