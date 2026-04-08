import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../models/chat.dart';
import '../../providers/chat_firebase_provider.dart';

class MyEventsTab extends StatefulWidget {
  const MyEventsTab({super.key});

  @override
  State<MyEventsTab> createState() => _MyEventsTabState();
}

class _MyEventsTabState extends State<MyEventsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatFirebaseProvider>().loadMyEvents();
    });
  }

  Future<void> _refresh() async {
    await context.read<ChatFirebaseProvider>().loadMyEvents();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatFirebaseProvider>();
    final isDark = AppTheme.isDark(context);

    if (provider.loadingMyEvents && provider.myEventCards.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.myEventCards.isEmpty) {
      return _emptyState(context);
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: provider.myEventCards.length,
        itemBuilder: (context, index) {
          final card = provider.myEventCards[index];
          return _EventCard(card: card, isDark: isDark);
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_outlined,
                size: 64, color: AppTheme.textSecondaryOf(context)),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No Events Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your events will appear here once you purchase tickets or make pledges.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final MyEventCard card;
  final bool isDark;

  const _EventCard({required this.card, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isCompleted = card.isCompleted;
    final opacity = isCompleted ? 0.6 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: AppRadius.lg,
          border: Border.all(
            color: card.isLive
                ? AppTheme.errorColor.withValues(alpha: 0.3)
                : AppTheme.dividerOf(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            if (card.channel != null) _announcementRow(context),
            _dmRow(context),
            if (card.bidInfo != null) _bidRow(context),
            if (card.tickets.isNotEmpty) _ticketsSection(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/events/${card.eventId}'),
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lgValue)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: card.isLive
              ? AppTheme.errorColor.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lgValue)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.eventTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  if (card.venueName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      card.venueName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _statusBadge(context),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context) {
    if (card.isLive) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.errorColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.errorColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      );
    }
    if (card.isCompleted) {
      return Text(
        'Completed',
        style: TextStyle(
          fontSize: 11,
          color: AppTheme.textSecondaryOf(context),
        ),
      );
    }
    if (card.startTime != null) {
      final diff = card.startTime!.difference(DateTime.now());
      if (diff.inDays > 0) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'In ${diff.inDays}d',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.warningColor,
            ),
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }

  Widget _announcementRow(BuildContext context) {
    return _cardRow(
      context,
      icon: Icons.campaign_rounded,
      iconColor: AppTheme.accentColor,
      title: 'Announcements',
      subtitle: 'Tap to view',
      badge: card.channelUnreadCount,
      onTap: () => context.push(
        '/chat/channel/${card.channel!.channelId}?organizer=false',
      ),
    );
  }

  Widget _dmRow(BuildContext context) {
    final conv = card.conversation;
    return _cardRow(
      context,
      icon: Icons.chat_bubble_outline_rounded,
      iconColor: AppTheme.textSecondaryOf(context),
      title: conv != null ? 'Chat with Organizer' : 'Message Organizer',
      subtitle: conv?.lastMessageText ?? (conv != null ? '' : 'Start a conversation'),
      badge: conv?.unreadCount ?? 0,
      trailing: conv == null
          ? Text('New',
              style: TextStyle(fontSize: 11, color: AppTheme.accentColor, fontWeight: FontWeight.w600))
          : null,
      onTap: () async {
        if (conv != null) {
          context.push('/chat/dm/${conv.conversationId}?name=Organizer&writable=${conv.isOpen}');
        } else {
          final provider = context.read<ChatFirebaseProvider>();
          try {
            final newConv = await provider.initConversation(card.eventId);
            if (context.mounted) {
              context.push('/chat/dm/${newConv.conversationId}?name=Organizer&writable=true');
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not start conversation: $e')),
              );
            }
          }
        }
      },
    );
  }

  Widget _bidRow(BuildContext context) {
    final bid = card.bidInfo!;
    return _cardRow(
      context,
      icon: Icons.sell_rounded,
      iconColor: AppTheme.warningColor,
      title: bid.categoryName,
      subtitle: bid.bidStatus,
      onTap: null,
    );
  }

  Widget _ticketsSection(BuildContext context) {
    return Column(
      children: card.tickets.map((ticket) {
        return _cardRow(
          context,
          icon: Icons.confirmation_number_rounded,
          iconColor: AppTheme.successColor,
          title: ticket.tierName ?? 'Ticket',
          subtitle: '#${ticket.ticketCode}',
          trailing: Text('View',
              style: TextStyle(fontSize: 11, color: AppTheme.accentColor, fontWeight: FontWeight.w500)),
          onTap: () => context.push('/tickets/${ticket.id}'),
        );
      }).toList(),
    );
  }

  Widget _cardRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    int badge = 0,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.dividerOf(context), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textPrimaryOf(context),
                      )),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryOf(context),
                        )),
                ],
              ),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$badge',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
