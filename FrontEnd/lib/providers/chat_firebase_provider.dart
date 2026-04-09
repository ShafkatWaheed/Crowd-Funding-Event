import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat.dart';
import '../models/event.dart';
import '../models/ticket.dart';
import '../repositories/chat_firebase_repository.dart';
import '../repositories/event_repository.dart';
import '../repositories/ticket_repository.dart';

class ChatFirebaseProvider extends ChangeNotifier {
  final ChatFirebaseRepository _repo;
  final EventRepository _eventRepo;
  final TicketRepository _ticketRepo;

  ChatFirebaseProvider(this._repo, this._eventRepo, this._ticketRepo);

  // ── My Events tab state ───────────────────────────────────

  List<MyEventCard> myEventCards = [];
  bool loadingMyEvents = false;
  String? myEventsError;

  // ── Active channel state ──────────────────────────────────

  ChatChannel? activeChannel;
  List<ChatPost> activePosts = [];
  String? activeChannelId;
  StreamSubscription? _channelSub;
  StreamSubscription? _postsSub;

  // ── Active conversation state ─────────────────────────────

  String? activeConversationId;
  List<DmMessage> activeMessages = [];
  Map<String, bool> typingUsers = {};
  StreamSubscription? _messagesSub;
  StreamSubscription? _typingSub;

  // ── General ───────────────────────────────────────────────

  bool loading = false;
  String? error;

  int get totalUnreadCount {
    int count = 0;
    for (final card in myEventCards) {
      count += card.totalUnread;
    }
    return count;
  }

  // ── My Events ─────────────────────────────────────────────

  /// Load events for the Portal tab. Pass [userId] for organizers to fetch
  /// their organized events directly.
  Future<void> loadMyEvents({int? userId, bool isOrganizer = false}) async {
    loadingMyEvents = true;
    myEventsError = null;
    notifyListeners();

    debugPrint('Portal: loadMyEvents userId=$userId isOrganizer=$isOrganizer');

    try {
      final eventMap = <int, _EventCardBuilder>{};

      // 0) Fetch organizer's own events if applicable
      if (isOrganizer && userId != null) {
        try {
          final orgResult = await _eventRepo.getEvents(
            filters: EventFilters(organizerId: userId, includeAllStatuses: true),
            limit: 100,
          );
          for (final event in orgResult.items) {
            eventMap.putIfAbsent(
              event.id,
              () => _EventCardBuilder(
                eventId: event.id,
                eventTitle: event.title,
                eventStatus: event.status.name,
                isOrganizer: true,
                startTime: event.startTime,
                endTime: event.endTime,
                venueName: event.venue?.name,
              ),
            );
          }
        } catch (e) {
          debugPrint('Portal: failed to load organizer events: $e');
        }
      }

      // 1-2) Customer/sponsor only: fetch registered events + tickets
      if (!isOrganizer) {
        try {
          final myEvents = await _eventRepo.getMyEvents(offset: 0, limit: 100);
          for (final event in myEvents) {
            eventMap.putIfAbsent(
              event.id,
              () => _EventCardBuilder(
                eventId: event.id,
                eventTitle: event.title,
                eventStatus: event.status.name,
                startTime: event.startTime,
                endTime: event.endTime,
                venueName: event.venue?.name,
              ),
            );
          }
        } catch (e) {
          debugPrint('Portal: failed to load my events: $e');
        }

        try {
          final ticketResult = await _ticketRepo.getMyTickets(offset: 0, limit: 200);
          for (final ticket in ticketResult.items) {
            final builder = eventMap.putIfAbsent(
              ticket.eventId,
              () => _EventCardBuilder(
                eventId: ticket.eventId,
                eventTitle: ticket.eventTitle ?? 'Event #${ticket.eventId}',
                eventStatus: ticket.eventStatus ?? 'selling_tickets',
              ),
            );
            builder.tickets.add(ticket);
          }
        } catch (e) {
          debugPrint('Portal: failed to load tickets: $e');
        }
      }

      // 3) Fetch user's conversations (DMs)
      try {
        final conversations = await _repo.getMyConversations();
        for (final conv in conversations) {
          final builder = eventMap.putIfAbsent(
            conv.eventId,
            () => _EventCardBuilder(
              eventId: conv.eventId,
              eventTitle: conv.eventTitle ?? 'Event #${conv.eventId}',
            ),
          );
          builder.conversation = conv;
        }
      } catch (_) {
        // Chat service may not be available yet — still show events
      }

      // 4) Sort tickets within each card: unscanned first
      for (final builder in eventMap.values) {
        builder.tickets.sort((a, b) {
          final aScanned = a.scannedAt != null ? 1 : 0;
          final bScanned = b.scannedAt != null ? 1 : 0;
          return aScanned.compareTo(bScanned);
        });
      }

      // 5) Check for announcement channels per event
      for (final builder in eventMap.values) {
        final channelId = 'event_${builder.eventId}_customer';
        try {
          final channelData = await _repo.getChannelOnce(channelId);
          if (channelData != null) {
            builder.channel = ChatChannel.fromFirebase(channelId, channelData);
          }
        } catch (_) {}
      }

      // 6) Fetch unread DM counts for organizers
      if (isOrganizer) {
        for (final builder in eventMap.values) {
          if (!builder.isOrganizer) continue;
          try {
            final customerConvs = await _repo.getEventConversations(builder.eventId, typeFilter: 'customer');
            builder.customerUnreadCount = customerConvs.fold<int>(0, (sum, c) => sum + c.unreadCount);
          } catch (_) {}
          try {
            final sponsorConvs = await _repo.getEventConversations(builder.eventId, typeFilter: 'sponsor');
            builder.sponsorUnreadCount = sponsorConvs.fold<int>(0, (sum, c) => sum + c.unreadCount);
          } catch (_) {}
        }
      }

      // 7) Build cards and sort by priority
      myEventCards = eventMap.values.map((b) => b.build()).toList();
      myEventCards.sort((a, b) {
        final priCmp = a.sortPriority.compareTo(b.sortPriority);
        if (priCmp != 0) return priCmp;
        final aTime = a.startTime?.millisecondsSinceEpoch ?? 0;
        final bTime = b.startTime?.millisecondsSinceEpoch ?? 0;
        return aTime.compareTo(bTime);
      });
      debugPrint('Portal: built ${myEventCards.length} cards');
    } catch (e) {
      myEventsError = e.toString();
      debugPrint('Portal: loadMyEvents error: $e');
    }

    loadingMyEvents = false;
    notifyListeners();
  }

  // ── Announcement channels ─────────────────────────────────

  void openChannel(String channelId) {
    closeChannel();
    activeChannelId = channelId;

    _channelSub = _repo.watchChannel(channelId).listen((channel) {
      activeChannel = channel;
      notifyListeners();
    });

    _postsSub = _repo.watchPosts(channelId).listen((posts) {
      activePosts = posts;
      notifyListeners();
    });
  }

  void closeChannel() {
    _channelSub?.cancel();
    _postsSub?.cancel();
    _channelSub = null;
    _postsSub = null;
    activeChannelId = null;
    activeChannel = null;
    activePosts = [];
  }

  Future<ChatPost> createPost(String channelId, String body, {String msgType = 'text'}) async {
    try {
      return await _repo.createPost(channelId, CreatePostRequest(body: body, msgType: msgType));
    } catch (e) {
      // If channel doesn't exist (404), auto-create it then retry
      if (e.toString().contains('404') || e.toString().contains('Not Found')) {
        // Parse event_id and type from channelId: "event_{id}_{type}"
        final parts = channelId.split('_');
        if (parts.length >= 3) {
          final eventId = int.tryParse(parts[1]);
          final type = parts.last; // "customer" or "sponsor"
          if (eventId != null) {
            await _repo.createChannel(CreateChannelRequest(eventId: eventId, channelType: type));
            return await _repo.createPost(channelId, CreatePostRequest(body: body, msgType: msgType));
          }
        }
      }
      rethrow;
    }
  }

  Future<void> reactToPost(
    String channelId,
    String postId,
    String userId,
    UserReaction? reaction,
  ) async {
    await _repo.reactToPost(channelId, postId, userId, reaction);
  }

  // ── DM Conversations ──────────────────────────────────────

  void openConversation(String conversationId) {
    closeConversation();
    activeConversationId = conversationId;

    _messagesSub = _repo.watchMessages(conversationId).listen((messages) {
      activeMessages = messages;
      notifyListeners();
    });

    _typingSub = _repo.watchTyping(conversationId).listen((typing) {
      typingUsers = typing;
      notifyListeners();
    });
  }

  void closeConversation() {
    _messagesSub?.cancel();
    _typingSub?.cancel();
    _messagesSub = null;
    _typingSub = null;
    activeConversationId = null;
    activeMessages = [];
    typingUsers = {};
  }

  Future<void> sendMessage(
    String conversationId,
    String body, {
    String msgType = 'text',
    required String clientId,
    required int senderId,
  }) async {
    await _repo.sendMessage(conversationId, body, msgType, clientId, senderId);
  }

  Future<void> markRead(String conversationId, String userId) async {
    await _repo.markRead(conversationId, userId);
  }

  Future<void> setTyping(
    String conversationId,
    String userId,
    bool isTyping,
  ) async {
    await _repo.setTyping(conversationId, userId, isTyping);
  }

  Future<DmConversation> initConversation(int eventId) async {
    final conv = await _repo.initConversation(eventId);
    await loadMyEvents(); // Refresh list
    return conv;
  }

  Future<ChatChannel> createChannel(int eventId, String channelType) async {
    final channel = await _repo.createChannel(
      CreateChannelRequest(eventId: eventId, channelType: channelType),
    );
    return channel;
  }

  // ── Organizer inbox ───────────────────────────────────────

  Future<List<DmConversation>> getEventConversations(
    int eventId, {
    String? typeFilter,
  }) async {
    return _repo.getEventConversations(eventId, typeFilter: typeFilter);
  }

  // ── Cleanup ───────────────────────────────────────────────

  @override
  void dispose() {
    closeChannel();
    closeConversation();
    super.dispose();
  }
}

/// Helper to build MyEventCard from grouped data.
class _EventCardBuilder {
  final int eventId;
  final String eventTitle;
  final String eventStatus;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? venueName;
  bool isOrganizer;
  ChatChannel? channel;
  DmConversation? conversation;
  List<TicketSale> tickets = [];
  int customerUnreadCount = 0;
  int sponsorUnreadCount = 0;

  _EventCardBuilder({
    required this.eventId,
    required this.eventTitle,
    this.eventStatus = 'selling_tickets',
    this.isOrganizer = false,
    this.startTime,
    this.endTime,
    this.venueName,
  });

  MyEventCard build() {
    return MyEventCard(
      eventId: eventId,
      eventTitle: eventTitle,
      eventStatus: eventStatus,
      startTime: startTime,
      endTime: endTime,
      venueName: venueName,
      isOrganizer: isOrganizer,
      channel: channel,
      conversation: conversation,
      tickets: tickets,
      customerUnreadCount: customerUnreadCount,
      sponsorUnreadCount: sponsorUnreadCount,
    );
  }
}
