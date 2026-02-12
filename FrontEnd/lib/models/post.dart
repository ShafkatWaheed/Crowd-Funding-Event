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
      id: json['id'],
      eventId: json['event_id'],
      userId: json['user_id'],
      authorName: json['author_name'],
      content: json['content'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
