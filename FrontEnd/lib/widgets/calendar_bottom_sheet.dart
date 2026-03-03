import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../config/design_tokens.dart';
import '../models/event.dart';
import '../providers/event_provider.dart';
import '../utils/share_utils.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_toast.dart';

Future<void> showCalendarSheet(BuildContext context, Event event) {
  return showAppBottomSheet(
    context: context,
    builder: (_) => _CalendarSheetContent(event: event),
  );
}

class _CalendarSheetContent extends StatelessWidget {
  final Event event;
  const _CalendarSheetContent({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add to Calendar',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          AppSpacing.vLg,

          _CalendarOption(
            icon: Icons.event_rounded,
            iconColor: const Color(0xFF4285F4),
            label: 'Google Calendar',
            subtitle: 'Open in Google Calendar',
            onTap: () => _openGoogleCalendar(context),
          ),
          Divider(height: 1, color: AppTheme.dividerOf(context)),
          _CalendarOption(
            icon: Icons.download_rounded,
            iconColor: AppTheme.textSecondaryOf(context),
            label: 'Download .ics',
            subtitle: 'Works with Outlook, Apple Calendar, etc.',
            onTap: () => _downloadIcs(context),
          ),

          AppSpacing.vSm,
        ],
      ),
    );
  }

  Future<void> _openGoogleCalendar(BuildContext context) async {
    Navigator.pop(context);

    final uri = ShareUtils.googleCalendarUrl(
      title: event.title,
      startTime: event.startTime,
      endTime: event.endTime,
      description: event.description,
      location: ShareUtils.venueString(event),
    );

    if (uri == null) {
      if (context.mounted) {
        AppToast.warning(context, 'Event has no date set yet');
      }
      return;
    }

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        AppToast.error(context, 'Could not open Google Calendar');
      }
    }
  }

  Future<void> _downloadIcs(BuildContext context) async {
    Navigator.pop(context);
    final repo = context.read<EventProvider>();
    final url = Uri.parse(repo.calendarUrl(event.id));

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        AppToast.error(context, 'Could not download calendar file');
      }
    }
  }
}

class _CalendarOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _CalendarOption({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.md,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: AppRadius.md,
              ),
              child: Icon(icon, color: iconColor, size: AppIconSize.lg),
            ),
            AppSpacing.hLg,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondaryOf(context),
              size: AppIconSize.md,
            ),
          ],
        ),
      ),
    );
  }
}
