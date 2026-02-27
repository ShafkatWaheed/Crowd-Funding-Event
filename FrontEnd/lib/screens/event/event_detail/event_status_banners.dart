import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event.dart';

class AgeRestrictionBanner extends StatelessWidget {
  final Event event;
  final bool isBlocked;

  const AgeRestrictionBanner({
    super.key,
    required this.event,
    required this.isBlocked,
  });

  @override
  Widget build(BuildContext context) {
    if (!event.ageRestricted) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isBlocked
              ? AppTheme.errorColor.withValues(alpha: 0.1)
              : AppTheme.warningSurfaceOf(context),
          borderRadius: AppRadius.md,
          border: Border.all(
            color: isBlocked
                ? AppTheme.errorColor.withValues(alpha: 0.3)
                : AppTheme.warningColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: AppRadius.pill,
              ),
              child: Text('${event.minAge}+',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isBlocked
                    ? 'You must be at least ${event.minAge} years old to participate in this event.'
                    : 'This event requires attendees to be at least ${event.minAge} years old.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isBlocked
                      ? AppTheme.errorColor
                      : AppTheme.textPrimaryOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PendingCancellationBanner extends StatelessWidget {
  final Map<String, dynamic> data;

  const PendingCancellationBanner({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Container(
        width: double.infinity,
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          color: AppTheme.warningSurfaceOf(context),
          borderRadius: AppRadius.lg,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.15),
                borderRadius: AppRadius.sm,
              ),
              child: Icon(Icons.hourglass_top_rounded,
                  color: context.fundingAccent, size: AppIconSize.sm),
            ),
            AppSpacing.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cancellation Pending Admin Approval',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: context.fundingAccent)),
                  AppSpacing.vXs,
                  Text(
                    data['pledge_percent'] != null
                        ? '${data['pledge_percent']}% funded — admin must approve cancellation'
                        : 'Organizer requested cancellation — awaiting admin review',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryOf(context)),
                  ),
                  if (data['reason'] != null) ...[
                    AppSpacing.vXs,
                    Text('Reason: ${data['reason']}',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryOf(context),
                            fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CancellationReasonBanner extends StatelessWidget {
  final String reason;

  const CancellationReasonBanner({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Container(
        width: double.infinity,
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          color: AppTheme.errorSurfaceOf(context),
          borderRadius: AppRadius.lg,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.12),
                borderRadius: AppRadius.sm,
              ),
              child: const Icon(Icons.cancel_rounded,
                  color: AppTheme.errorColor, size: AppIconSize.sm),
            ),
            AppSpacing.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cancellation Reason',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.errorColor)),
                  AppSpacing.vXs,
                  Text(reason,
                      style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondaryOf(context),
                          height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UnderReviewBanner extends StatelessWidget {
  final String notes;

  const UnderReviewBanner({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Container(
        width: double.infinity,
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          color: AppTheme.warningSurfaceOf(context),
          borderRadius: AppRadius.lg,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.18),
                borderRadius: AppRadius.sm,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.warningColor, size: AppIconSize.sm),
            ),
            AppSpacing.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Under Review',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.warningColor)),
                  AppSpacing.vXs,
                  Text(notes,
                      style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondaryOf(context),
                          height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
