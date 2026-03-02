import '../models/chat_message.dart';
import 'base_repository.dart';

/// Repository for sponsor-negotiation chat endpoints.
class ChatRepository extends BaseRepository {
  ChatRepository(super.dio);

  /// Fetch paginated messages for a bid conversation.
  Future<List<ChatMessage>> getChatMessages(
    int bidId, {
    String? before,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (before != null) params['before'] = before;
    final resp = await dio.get(
      '/chat/bids/$bidId/messages',
      queryParameters: params,
    );
    return (resp.data as List)
        .map((j) => ChatMessage.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// List all conversations for the current user.
  Future<List<ChatConversation>> getChatConversations() async {
    final resp = await dio.get('/chat/conversations');
    return (resp.data as List)
        .map((j) => ChatConversation.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Mark messages as read up to [messageId] in the given bid conversation.
  Future<void> markChatRead(int bidId, String messageId) async {
    await dio.post(
      '/chat/bids/$bidId/read',
      queryParameters: {'message_id': messageId},
    );
  }
}
