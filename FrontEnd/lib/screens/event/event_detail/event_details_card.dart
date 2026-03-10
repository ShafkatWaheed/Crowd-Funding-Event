import 'package:flutter/material.dart';

import '../../../config/app_icons.dart';
import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event.dart';
import '../../../utils/date_time_utils.dart';
import '../../../widgets/animated_list_item.dart';
import 'event_detail_helpers.dart';

class EventDetailsCard extends StatelessWidget {
  final Event event;
  final bool isOrganizerOrAdmin;

  const EventDetailsCard({
    super.key,
    required this.event,
    this.isOrganizerOrAdmin = true,
  });

  static bool _showTicketStats(Event event) =>
      event.status == EventStatus.selling_tickets ||
      event.status == EventStatus.live ||
      event.status == EventStatus.completed;

  // ── Date window: Starts + Ends connected by a vertical gradient bar ──
  Widget _dateWindow(BuildContext context, bool isDark) {
    final startColor = AppIcons.detailStarts.color(isDark);
    final endColor = AppIcons.detailEnds.color(isDark);
    final hasBoth = event.startTime != null && event.endTime != null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vertical timeline gradient bar
          Container(
            width: 3,
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: hasBoth ? [startColor, endColor] : [startColor, startColor],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                if (event.startTime != null)
                  _dateRow(context, isDark,
                      icon: AppIcons.detailStarts.icon,
                      color: startColor,
                      label: 'Starts',
                      dt: event.startTime!),
                if (hasBoth)
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    color: AppTheme.dividerOf(context),
                  ),
                if (event.endTime != null)
                  _dateRow(context, isDark,
                      icon: AppIcons.detailEnds.icon,
                      color: endColor,
                      label: 'Ends',
                      dt: event.endTime!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateRow(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required Color color,
    required String label,
    required DateTime dt,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.14 : 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryOf(context),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                AppDateFormat.fullDateTime(dt),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Meta chip: icon + stacked label/value ──
  Widget _metaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: AppRadius.md,
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: color.withValues(alpha: 0.65),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final hasDates = event.startTime != null || event.endTime != null;

    return AnimatedListItem(
      index: 4,
      child: Container(
        width: double.infinity,
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: AppRadius.lg,
          boxShadow: AppShadow.card(isDark),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.07))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section header ──
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: AppIconSize.sm,
                    color: AppTheme.textSecondaryOf(context)),
                AppSpacing.hSm,
                Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondaryOf(context),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            AppSpacing.vMd,

            // ── Date timeline ──
            if (hasDates) ...[
              _dateWindow(context, isDark),
              AppSpacing.vMd,
            ],

            // ── TBD date ──
            if (!hasDates)
              EventDetailHelpers.modernInfoRow(
                context,
                AppIcons.detailDateTbd.icon,
                'Date',
                'Announced after funding milestone',
                iconColor: AppIcons.detailDateTbd.color(isDark),
                valueColor: context.fundingAccent,
              ),

            // ── Set Date By row (organizer/admin) ──
            if (event.eventDateDeadline != null && isOrganizerOrAdmin)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: EventDetailHelpers.modernInfoRow(
                  context,
                  AppIcons.detailSetDateBy.icon,
                  'Set Event Date By',
                  AppDateFormat.fullDateTime(event.eventDateDeadline!),
                  iconColor: AppIcons.detailSetDateBy.color(isDark),
                ),
              ),

            // ── Meta chips ──
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metaChip(
                  context,
                  icon: AppIcons.detailRegistration.icon,
                  label: 'Registration',
                  value: event.registrationType.name.replaceAll('_', ' '),
                  color: AppIcons.detailRegistration.color(isDark),
                ),
                if (event.refundDeadlineDays != null)
                  _metaChip(
                    context,
                    icon: AppIcons.detailRefund.icon,
                    label: 'Refund',
                    value: event.refundDeadlineDays! > 0
                        ? '${event.refundDeadlineDays}d before event'
                        : 'Until event starts',
                    color: AppIcons.detailRefund.color(isDark),
                  ),
                if (isOrganizerOrAdmin)
                  _metaChip(
                    context,
                    icon: AppIcons.detailCapacity.icon,
                    label: 'Capacity',
                    value: event.maxCapacity > 0
                        ? EventDetailHelpers.capacityLabel(event)
                        : '${event.registrationCount} registered',
                    color: event.maxCapacity > 0 &&
                            EventDetailHelpers.capacityUsed(event) >=
                                event.maxCapacity
                        ? AppTheme.errorColor
                        : AppIcons.detailCapacity.color(isDark),
                  ),
                if (!isOrganizerOrAdmin && _showTicketStats(event))
                  _metaChip(
                    context,
                    icon: AppIcons.detailTicketsSold.icon,
                    label: 'Tickets Sold',
                    value: event.totalTierCapacity > 0
                        ? '${event.ticketsSoldCount} / ${event.totalTierCapacity}'
                        : '${event.ticketsSoldCount}',
                    color: event.totalTierCapacity > 0 &&
                            event.ticketsSoldCount >= event.totalTierCapacity
                        ? AppTheme.errorColor
                        : AppIcons.detailTicketsSold.color(isDark),
                  ),
                if (event.ticketStrategyName != null && isOrganizerOrAdmin)
                  _metaChip(
                    context,
                    icon: AppIcons.detailTicketStrategy.icon,
                    label: 'Strategy',
                    value: event.ticketStrategyName!,
                    color: AppIcons.detailTicketStrategy.color(isDark),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
