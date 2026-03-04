class ScheduleItem {
  final int id;
  final int eventId;
  final String date;
  final String startTime;
  final String endTime;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? imageCaption;
  final String? linkUrl;
  final int sortOrder;
  final bool overlaps;
  final DateTime createdAt;

  ScheduleItem({
    required this.id,
    required this.eventId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.title,
    this.description,
    this.imageUrl,
    this.imageCaption,
    this.linkUrl,
    this.sortOrder = 0,
    this.overlaps = false,
    required this.createdAt,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: json['id'],
      eventId: json['event_id'],
      date: json['date'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      title: json['title'],
      description: json['description'],
      imageUrl: json['image_url'],
      imageCaption: json['image_caption'],
      linkUrl: json['link_url'],
      sortOrder: json['sort_order'] ?? 0,
      overlaps: json['overlaps'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class ScheduleDay {
  final String date;
  final List<ScheduleItem> items;

  ScheduleDay({required this.date, required this.items});

  factory ScheduleDay.fromJson(Map<String, dynamic> json) {
    return ScheduleDay(
      date: json['date'],
      items: (json['items'] as List)
          .map((j) => ScheduleItem.fromJson(j))
          .toList(),
    );
  }
}

// ─── Schedule Image Upload Result ───

class ScheduleImageResult {
  final String? url;
  final String? caption;

  ScheduleImageResult({this.url, this.caption});

  factory ScheduleImageResult.fromJson(Map<String, dynamic> json) =>
      ScheduleImageResult(
        url: (json['url'] ?? json['image_url']) as String?,
        caption: json['caption'] as String?,
      );
}
