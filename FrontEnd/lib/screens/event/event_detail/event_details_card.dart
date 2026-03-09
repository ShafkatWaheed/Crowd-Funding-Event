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

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return AnimatedListItem(
      index: 4,
      child: Container(
        width: double.infinity,
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: AppRadius.lg,
          boxShadow: AppShadow.card(isDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            if (event.startTime != null)
              EventDetailHelpers.modernInfoRow(context,
                  AppIcons.detailStarts.icon, 'Starts',
                  AppDateFormat.fullDateTime(event.startTime!),
                  iconColor: AppIcons.detailStarts.color(isDark)),
            if (event.endTime != null)
              EventDetailHelpers.modernInfoRow(context,
                  AppIcons.detailEnds.icon, 'Ends',
                  AppDateFormat.fullDateTime(event.endTime!),
                  iconColor: AppIcons.detailEnds.color(isDark)),
            if (event.startTime == null && event.endTime == null)
              EventDetailHelpers.modernInfoRow(context,
                  AppIcons.detailDateTbd.icon, 'Date',
                  'Announced after funding milestone',
                  iconColor: AppIcons.detailDateTbd.color(isDark),
                  valueColor: context.fundingAccent),
            if (isOrganizerOrAdmin)
              EventDetailHelpers.modernInfoRow(context,
                  AppIcons.detailCapacity.icon, 'Capacity',
                  event.maxCapacity > 0
                      ? EventDetailHelpers.capacityLabel(event)
                      : '${event.registrationCount} registered',
                  iconColor: AppIcons.detailCapacity.color(isDark),
                  valueColor: event.maxCapacity > 0 &&
                          EventDetailHelpers.capacityUsed(event) >=
                              event.maxCapacity
                      ? AppTheme.errorColor
                      : null),
            if (!isOrganizerOrAdmin && _showTicketStats(event))
              EventDetailHelpers.modernInfoRow(context,
                  AppIcons.detailTicketsSold.icon, 'Tickets Sold',
                  event.totalTierCapacity > 0
                      ? '${event.ticketsSoldCount} / ${event.totalTierCapacity}'
                      : '${event.ticketsSoldCount}',
                  iconColor: AppIcons.detailTicketsSold.color(isDark),
                  valueColor: event.totalTierCapacity > 0 &&
                          event.ticketsSoldCount >= event.totalTierCapacity
                      ? AppTheme.errorColor
                      : null),
            EventDetailHelpers.modernInfoRow(context,
                AppIcons.detailRegistration.icon, 'Registration',
                event.registrationType.name.replaceAll('_', ' '),
                iconColor: AppIcons.detailRegistration.color(isDark)),
            if (event.eventDateDeadline != null)
              EventDetailHelpers.modernInfoRow(context,
                  AppIcons.detailSetDateBy.icon, 'Set Event Date By',
                  AppDateFormat.fullDateTime(event.eventDateDeadline!),
                  iconColor: AppIcons.detailSetDateBy.color(isDark)),
            if (event.ticketStrategyName != null && isOrganizerOrAdmin)
              EventDetailHelpers.modernInfoRow(context,
                  AppIcons.detailTicketStrategy.icon, 'Ticket Strategy',
                  event.ticketStrategyName!,
                  iconColor: AppIcons.detailTicketStrategy.color(isDark)),
            if (event.refundDeadlineDays != null)
              EventDetailHelpers.modernInfoRow(context,
                  AppIcons.detailRefund.icon, 'Refund',
                  event.refundDeadlineDays! > 0
                      ? '${event.refundDeadlineDays}d before event starts'
                      : 'Until event starts',
                  iconColor: AppIcons.detailRefund.color(isDark),
                  valueColor: AppTheme.secondaryColor),
          ],
        ),
      ),
    );
  }
}
