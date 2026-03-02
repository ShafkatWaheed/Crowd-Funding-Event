import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/chat_message.dart';
import '../helpers/fixtures.dart';

void main() {
  group('ChatMessage', () {
    test('fromJson parses string created_at', () {
      final json = chatMessageJson(
        id: 'msg-42',
        bidId: 5,
        senderId: 10,
        body: 'Hello world',
        msgType: 'text',
        createdAt: '2025-02-15T10:30:00',
      );
      final msg = ChatMessage.fromJson(json);

      expect(msg.id, 'msg-42');
      expect(msg.bidId, 5);
      expect(msg.senderId, 10);
      expect(msg.body, 'Hello world');
      expect(msg.msgType, 'text');
      expect(msg.createdAt.year, 2025);
      expect(msg.createdAt.month, 2);
      expect(msg.createdAt.day, 15);
    });

    test('fromJson handles int timestamp for created_at', () {
      final ts = DateTime.utc(2025, 3, 1, 12, 0).millisecondsSinceEpoch;
      final json = {
        'id': 'msg-1',
        'bid_id': 1,
        'sender_id': 1,
        'body': 'test',
        'created_at': ts,
      };
      final msg = ChatMessage.fromJson(json);
      expect(msg.createdAt.year, 2025);
      expect(msg.createdAt.month, 3);
    });

    test('fromJson handles null/missing created_at gracefully', () {
      final json = {
        'id': 'msg-1',
        'bid_id': 1,
        'sender_id': 1,
        'body': 'test',
      };
      final msg = ChatMessage.fromJson(json);
      // Should not throw, uses DateTime.now() fallback
      expect(msg.createdAt, isNotNull);
    });

    test('isSystem getter', () {
      final sys = ChatMessage.fromJson(chatMessageJson(msgType: 'system'));
      expect(sys.isSystem, true);
      expect(sys.isImage, false);
    });

    test('isImage getter', () {
      final img = ChatMessage.fromJson(chatMessageJson(msgType: 'image'));
      expect(img.isImage, true);
      expect(img.isSystem, false);
    });

    test('MessageStatus enum', () {
      expect(MessageStatus.values.length, 4);
      expect(MessageStatus.sending.index, 0);
      expect(MessageStatus.sent.index, 1);
      expect(MessageStatus.delivered.index, 2);
      expect(MessageStatus.read.index, 3);
    });

    test('default status is sent', () {
      final msg = ChatMessage.fromJson(chatMessageJson());
      expect(msg.status, MessageStatus.sent);
    });

    test('clientId nullable', () {
      final msg = ChatMessage.fromJson(chatMessageJson(clientId: null));
      expect(msg.clientId, isNull);

      final withClient = ChatMessage.fromJson(chatMessageJson(clientId: 'abc'));
      expect(withClient.clientId, 'abc');
    });
  });

  group('ChatConversation', () {
    test('fromJson parses all fields', () {
      final json = chatConversationJson(
        bidId: 5,
        eventId: 3,
        eventTitle: 'Music Fest',
        categoryName: 'Platinum',
        bidStatus: 'accepted',
        eventStatus: 'approved',
        sponsorUserId: 7,
        organizerUserId: 10,
        unreadCount: 5,
        isWritable: true,
      );
      final conv = ChatConversation.fromJson(json);

      expect(conv.bidId, 5);
      expect(conv.eventId, 3);
      expect(conv.eventTitle, 'Music Fest');
      expect(conv.categoryName, 'Platinum');
      expect(conv.bidStatus, 'accepted');
      expect(conv.eventStatus, 'approved');
      expect(conv.sponsorUserId, 7);
      expect(conv.organizerUserId, 10);
      expect(conv.unreadCount, 5);
      expect(conv.isWritable, true);
    });

    test('lastMessageAt nullable', () {
      final json = chatConversationJson();
      final conv = ChatConversation.fromJson(json);
      expect(conv.lastMessageAt, isNull);
    });

    test('lastMessageAt parsed when present', () {
      final json = chatConversationJson();
      json['last_message_at'] = '2025-03-01T15:00:00';
      final conv = ChatConversation.fromJson(json);
      expect(conv.lastMessageAt, isNotNull);
      expect(conv.lastMessageAt!.day, 1);
    });

    test('defaults for optional string fields', () {
      final json = {'bid_id': 1, 'event_id': 1};
      final conv = ChatConversation.fromJson(json);
      expect(conv.sponsorName, '');
      expect(conv.organizerName, '');
      expect(conv.eventTitle, '');
      expect(conv.categoryName, '');
    });
  });
}
