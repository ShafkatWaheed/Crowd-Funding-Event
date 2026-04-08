import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat.dart';
import '../repositories/chat_firebase_repository.dart';

class ChatFirebaseProvider extends ChangeNotifier {
  final ChatFirebaseRepository _repo;

  ChatFirebaseProvider(this._repo);

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

  Future<void> loadMyEvents() async {
    loadingMyEvents = true;
    myEventsError = null;
    notifyListeners();

    try {
      final conversations = await _repo.getMyConversations();
      // Group by event
      final eventMap = <int, _EventCardBuilder>{};

      for (final conv in conversations) {
        eventMap.putIfAbsent(
          conv.eventId,
          () => _EventCardBuilder(
            eventId: conv.eventId,
            eventTitle: conv.eventTitle ?? 'Event #${conv.eventId}',
          ),
        );
        eventMap[conv.eventId]!.conversation = conv;
      }

      // Build cards and sort
      myEventCards = eventMap.values.map((b) => b.build()).toList();
      myEventCards.sort((a, b) {
        final priCmp = a.sortPriority.compareTo(b.sortPriority);
        if (priCmp != 0) return priCmp;
        // Within same priority, sort by start time (soonest first)
        final aTime = a.startTime?.millisecondsSinceEpoch ?? 0;
        final bTime = b.startTime?.millisecondsSinceEpoch ?? 0;
        return aTime.compareTo(bTime);
      });
    } catch (e) {
      myEventsError = e.toString();
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
    return _repo.createPost(channelId, CreatePostRequest(body: body, msgType: msgType));
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
  DmConversation? conversation;

  _EventCardBuilder({required this.eventId, required this.eventTitle});

  MyEventCard build() {
    return MyEventCard(
      eventId: eventId,
      eventTitle: eventTitle,
      eventStatus: conversation?.status == 'read_only' ? 'completed' : 'selling_tickets',
      conversation: conversation,
    );
  }
}
