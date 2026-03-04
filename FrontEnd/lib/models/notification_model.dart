// Notification model for the app notification system.

class NotificationPayload {
  final String type;
  final int? eventId;
  final int? bidId;
  final int? categoryId;
  final int? ticketSaleId;
  final int? pledgeId;

  const NotificationPayload({
    this.type = '',
    this.eventId,
    this.bidId,
    this.categoryId,
    this.ticketSaleId,
    this.pledgeId,
  });

  factory NotificationPayload.fromMap(Map<String, dynamic> data) {
    return NotificationPayload(
      type: data['type'] as String? ?? '',
      eventId: _parseInt(data['event_id']),
      bidId: _parseInt(data['bid_id']),
      categoryId: _parseInt(data['category_id']),
      ticketSaleId: _parseInt(data['ticket_sale_id']),
      pledgeId: _parseInt(data['pledge_id']),
    );
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}

class AppNotification {
  final int id;
  final String type;
  final String title;
  final String message;
  final NotificationPayload data;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.data = const NotificationPayload(),
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      data: NotificationPayload.fromMap(json['data'] != null
          ? Map<String, dynamic>.from(json['data'] as Map)
          : {}),
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      data: data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
