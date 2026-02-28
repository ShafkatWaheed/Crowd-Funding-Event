enum MessageStatus { sending, sent, delivered, read }

class ChatMessage {
  final String id;
  final int bidId;
  final int senderId;
  final String body;
  final String? clientId;
  final String msgType;
  final DateTime createdAt;
  MessageStatus status;

  ChatMessage({
    required this.id,
    required this.bidId,
    required this.senderId,
    required this.body,
    this.clientId,
    this.msgType = 'text',
    required this.createdAt,
    this.status = MessageStatus.sent,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final ts = json['created_at'];
    DateTime createdAt;
    if (ts is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
    } else if (ts is String) {
      createdAt = DateTime.tryParse(ts)?.toUtc() ?? DateTime.now().toUtc();
    } else {
      createdAt = DateTime.now().toUtc();
    }

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      bidId: json['bid_id'] ?? 0,
      senderId: json['sender_id'] ?? 0,
      body: json['body'] ?? '',
      clientId: json['client_id'],
      msgType: json['msg_type'] ?? 'text',
      createdAt: createdAt,
    );
  }

  bool get isSystem => msgType == 'system';
  bool get isImage => msgType == 'image';
}

class ChatConversation {
  final int bidId;
  final int eventId;
  final String eventTitle;
  final String categoryName;
  final String bidStatus;
  final String eventStatus;
  final int sponsorUserId;
  final int organizerUserId;
  final String sponsorName;
  final String organizerName;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isWritable;

  ChatConversation({
    required this.bidId,
    required this.eventId,
    required this.eventTitle,
    required this.categoryName,
    required this.bidStatus,
    required this.eventStatus,
    required this.sponsorUserId,
    required this.organizerUserId,
    this.sponsorName = '',
    this.organizerName = '',
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isWritable = true,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      bidId: json['bid_id'] ?? 0,
      eventId: json['event_id'] ?? 0,
      eventTitle: json['event_title'] ?? '',
      categoryName: json['category_name'] ?? '',
      bidStatus: json['bid_status'] ?? '',
      eventStatus: json['event_status'] ?? '',
      sponsorUserId: json['sponsor_user_id'] ?? 0,
      organizerUserId: json['organizer_user_id'] ?? 0,
      sponsorName: json['sponsor_name'] ?? '',
      organizerName: json['organizer_name'] ?? '',
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'])
          : null,
      unreadCount: json['unread_count'] ?? 0,
      isWritable: json['is_writable'] ?? true,
    );
  }
}
