import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../models/chat_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class ConversationsScreen extends StatefulWidget {
  final bool embedded;
  const ConversationsScreen({super.key, this.embedded = false});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ChatConversation> _filterConversations(List<ChatConversation> conversations) {
    if (_searchQuery.isEmpty) return conversations;
    final query = _searchQuery.toLowerCase();
    final currentUserId = context.read<AuthProvider>().user?.id ?? 0;
    return conversations.where((conv) {
      final isSponsor = conv.sponsorUserId == currentUserId;
      final participantName = isSponsor ? conv.organizerName : conv.sponsorName;
      return participantName.toLowerCase().contains(query) ||
          conv.eventTitle.toLowerCase().contains(query) ||
          conv.categoryName.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildBody() {
    return Consumer<ChatProvider>(
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
        final filtered = _filterConversations(chat.conversations);
        if (filtered.isEmpty && _searchQuery.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  'No results for "$_searchQuery"',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryOf(context)),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => chat.loadConversations(),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 72,
              color: Colors.grey.withValues(alpha: 0.15),
            ),
            itemBuilder: (context, index) {
              final conv = filtered[index];
              return _ConversationTile(conversation: conv);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      final isDark = AppTheme.isDark(context);
      return Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardOf(context),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppRadius.xxlValue),
                bottomRight: Radius.circular(AppRadius.xxlValue),
              ),
              boxShadow: AppShadow.soft(isDark),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl, 56, AppSpacing.xxl, AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sponsor Channel',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search conversations...',
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppTheme.textSecondaryOf(context),
                      size: AppIconSize.md,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: AppIconSize.md),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.inputFillOf(context),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.md,
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0.5,
      ),
      body: _buildBody(),
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
    final participantName = isSponsor
        ? conversation.organizerName
        : conversation.sponsorName;
    final displayName = participantName.isNotEmpty
        ? participantName
        : (isSponsor ? 'Organizer' : 'Sponsor');
    final roleLabel = isSponsor ? 'Organizer' : 'Sponsor';

    final statusColor = _bidStatusColor(conversation.bidStatus);
    final hasMessages = conversation.lastMessageAt != null;
    final timeStr = hasMessages
        ? _formatTime(conversation.lastMessageAt!)
        : 'No messages yet';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppTheme.accentColor.withValues(alpha: 0.12),
        child: Text(
          displayName[0].toUpperCase(),
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
              displayName,
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
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${conversation.eventTitle} · $roleLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
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
      onTap: () => context.push(
        '/chat/bid/${conversation.bidId}?name=${Uri.encodeComponent(displayName)}&writable=${conversation.isWritable}&eventId=${conversation.eventId}',
      ),
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
