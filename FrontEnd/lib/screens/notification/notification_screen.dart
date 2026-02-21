import 'package:flutter/material.dart';
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
      case 'sponsor_ticket_generated':
        return Icons.badge;
      case 'new_rating_received':
        return Icons.star_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    if (type.contains('cancel') || type.contains('reject')) return AppTheme.errorColor;
    if (type.contains('approved') || type.contains('confirmed') || type.contains('accepted')) {
      return AppTheme.successColor;
    }
    if (type.contains('waitlist')) return AppTheme.warningColor;
    if (type.contains('bid')) return AppTheme.accentColor;
    return AppTheme.textSecondary;
  }

  void _onTapNotification(Map<String, dynamic> notif) {
    final provider = context.read<NotificationProvider>();
    if (notif['is_read'] != true) {
      provider.markRead(notif['id']);
    }
    final data = notif['data'] as Map<String, dynamic>?;
    if (data != null && data['event_id'] != null) {
      Navigator.pushNamed(context, '/events/${data['event_id']}');
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat.MMMd().format(dt);
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
                      color: AppTheme.textSecondaryOf(context)),
                  const SizedBox(height: 12),
                  Text('No notifications yet',
                      style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 16)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => provider.loadNotifications(),
            child: ListView.separated(
              itemCount: provider.notifications.length,
              separatorBuilder: (_, __) => Divider(
                height: 1, color: AppTheme.dividerOf(context),
              ),
              itemBuilder: (ctx, i) {
                final n = provider.notifications[i];
                final type = n['type'] ?? '';
                final isRead = n['is_read'] == true;
                return ListTile(
                  tileColor: isRead ? null : AppTheme.accentColor.withValues(alpha: 0.05),
                  leading: CircleAvatar(
                    backgroundColor: _colorForType(type).withValues(alpha: 0.15),
                    child: Icon(_iconForType(type), color: _colorForType(type), size: 20),
                  ),
                  title: Text(
                    n['title'] ?? '',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  subtitle: Text(
                    n['message'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13),
                  ),
                  trailing: Text(
                    _formatTime(n['created_at']),
                    style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 11),
                  ),
                  onTap: () => _onTapNotification(n),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
