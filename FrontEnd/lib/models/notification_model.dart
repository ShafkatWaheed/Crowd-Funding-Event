// Notification model for the app notification system.

class NotificationPayload {
  final String type;
  final int? eventId;
  final int? bidId;
  final int? categoryId;
  final int? ticketSaleId;
  final String? purchaseGroupId;
  final int? pledgeId;

  const NotificationPayload({
    this.type = '',
    this.eventId,
    this.bidId,
    this.categoryId,
    this.ticketSaleId,
    this.purchaseGroupId,
    this.pledgeId,
  });

  factory NotificationPayload.fromMap(Map<String, dynamic> data) {
    return NotificationPayload(
      type: data['type'] as String? ?? '',
      eventId: _parseInt(data['event_id']),
      bidId: _parseInt(data['bid_id']),
      categoryId: _parseInt(data['category_id']),
      ticketSaleId: _parseInt(data['ticket_sale_id']),
      purchaseGroupId: data['purchase_group_id'] as String?,
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
    final notifType = json['type'] as String? ?? '';
    final rawData = json['data'] != null
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};
    // Ensure payload always carries the notification type for routing
    rawData.putIfAbsent('type', () => notifType);
    return AppNotification(
      id: json['id'] as int,
      type: notifType,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      data: NotificationPayload.fromMap(rawData),
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
