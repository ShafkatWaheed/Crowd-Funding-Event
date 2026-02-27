import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../config/design_tokens.dart';
import '../../../../config/theme.dart';
import 'dashboard_helpers.dart';

class DashboardActivityFeed extends StatefulWidget {
  final List<dynamic> feed;

  const DashboardActivityFeed({
    super.key,
    required this.feed,
  });

  @override
  State<DashboardActivityFeed> createState() =>
      _DashboardActivityFeedState();
}

class _DashboardActivityFeedState extends State<DashboardActivityFeed> {
  int? _filterEventId;

  @override
  Widget build(BuildContext context) {
    if (widget.feed.isEmpty) return const SizedBox.shrink();

    final isDark = AppTheme.isDark(context);
    final uniqueEvents = <int, String>{};
    for (final item in widget.feed) {
      final m = item as Map<String, dynamic>;
      uniqueEvents[m['event_id'] as int] =
          m['event_title'] as String? ?? '';
    }

    final showFilter = uniqueEvents.length >= 4;
    final filtered = _filterEventId == null
        ? widget.feed
        : widget.feed
            .where(
                (item) => (item as Map)['event_id'] == _filterEventId)
            .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_rounded,
                  size: AppIconSize.sm,
                  color: context.fundingAccent),
              AppSpacing.hSm,
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
            ],
          ),
          if (showFilter) ...[
            AppSpacing.vMd,
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _feedFilterChip(context, label: 'All', eventId: null),
                  for (final entry in uniqueEvents.entries) ...[
                    AppSpacing.hSm,
                    _feedFilterChip(
                      context,
                      label: entry.value.length > 20
                          ? '${entry.value.substring(0, 20)}...'
                          : entry.value,
                      eventId: entry.key,
                    ),
                  ],
                ],
              ),
            ),
          ],
          AppSpacing.vMd,
          for (int i = 0; i < filtered.length; i++)
            _buildActivityItem(
                context, filtered[i] as Map<String, dynamic>, i, isDark),
        ],
      ),
    );
  }

  Widget _feedFilterChip(BuildContext context,
      {required String label, required int? eventId}) {
    final selected = _filterEventId == eventId;
    return GestureDetector(
      onTap: () => setState(() => _filterEventId = eventId),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentColor
              : AppTheme.surfaceOf(context),
          borderRadius: AppRadius.pill,
          border: selected
              ? null
              : Border.all(color: AppTheme.dividerOf(context)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : AppTheme.textSecondaryOf(context),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context,
      Map<String, dynamic> item, int index, bool isDark) {
    final type = item['type'] as String? ?? '';
    final actorName = item['actor_name'] as String? ?? 'Someone';
    final eventTitle = item['event_title'] as String? ?? '';
    final amountCents = item['amount_cents'] as int? ?? 0;
    final createdAt = item['created_at'] as String? ?? '';

    IconData icon;
    Color iconColor;
    String action;
    switch (type) {
      case 'ticket_sale':
        icon = Icons.confirmation_number_rounded;
        iconColor = context.ticketAccent;
        action = 'bought a ticket';
      case 'pledge':
        icon = Icons.volunteer_activism_rounded;
        iconColor = context.fundingAccent;
        action = 'pledged';
      case 'sponsor_bid':
        icon = Icons.handshake_rounded;
        iconColor = context.sponsorAccent;
        final bidStatus =
            (item['extra'] as Map?)?['bid_status'] as String? ?? '';
        action = 'bid ($bidStatus)';
      default:
        icon = Icons.circle;
        iconColor = AppTheme.textSecondaryOf(context);
        action = 'activity';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: AppRadius.md,
          boxShadow: AppShadow.card(isDark),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color:
                    iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: AppRadius.sm,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            AppSpacing.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: actorName,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.textPrimaryOf(context)),
                      ),
                      TextSpan(
                        text: ' $action',
                        style: TextStyle(
                            fontSize: 13,
                            color:
                                AppTheme.textSecondaryOf(context)),
                      ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    eventTitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryOf(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            AppSpacing.hSm,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  dashFormatCents(amountCents),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.successColor),
                ),
                Text(
                  dashRelativeTime(createdAt),
                  style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondaryOf(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (60 * index).ms, duration: 300.ms)
        .slideY(begin: 0.05, duration: 300.ms, curve: Curves.easeOut);
  }
}
