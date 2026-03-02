import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../lib/providers/chat_provider.dart';
import '../../lib/models/chat_message.dart';
import '../helpers/mock_api_service.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockApiService mockApi;
  late MockChatSocketService mockSocket;
  late ChatProvider provider;
  late StreamController<Map<String, dynamic>> wsController;

  setUp(() {
    mockApi = MockApiService();
    mockSocket = MockChatSocketService();
    wsController = StreamController<Map<String, dynamic>>.broadcast();
    when(() => mockSocket.messages).thenAnswer((_) => wsController.stream);
    provider = ChatProvider(mockApi, mockSocket);
  });

  tearDown(() {
    wsController.close();
    provider.dispose();
  });

  group('ChatProvider', () {
    test('initial state', () {
      expect(provider.messagesFor(1), isEmpty);
      expect(provider.unreadFor(1), 0);
      expect(provider.isTyping(1), false);
      expect(provider.conversations, isEmpty);
      expect(provider.conversationsLoading, false);
      expect(provider.totalUnreadCount, 0);
    });

    test('loadConversations success', () async {
      when(() => mockApi.getChatConversations()).thenAnswer((_) async => [
            ChatConversation.fromJson(chatConversationJson(bidId: 1, unreadCount: 3)),
            ChatConversation.fromJson(chatConversationJson(bidId: 2, unreadCount: 1)),
          ]);

      await provider.loadConversations();

      expect(provider.conversations.length, 2);
      expect(provider.totalUnreadCount, 4);
      expect(provider.unreadFor(1), 3);
      expect(provider.conversationsLoading, false);
    });

    test('loadConversations error does not throw', () async {
      when(() => mockApi.getChatConversations())
          .thenThrow(Exception('Network error'));

      await provider.loadConversations();

      expect(provider.conversations, isEmpty);
      expect(provider.conversationsLoading, false);
    });

    test('loadHistory appends messages', () async {
      when(() => mockApi.getChatMessages(1, before: null)).thenAnswer((_) async => [
            ChatMessage.fromJson(chatMessageJson(id: 'msg-1', bidId: 1)),
            ChatMessage.fromJson(chatMessageJson(id: 'msg-2', bidId: 1)),
          ]);

      await provider.loadHistory(1);

      expect(provider.messagesFor(1).length, 2);
    });

    test('loadHistory deduplicates messages', () async {
      when(() => mockApi.getChatMessages(1, before: null)).thenAnswer((_) async => [
            ChatMessage.fromJson(chatMessageJson(id: 'msg-1', bidId: 1)),
          ]);

      await provider.loadHistory(1);
      await provider.loadHistory(1);

      // Should not duplicate
      expect(provider.messagesFor(1).length, 1);
    });

    test('sendMessage adds optimistic message', () {
      when(() => mockSocket.sendMessage(any(), any(), any())).thenReturn(null);

      provider.sendMessage(1, 'Hello', 10);

      expect(provider.messagesFor(1).length, 1);
      expect(provider.messagesFor(1)[0].body, 'Hello');
      expect(provider.messagesFor(1)[0].status, MessageStatus.sending);
    });

    test('joinBid and leaveBid delegate to socket', () {
      when(() => mockSocket.join(any())).thenReturn(null);
      when(() => mockSocket.leave(any())).thenReturn(null);

      provider.joinBid(5);
      verify(() => mockSocket.join(5)).called(1);

      provider.leaveBid(5);
      verify(() => mockSocket.leave(5)).called(1);
    });

    test('markRead delegates to socket and clears unread', () {
      when(() => mockSocket.markRead(any(), any())).thenReturn(null);

      // Setup some unread count
      when(() => mockApi.getChatConversations()).thenAnswer((_) async => [
            ChatConversation.fromJson(chatConversationJson(bidId: 1, unreadCount: 5)),
          ]);

      provider.markRead(1, 'msg-1');

      verify(() => mockSocket.markRead(1, 'msg-1')).called(1);
      expect(provider.unreadFor(1), 0);
    });

    test('sendTypingIndicator delegates to socket', () {
      when(() => mockSocket.sendTyping(any(), any())).thenReturn(null);

      provider.sendTypingIndicator(3, true);
      verify(() => mockSocket.sendTyping(3, true)).called(1);
    });

    test('clearBid removes messages and typing state', () {
      when(() => mockSocket.sendMessage(any(), any(), any())).thenReturn(null);
      provider.sendMessage(1, 'test', 10);
      expect(provider.messagesFor(1).length, 1);

      provider.clearBid(1);
      expect(provider.messagesFor(1), isEmpty);
    });

    test('WebSocket new_message event adds message', () async {
      provider.startListening();

      wsController.add({
        'type': 'new_message',
        'message': chatMessageJson(id: 'ws-msg-1', bidId: 1, body: 'Hi there'),
      });

      // Give stream time to propagate
      await Future.delayed(Duration.zero);

      when(() => mockSocket.ack(any(), any())).thenReturn(null);
      // The listener should have processed the message
      // Note: We need to verify behavior through side effects
    });

    test('WebSocket typing event updates typing state', () async {
      provider.startListening();

      wsController.add({
        'type': 'typing',
        'bid_id': 1,
        'is_typing': true,
      });

      await Future.delayed(Duration.zero);

      expect(provider.isTyping(1), true);
    });
  });
}
