import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../models/chat.dart';
import '../../providers/chat_firebase_provider.dart';

/// Event chat hub for organizers — Phase 1: Customer section only.
class OrganizerEventChatHub extends StatefulWidget {
  final int eventId;

  const OrganizerEventChatHub({super.key, required this.eventId});

  @override
  State<OrganizerEventChatHub> createState() => _OrganizerEventChatHubState();
}

class _OrganizerEventChatHubState extends State<OrganizerEventChatHub> {
  List<DmConversation> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final convs = await context
          .read<ChatFirebaseProvider>()
          .getEventConversations(widget.eventId, typeFilter: 'customer');
      if (mounted) {
        setState(() {
          _conversations = convs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelId = 'event_${widget.eventId}_customer';

    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(
        title: const Text('Event Chat'),
        backgroundColor: AppTheme.cardOf(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadConversations,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // Section header: Customers
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'CUSTOMERS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  // Announcements row
                  _SectionTile(
                    icon: Icons.campaign_rounded,
                    iconColor: AppTheme.accentColor,
                    title: 'Announcements',
                    subtitle: 'Post announcements to customers',
                    onTap: () => context.push(
                      '/chat/channel/$channelId?organizer=true',
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Individual DMs
                  if (_conversations.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(
                        child: Text(
                          'No customer messages yet',
                          style: TextStyle(
                            color: AppTheme.textSecondaryOf(context),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._conversations.map((conv) => _ConversationTile(
                          conversation: conv,
                        )),
                ],
              ),
            ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SectionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.08),
        borderRadius: AppRadius.md,
        border: Border.all(color: iconColor.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondaryOf(context),
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final DmConversation conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: AppRadius.md,
        border: Border.all(color: AppTheme.dividerOf(context), width: 0.5),
      ),
      child: ListTile(
        onTap: () {
          final name = conversation.participantName ?? 'Customer';
          final writable = conversation.isOpen;
          context.push(
            '/chat/dm/${conversation.conversationId}?name=${Uri.encodeComponent(name)}&writable=$writable',
          );
        },
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: AppTheme.textSecondaryOf(context).withValues(alpha: 0.1),
          child: Text(
            (conversation.participantName ?? '?')[0].toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),
        ),
        title: Text(
          conversation.participantName ?? 'Customer',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        subtitle: conversation.lastMessageText != null
            ? Text(
                conversation.lastMessageText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryOf(context),
                ),
              )
            : null,
        trailing: conversation.unreadCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${conversation.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
