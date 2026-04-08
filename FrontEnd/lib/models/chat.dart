// Models for Firebase RTDB chat: channels, posts, conversations, DMs.
import 'ticket.dart';

// ── Announcement Channels ───────────────────────────────────

class ChatChannel {
  final String channelId;
  final int eventId;
  final String type; // "customer" | "sponsor"
  final String status; // "open" | "read_only" | "archived"
  final int? lastPostAt;

  const ChatChannel({
    required this.channelId,
    required this.eventId,
    required this.type,
    this.status = 'open',
    this.lastPostAt,
  });

  factory ChatChannel.fromJson(Map<String, dynamic> json) {
    return ChatChannel(
      channelId: json['channel_id'] as String? ?? '',
      eventId: json['event_id'] as int? ?? 0,
      type: json['type'] as String? ?? 'customer',
      status: json['status'] as String? ?? 'open',
      lastPostAt: json['last_post_at'] as int?,
    );
  }

  /// From Firebase RTDB snapshot (key = channel_id).
  factory ChatChannel.fromFirebase(String key, Map<String, dynamic> data) {
    return ChatChannel(
      channelId: key,
      eventId: data['event_id'] as int? ?? 0,
      type: data['type'] as String? ?? 'customer',
      status: data['status'] as String? ?? 'open',
      lastPostAt: data['last_post_at'] as int?,
    );
  }

  bool get isOpen => status == 'open';
}

class ChatPost {
  final String postId;
  final String channelId;
  final int senderId;
  final String body;
  final String msgType; // "text" | "image"
  final String? imageUrl;
  final int createdAt;
  final int likeCount;
  final int dislikeCount;

  const ChatPost({
    required this.postId,
    required this.channelId,
    required this.senderId,
    required this.body,
    this.msgType = 'text',
    this.imageUrl,
    required this.createdAt,
    this.likeCount = 0,
    this.dislikeCount = 0,
  });

  factory ChatPost.fromFirebase(String key, String channelId, Map<String, dynamic> data) {
    final reactions = data['reaction_counts'] as Map<String, dynamic>? ?? {};
    return ChatPost(
      postId: key,
      channelId: channelId,
      senderId: data['sender_id'] as int? ?? 0,
      body: data['body'] as String? ?? '',
      msgType: data['msg_type'] as String? ?? 'text',
      imageUrl: data['image_url'] as String?,
      createdAt: data['created_at'] as int? ?? 0,
      likeCount: reactions['like'] as int? ?? 0,
      dislikeCount: reactions['dislike'] as int? ?? 0,
    );
  }

  factory ChatPost.fromJson(Map<String, dynamic> json) {
    final reactions = json['reaction_counts'] as Map<String, dynamic>? ?? {};
    return ChatPost(
      postId: json['post_id'] as String? ?? '',
      channelId: json['channel_id'] as String? ?? '',
      senderId: json['sender_id'] as int? ?? 0,
      body: json['body'] as String? ?? '',
      msgType: json['msg_type'] as String? ?? 'text',
      imageUrl: json['image_url'] as String?,
      createdAt: json['created_at'] as int? ?? 0,
      likeCount: reactions['like'] as int? ?? 0,
      dislikeCount: reactions['dislike'] as int? ?? 0,
    );
  }

  bool get isImage => msgType == 'image';

  DateTime get createdAtDateTime =>
      DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true);
}

// ── DM Conversations ────────────────────────────────────────

class DmConversation {
  final String conversationId;
  final int eventId;
  final String? eventTitle;
  final int participantUserId;
  final String? participantName;
  final int organizerUserId;
  final String? organizerName;
  final String type; // "customer" | "sponsor"
  final String status; // "open" | "read_only"
  final String? lastMessageText;
  final int? lastMessageAt;
  final int unreadCount;

  const DmConversation({
    required this.conversationId,
    required this.eventId,
    this.eventTitle,
    required this.participantUserId,
    this.participantName,
    required this.organizerUserId,
    this.organizerName,
    this.type = 'customer',
    this.status = 'open',
    this.lastMessageText,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory DmConversation.fromJson(Map<String, dynamic> json) {
    return DmConversation(
      conversationId: json['conversation_id'] as String? ?? '',
      eventId: json['event_id'] as int? ?? 0,
      eventTitle: json['event_title'] as String?,
      participantUserId: json['participant_user_id'] as int? ?? 0,
      participantName: json['participant_name'] as String?,
      organizerUserId: json['organizer_user_id'] as int? ?? 0,
      organizerName: json['organizer_name'] as String?,
      type: json['type'] as String? ?? 'customer',
      status: json['status'] as String? ?? 'open',
      lastMessageText: json['last_message_text'] as String?,
      lastMessageAt: json['last_message_at'] as int?,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  bool get isOpen => status == 'open';
}

class DmMessage {
  final String id;
  final int senderId;
  final String body;
  final String msgType; // "text" | "image"
  final String? imageUrl;
  final String? clientId;
  final int createdAt;
  final String status; // "sent" | "delivered" | "read"

  const DmMessage({
    required this.id,
    required this.senderId,
    required this.body,
    this.msgType = 'text',
    this.imageUrl,
    this.clientId,
    required this.createdAt,
    this.status = 'sent',
  });

  factory DmMessage.fromFirebase(String key, Map<String, dynamic> data) {
    return DmMessage(
      id: key,
      senderId: data['sender_id'] as int? ?? 0,
      body: data['body'] as String? ?? '',
      msgType: data['msg_type'] as String? ?? 'text',
      imageUrl: data['image_url'] as String?,
      clientId: data['client_id'] as String?,
      createdAt: data['created_at'] as int? ?? 0,
      status: data['status'] as String? ?? 'sent',
    );
  }

  bool get isImage => msgType == 'image';

  DateTime get createdAtDateTime =>
      DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true);
}

// ── Reaction ────────────────────────────────────────────────

enum UserReaction { like, dislike }

// ── Composite: My Event Card ────────────────────────────────

class MyEventCard {
  final int eventId;
  final String eventTitle;
  final String eventStatus;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? venueName;
  final DateTime? completedAt;

  /// Announcement channel for this event (null if not a member).
  final ChatChannel? channel;

  /// DM conversation with organizer (null if none initiated).
  final DmConversation? conversation;

  /// Sponsor bid info (for sponsor cards only).
  final SponsorBidInfo? bidInfo;

  /// Tickets the user holds for this event.
  final List<TicketSale> tickets;

  /// Whether the current user is the organizer for this event.
  final bool isOrganizer;

  /// Unread count for the announcement channel.
  final int channelUnreadCount;

  const MyEventCard({
    required this.eventId,
    required this.eventTitle,
    required this.eventStatus,
    this.startTime,
    this.endTime,
    this.venueName,
    this.completedAt,
    this.channel,
    this.conversation,
    this.bidInfo,
    this.tickets = const [],
    this.isOrganizer = false,
    this.channelUnreadCount = 0,
  });

  /// Sort priority: live=0, upcoming=1, selling/funding=2, completed=3.
  int get sortPriority {
    switch (eventStatus) {
      case 'live':
        return 0;
      case 'waiting_event_date':
        return 1;
      case 'selling_tickets':
      case 'approved':
        return 2;
      case 'completed':
      case 'cancelled':
        return 3;
      default:
        return 2;
    }
  }

  bool get isLive => eventStatus == 'live';
  bool get isCompleted => eventStatus == 'completed' || eventStatus == 'cancelled';

  int get totalUnread =>
      channelUnreadCount + (conversation?.unreadCount ?? 0);
}

class SponsorBidInfo {
  final String categoryName;
  final String bidStatus;
  final int amountCents;

  const SponsorBidInfo({
    required this.categoryName,
    required this.bidStatus,
    required this.amountCents,
  });
}

// ── Request classes ─────────────────────────────────────────

class CreateChannelRequest {
  final int eventId;
  final String channelType;

  const CreateChannelRequest({required this.eventId, required this.channelType});

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'channel_type': channelType,
      };
}

class CreatePostRequest {
  final String body;
  final String msgType;

  const CreatePostRequest({required this.body, this.msgType = 'text'});

  Map<String, dynamic> toJson() => {
        'body': body,
        'msg_type': msgType,
      };
}

class InitConversationRequest {
  final int eventId;

  const InitConversationRequest({required this.eventId});

  Map<String, dynamic> toJson() => {'event_id': eventId};
}
