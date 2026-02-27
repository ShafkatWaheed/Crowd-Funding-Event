import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../services/chat_socket_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api;
  final ChatSocketService _socket;
  StreamSubscription? _sub;

  final Map<int, List<ChatMessage>> _messagesByBid = {};
  final Map<int, int> _unreadCounts = {};
  final Map<int, bool> _typingByBid = {};
  List<ChatConversation> _conversations = [];
  bool _conversationsLoading = false;

  ChatProvider(this._api, this._socket);

  List<ChatMessage> messagesFor(int bidId) => _messagesByBid[bidId] ?? [];
  int unreadFor(int bidId) => _unreadCounts[bidId] ?? 0;
  bool isTyping(int bidId) => _typingByBid[bidId] ?? false;
  List<ChatConversation> get conversations => _conversations;
  bool get conversationsLoading => _conversationsLoading;

  int get totalUnreadCount =>
      _unreadCounts.values.fold(0, (sum, c) => sum + c);

  void startListening() {
    _sub?.cancel();
    _sub = _socket.messages.listen(_onWsMessage);
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
  }

  void _onWsMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'new_message':
        final msgData = data['message'] as Map<String, dynamic>?;
        if (msgData == null) return;
        final msg = ChatMessage.fromJson(msgData);
        final list = _messagesByBid.putIfAbsent(msg.bidId, () => []);
        if (!list.any((m) => m.id == msg.id)) {
          list.insert(0, msg);
          _unreadCounts[msg.bidId] = (unreadFor(msg.bidId)) + 1;
          _socket.ack(msg.bidId, msg.id);
        }
        _typingByBid[msg.bidId] = false;
        notifyListeners();

      case 'sent':
        final clientId = data['client_id'] as String?;
        final messageId = data['message_id'] as String?;
        final createdAt = data['created_at'];
        if (clientId == null || messageId == null) return;
        for (final entry in _messagesByBid.entries) {
          final idx = entry.value.indexWhere((m) => m.clientId == clientId);
          if (idx >= 0) {
            entry.value[idx].status = MessageStatus.sent;
            entry.value[idx] = ChatMessage(
              id: messageId,
              bidId: entry.value[idx].bidId,
              senderId: entry.value[idx].senderId,
              body: entry.value[idx].body,
              clientId: clientId,
              msgType: entry.value[idx].msgType,
              createdAt: createdAt is int
                  ? DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true)
                  : entry.value[idx].createdAt,
              status: MessageStatus.sent,
            );
            break;
          }
        }
        notifyListeners();

      case 'delivered':
        final messageId = data['message_id'] as String?;
        if (messageId == null) return;
        _updateMessageStatus(messageId, MessageStatus.delivered);
        notifyListeners();

      case 'read':
        final messageId = data['message_id'] as String?;
        if (messageId == null) return;
        _updateMessageStatus(messageId, MessageStatus.read);
        notifyListeners();

      case 'typing':
        final bidId = data['bid_id'] as int?;
        final typing = data['is_typing'] as bool? ?? false;
        if (bidId != null) {
          _typingByBid[bidId] = typing;
          notifyListeners();
        }

      case 'joined':
        break;

      case 'error':
        debugPrint('Chat WS error: ${data['detail']}');
    }
  }

  void _updateMessageStatus(String messageId, MessageStatus status) {
    for (final list in _messagesByBid.values) {
      final idx = list.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        if (list[idx].status.index < status.index) {
          list[idx].status = status;
        }
        return;
      }
    }
  }

  void sendMessage(int bidId, String body, int senderId) {
    final clientId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final msg = ChatMessage(
      id: 'pending_$clientId',
      bidId: bidId,
      senderId: senderId,
      body: body,
      clientId: clientId,
      createdAt: DateTime.now().toUtc(),
      status: MessageStatus.sending,
    );
    _messagesByBid.putIfAbsent(bidId, () => []);
    _messagesByBid[bidId]!.insert(0, msg);
    notifyListeners();

    _socket.sendMessage(bidId, body, clientId);
  }

  Future<void> loadHistory(int bidId, {String? before}) async {
    try {
      final messages = await _api.getChatMessages(bidId, before: before);
      final list = _messagesByBid.putIfAbsent(bidId, () => []);
      for (final msg in messages) {
        if (!list.any((m) => m.id == msg.id)) {
          list.add(msg);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Load chat history error: $e');
    }
  }

  Future<void> loadConversations() async {
    _conversationsLoading = true;
    notifyListeners();
    try {
      _conversations = await _api.getChatConversations();
      for (final c in _conversations) {
        _unreadCounts[c.bidId] = c.unreadCount;
      }
    } catch (e) {
      debugPrint('Load conversations error: $e');
    }
    _conversationsLoading = false;
    notifyListeners();
  }

  void joinBid(int bidId) => _socket.join(bidId);
  void leaveBid(int bidId) => _socket.leave(bidId);

  void markRead(int bidId, String messageId) {
    _socket.markRead(bidId, messageId);
    _unreadCounts[bidId] = 0;
    notifyListeners();
  }

  void sendTypingIndicator(int bidId, bool isTyping) {
    _socket.sendTyping(bidId, isTyping);
  }

  void clearBid(int bidId) {
    _messagesByBid.remove(bidId);
    _typingByBid.remove(bidId);
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
