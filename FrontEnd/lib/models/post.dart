class EventPost {
  final int id;
  final int eventId;
  final int userId;
  final String? authorName;
  final String content;
  final DateTime createdAt;

  EventPost({
    required this.id,
    required this.eventId,
    required this.userId,
    this.authorName,
    required this.content,
    required this.createdAt,
  });

  factory EventPost.fromJson(Map<String, dynamic> json) {
    return EventPost(
      id: (json['id'] as num?)?.toInt() ?? 0,
      eventId: (json['event_id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      authorName: json['author_name'] as String?,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
