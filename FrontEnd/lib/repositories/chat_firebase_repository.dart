import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/chat.dart';
import 'base_repository.dart';

const _root = 'crowd_funding_chat';
const _shardCount = 10;

class ChatFirebaseRepository extends BaseRepository {
  ChatFirebaseRepository(super.dio);

  final _db = FirebaseDatabase.instance;
  final _random = Random();

  DatabaseReference _ref(String path) => _db.ref('$_root/$path');

  // ── Channels (Announcements) ──────────────────────────────

  Stream<ChatChannel?> watchChannel(String channelId) {
    return _ref('channels/$channelId').onValue.map((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return null;
      return ChatChannel.fromFirebase(channelId, Map<String, dynamic>.from(data));
    });
  }

  /// One-shot read of channel data (not a stream). Returns raw map or null.
  Future<Map<String, dynamic>?> getChannelOnce(String channelId) async {
    final snap = await _ref('channels/$channelId').get();
    final data = snap.value as Map?;
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Stream<List<ChatPost>> watchPosts(String channelId) {
    return _ref('posts/$channelId').onValue.map((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return [];
      final posts = <ChatPost>[];
      data.forEach((key, value) {
        if (value is Map) {
          posts.add(ChatPost.fromFirebase(
            key.toString(),
            channelId,
            Map<String, dynamic>.from(value),
          ));
        }
      });
      posts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return posts;
    });
  }

  Stream<UserReaction?> watchUserReaction(
    String channelId,
    String postId,
    String userId,
  ) {
    return _ref('user_reactions/$channelId/$postId/$userId').onValue.map((event) {
      final val = event.snapshot.value as String?;
      if (val == 'like') return UserReaction.like;
      if (val == 'dislike') return UserReaction.dislike;
      return null;
    });
  }

  Future<void> reactToPost(
    String channelId,
    String postId,
    String userId,
    UserReaction? reaction,
  ) async {
    final userRef = _ref('user_reactions/$channelId/$postId/$userId');
    final currentSnap = await userRef.get();
    final current = currentSnap.value as String?;

    final shard = 'shard_${_random.nextInt(_shardCount)}';
    final shardRef = _ref('reaction_shards/$channelId/$postId/$shard');

    if (reaction == null) {
      // Toggle off
      if (current == 'like') {
        await shardRef.child('like').set(ServerValue.increment(-1));
      } else if (current == 'dislike') {
        await shardRef.child('dislike').set(ServerValue.increment(-1));
      }
      await userRef.remove();
    } else {
      final newVal = reaction == UserReaction.like ? 'like' : 'dislike';
      if (current == newVal) {
        // Same reaction — toggle off
        await shardRef.child(newVal).set(ServerValue.increment(-1));
        await userRef.remove();
      } else {
        // Switch or new reaction
        if (current != null) {
          await shardRef.child(current).set(ServerValue.increment(-1));
        }
        await shardRef.child(newVal).set(ServerValue.increment(1));
        await userRef.set(newVal);
      }
    }
  }

  Stream<String?> watchReadCursor(String channelId, String userId) {
    return _ref('channel_read_cursors/$channelId/$userId').onValue.map((event) {
      return event.snapshot.value as String?;
    });
  }

  Future<void> setReadCursor(
    String channelId,
    String userId,
    String postId,
  ) async {
    await _ref('channel_read_cursors/$channelId/$userId').set(postId);
  }

  // ── DM Conversations ──────────────────────────────────────

  Stream<List<DmMessage>> watchMessages(String conversationId) {
    return _ref('messages/$conversationId').onValue.map((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return [];
      final messages = <DmMessage>[];
      data.forEach((key, value) {
        if (value is Map) {
          messages.add(DmMessage.fromFirebase(
            key.toString(),
            Map<String, dynamic>.from(value),
          ));
        }
      });
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return messages;
    });
  }

  Future<void> sendMessage(
    String conversationId,
    String body,
    String msgType,
    String clientId,
    int senderId,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _ref('messages/$conversationId').push().set({
      'sender_id': senderId,
      'body': body,
      'msg_type': msgType,
      'image_url': null,
      'client_id': clientId,
      'created_at': now,
      'status': 'sent',
    });
  }

  Future<void> markRead(String conversationId, String userId) async {
    await _ref('conversations/$conversationId/unread/$userId').set(0);
  }

  Future<void> setTyping(
    String conversationId,
    String userId,
    bool isTyping,
  ) async {
    await _ref('typing/$conversationId/$userId').set(isTyping);
  }

  Stream<Map<String, bool>> watchTyping(String conversationId) {
    return _ref('typing/$conversationId').onValue.map((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return {};
      return data.map((k, v) => MapEntry(k.toString(), v == true));
    });
  }

  // ── REST: Backend gatekeeper endpoints ────────────────────

  Future<DmConversation> initConversation(int eventId) async {
    final resp = await dio.post(
      '/chat/conversations',
      data: InitConversationRequest(eventId: eventId).toJson(),
    );
    return DmConversation.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<ChatChannel> createChannel(CreateChannelRequest request) async {
    final resp = await dio.post('/chat/channels', data: request.toJson());
    return ChatChannel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<ChatPost> createPost(String channelId, CreatePostRequest request) async {
    final resp = await dio.post(
      '/chat/channels/$channelId/posts',
      data: request.toJson(),
    );
    return ChatPost.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<String> uploadImage(String targetPath, List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final resp = await dio.post(targetPath, data: formData);
    return (resp.data as Map<String, dynamic>)['image_url'] as String;
  }

  Future<List<DmConversation>> getMyConversations() async {
    final resp = await dio.get('/chat/conversations');
    return (resp.data as List)
        .map((j) => DmConversation.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<DmConversation>> getEventConversations(
    int eventId, {
    String? typeFilter,
  }) async {
    final params = <String, String>{};
    if (typeFilter != null) params['type_filter'] = typeFilter;
    final resp = await dio.get(
      '/chat/conversations/event/$eventId',
      queryParameters: params,
    );
    return (resp.data as List)
        .map((j) => DmConversation.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
