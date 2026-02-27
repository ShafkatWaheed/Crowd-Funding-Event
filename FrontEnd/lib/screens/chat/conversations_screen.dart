import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/chat_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0.5,
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chat, _) {
          if (chat.conversationsLoading && chat.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (chat.conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(fontSize: 16, color: AppTheme.textSecondaryOf(context)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chat with organizers or sponsors on bids',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context)),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => chat.loadConversations(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: chat.conversations.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 72,
                color: Colors.grey.withValues(alpha: 0.15),
              ),
              itemBuilder: (context, index) {
                final conv = chat.conversations[index];
                return _ConversationTile(conversation: conv);
              },
            ),
          );
        },
      ),
    );
  }
}


class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().user?.id ?? 0;
    final isSponsor = conversation.sponsorUserId == currentUserId;
    final participantLabel = isSponsor ? 'Organizer' : 'Sponsor';

    final statusColor = _bidStatusColor(conversation.bidStatus);
    final timeStr = conversation.lastMessageAt != null
        ? _formatTime(conversation.lastMessageAt!)
        : '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppTheme.accentColor.withValues(alpha: 0.12),
        child: Text(
          participantLabel[0],
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.accentColor,
            fontSize: 18,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${conversation.eventTitle} - ${conversation.categoryName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: conversation.unreadCount > 0
                    ? FontWeight.w700
                    : FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 12,
              color: conversation.unreadCount > 0
                  ? AppTheme.accentColor
                  : AppTheme.textSecondaryOf(context),
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              conversation.bidStatus,
              style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              participantLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ),
          if (conversation.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${conversation.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      onTap: () => context.push('/chat/bid/${conversation.bidId}'),
    );
  }

  Color _bidStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warningColor;
      case 'accepted':
      case 'paid':
        return AppTheme.successColor;
      case 'rejected':
      case 'withdrawn':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return DateFormat('HH:mm').format(local);
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return 'Yesterday';
    }
    return DateFormat('MMM d').format(local);
  }
}
