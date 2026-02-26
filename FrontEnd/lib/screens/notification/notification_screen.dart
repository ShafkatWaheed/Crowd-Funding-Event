import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/shimmer_loaders.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  String _category = 'all';

  @override
  void initState() {
    super.initState();
    context.read<NotificationProvider>().loadNotifications();
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'registration_confirmed':
        return Icons.check_circle_outline;
      case 'registration_waitlisted':
        return Icons.hourglass_top;
      case 'waitlist_approved':
        return Icons.thumb_up_outlined;
      case 'waitlist_rejected':
        return Icons.thumb_down_outlined;
      case 'pledge_confirmed':
        return Icons.volunteer_activism;
      case 'funding_goal_reached':
        return Icons.flag_outlined;
      case 'milestone_reached':
        return Icons.emoji_events_outlined;
      case 'ticket_purchased':
        return Icons.confirmation_number_outlined;
      case 'ticket_waitlist_approved':
        return Icons.check_circle;
      case 'ticket_waitlist_rejected':
        return Icons.cancel_outlined;
      case 'refund_issued':
        return Icons.money_off;
      case 'event_cancelled':
        return Icons.event_busy;
      case 'event_status_changed':
      case 'event_updated':
        return Icons.sync;
      case 'event_approved':
        return Icons.verified;
      case 'event_rejected':
        return Icons.block;
      case 'schedule_updated':
        return Icons.schedule;
      case 'bid_received':
        return Icons.gavel;
      case 'bid_accepted':
        return Icons.handshake;
      case 'bid_rejected':
        return Icons.cancel;
      case 'sponsor_payment_received':
        return Icons.payment;
      case 'sponsor_refunded':
        return Icons.currency_exchange;
      case 'sponsor_ticket_generated':
        return Icons.badge;
      case 'new_rating_received':
        return Icons.star_outline;
      case 'bookmarked_event_update':
        return Icons.bookmark;
      case 'event_under_review':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    if (type.contains('cancel') || type.contains('reject')) return AppTheme.errorColor;
    if (type.contains('approved') || type.contains('confirmed') || type.contains('accepted')) {
      return AppTheme.successColor;
    }
    if (type == 'sponsor_payment_received') return AppTheme.successColor;
    if (type == 'sponsor_refunded') return AppTheme.warningColor;
    if (type.contains('waitlist')) return AppTheme.warningColor;
    if (type.contains('bid')) return AppTheme.accentColor;
    return AppTheme.textSecondary;
  }

  String _actionHint(String type) {
    switch (type) {
      case 'ticket_purchased':
        return 'View ticket';
      case 'pledge_confirmed':
      case 'funding_goal_reached':
      case 'milestone_reached':
        return 'View pledge';
      case 'bid_received':
      case 'bid_accepted':
      case 'bid_rejected':
        return 'View bid';
      case 'sponsor_payment_received':
      case 'sponsor_refunded':
        return 'View payment';
      case 'new_rating_received':
        return 'See ratings';
      case 'schedule_updated':
        return 'View schedule';
      case 'refund_issued':
        return 'View refund';
      default:
        return 'View event';
    }
  }

  String _categoryForType(String type) {
    if (type.contains('ticket') || type.contains('waitlist')) return 'tickets';
    if (type.contains('pledge') || type.contains('funding') || type.contains('milestone')) return 'funding';
    if (type.contains('bid') || type.contains('sponsor')) return 'sponsors';
    if (type.contains('event') || type.contains('schedule') || type.contains('registration') || type.contains('rating') || type.contains('bookmark')) return 'events';
    return 'events';
  }

  void _navigateToNotification(Map<String, dynamic> notif) {
    final provider = context.read<NotificationProvider>();
    if (notif['is_read'] != true) {
      provider.markRead(notif['id']);
    }

    final type = notif['type'] as String? ?? '';
    final data = notif['data'] as Map<String, dynamic>? ?? {};
    final eventId = data['event_id'];

    if (eventId == null) return;

    switch (type) {
      case 'ticket_purchased':
        context.push('/events/$eventId');
      case 'pledge_confirmed':
      case 'funding_goal_reached':
        context.push('/events/$eventId');
      case 'bid_received':
      case 'bid_accepted':
      case 'bid_rejected':
        context.push('/events/$eventId');
      case 'new_rating_received':
        context.push('/events/$eventId');
      case 'schedule_updated':
        context.push('/events/$eventId');
      default:
        context.push('/events/$eventId');
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(dt);
  }

  String _dateGroup(String? iso) {
    if (iso == null) return 'Earlier';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'Earlier';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notifDate = DateTime(dt.year, dt.month, dt.day);
    if (notifDate == today) return 'Today';
    if (notifDate == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (now.difference(dt).inDays < 7) return 'This Week';
    return 'Earlier';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => context.read<NotificationProvider>().markAllRead(),
            child: Text('Mark all read', style: TextStyle(color: AppTheme.accentColor)),
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (ctx, provider, _) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return ListView.builder(
              itemCount: 8,
              itemBuilder: (_, __) => const ShimmerEventCard(),
            );
          }
          if (provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64,
                      color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text("You're all caught up!",
                      style: TextStyle(color: AppTheme.textPrimaryOf(context), fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('No notifications to show',
                      style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 14)),
                ],
              ),
            );
          }

          final filtered = _category == 'all'
              ? provider.notifications
              : provider.notifications.where((n) => _categoryForType(n['type'] ?? '') == _category).toList();

          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final n in filtered) {
            final group = _dateGroup(n['created_at']);
            grouped.putIfAbsent(group, () => []).add(n);
          }
          final groupOrder = ['Today', 'Yesterday', 'This Week', 'Earlier'];
          final orderedGroups = groupOrder.where((g) => grouped.containsKey(g)).toList();

          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _categoryChip('All', 'all'),
                    _categoryChip('Events', 'events'),
                    _categoryChip('Tickets', 'tickets'),
                    _categoryChip('Funding', 'funding'),
                    _categoryChip('Sponsors', 'sponsors'),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.loadNotifications(),
                  child: ListView.builder(
                    itemCount: orderedGroups.fold<int>(0, (sum, g) => sum + 1 + grouped[g]!.length),
                    itemBuilder: (ctx, index) {
                      int cursor = 0;
                      for (final group in orderedGroups) {
                        if (index == cursor) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text(group, style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13,
                              color: AppTheme.textSecondaryOf(context),
                              letterSpacing: 0.5,
                            )),
                          );
                        }
                        cursor++;
                        final items = grouped[group]!;
                        if (index < cursor + items.length) {
                          final n = items[index - cursor];
                          return _buildNotificationCard(n);
                        }
                        cursor += items.length;
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _categoryChip(String label, String value) {
    final selected = _category == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(
          fontSize: 13,
          color: selected ? Colors.white : AppTheme.textPrimaryOf(context),
        )),
        selected: selected,
        selectedColor: AppTheme.accentColor,
        backgroundColor: AppTheme.inputFillOf(context),
        onSelected: (_) => setState(() => _category = value),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> n) {
    final type = n['type'] ?? '';
    final isRead = n['is_read'] == true;
    final color = _colorForType(type);

    return Dismissible(
      key: ValueKey(n['id']),
      direction: DismissDirection.horizontal,
      background: Container(
        color: AppTheme.accentColor,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.mark_email_read, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: AppTheme.errorColor,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          context.read<NotificationProvider>().markRead(n['id']);
          return false;
        }
        return true;
      },
      onDismissed: (_) {
        context.read<NotificationProvider>().deleteNotification(n['id']);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Card(
          color: isRead ? AppTheme.cardOf(context) : AppTheme.accentColor.withValues(alpha: 0.06),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _navigateToNotification(n),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_iconForType(type), color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n['title'] ?? '',
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          n['message'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _actionHint(type),
                          style: TextStyle(color: AppTheme.accentColor, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(n['created_at']),
                        style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 11),
                      ),
                      if (!isRead) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
