import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event.dart';

class EventDetailHelpers {
  EventDetailHelpers._();

  static Widget modernInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOf(context),
              borderRadius: AppRadius.sm,
            ),
            child: Icon(icon,
                size: AppIconSize.sm,
                color: iconColor ?? AppTheme.textSecondaryOf(context)),
          ),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryOf(context),
                        letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            valueColor ?? AppTheme.textPrimaryOf(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget statusPill(BuildContext context, EventStatus status) {
    final label = statusLabel(status);
    final bgColor = statusColor(context, status);
    final fgColor = statusForeground(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: fgColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: fgColor,
                  letterSpacing: 0.3)),
        ],
      ),
    );
  }

  static Widget tagPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.2)),
        ],
      ),
    );
  }

  static Widget sectionTitle(BuildContext context, String title,
      {IconData? icon, Color? iconColor}) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: (iconColor ?? AppTheme.primaryColor)
                  .withValues(alpha: 0.1),
              borderRadius: AppRadius.sm,
            ),
            child: Icon(icon,
                size: AppIconSize.sm,
                color: iconColor ?? AppTheme.primaryColor),
          ),
          AppSpacing.hSm,
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimaryOf(context),
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }

  static Widget infoBanner(String text, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: AppIconSize.md),
          AppSpacing.hSm,
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  static Widget previewPlaceholder(
      BuildContext context, String message, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        borderRadius: AppRadius.md,
        color: AppTheme.surfaceOf(context),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: AppTheme.textSecondaryOf(context),
              size: AppIconSize.md),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: AppTheme.textSecondaryOf(context),
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  static Widget previewBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.08),
        borderRadius: AppRadius.md,
        border: Border.all(
            color: AppTheme.warningColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_rounded,
              size: AppIconSize.sm, color: AppTheme.warningColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This is a preview. Some sections appear after publishing.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryOf(context),
                  height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  static Widget trustBadgePill(BuildContext context, Event event) {
    final label = event.organizerTrustLabel;
    final score = event.organizerTrustScore;
    final Color color;
    final IconData icon;
    switch (label) {
      case 'Excellent':
        color = context.trustHigh;
        icon = Icons.verified_rounded;
      case 'Good':
        color = AppTheme.accentColor;
        icon = Icons.verified_outlined;
      case 'Fair':
        color = context.trustMedium;
        icon = Icons.shield_outlined;
      case 'Low':
        color = context.trustLow;
        icon = Icons.warning_amber_rounded;
      default:
        color = AppTheme.textSecondaryOf(context);
        icon = Icons.person_outline;
    }
    return Tooltip(
      message:
          '${event.organizerCompletedEvents} completed / ${event.organizerPublishedEvents} published events',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.pill,
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              '$label ${(score * 100).toInt()}%',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.2),
            ),
          ],
        ),
      ),
    );
  }

  static String statusLabel(EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return 'DRAFT';
      case EventStatus.pending_approval:
        return 'WAITING APPROVAL';
      case EventStatus.approved:
        return 'PUBLISHED';
      case EventStatus.selling_tickets:
        return 'SELLING TICKETS';
      case EventStatus.waiting_event_date:
        return 'AWAITING EVENT DATE';
      case EventStatus.live:
        return 'LIVE';
      case EventStatus.completed:
        return 'COMPLETED';
      case EventStatus.cancelled:
        return 'CANCELLED';
      case EventStatus.under_review:
        return 'UNDER REVIEW';
    }
  }

  static Color statusColor(BuildContext context, EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return AppTheme.textSecondaryOf(context).withValues(alpha: 0.2);
      case EventStatus.pending_approval:
        return AppTheme.warningColor.withValues(alpha: 0.2);
      case EventStatus.approved:
        return AppTheme.successColor.withValues(alpha: 0.2);
      case EventStatus.selling_tickets:
        return context.ticketAccent.withValues(alpha: 0.2);
      case EventStatus.waiting_event_date:
        return context.fundingAccent.withValues(alpha: 0.2);
      case EventStatus.live:
        return AppTheme.secondaryColor.withValues(alpha: 0.2);
      case EventStatus.completed:
        return AppTheme.textSecondaryOf(context).withValues(alpha: 0.2);
      case EventStatus.cancelled:
        return AppTheme.errorColor.withValues(alpha: 0.2);
      case EventStatus.under_review:
        return AppTheme.warningColor.withValues(alpha: 0.2);
    }
  }

  static Color statusForeground(BuildContext context, EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return AppTheme.textSecondaryOf(context);
      case EventStatus.pending_approval:
        return context.statusPending;
      case EventStatus.approved:
        return AppTheme.secondaryColor;
      case EventStatus.selling_tickets:
        return context.statusSelling;
      case EventStatus.waiting_event_date:
        return context.statusWaiting;
      case EventStatus.live:
        return AppTheme.accentColor;
      case EventStatus.completed:
        return context.statusCompleted;
      case EventStatus.cancelled:
        return AppTheme.errorColor;
      case EventStatus.under_review:
        return AppTheme.warningColor;
    }
  }

  static int capacityUsed(Event event) =>
      event.totalReservedSpots + event.ticketsSoldCount;

  static String capacityLabel(Event event) {
    final used = capacityUsed(event);
    return '$used / ${event.maxCapacity}';
  }
}
