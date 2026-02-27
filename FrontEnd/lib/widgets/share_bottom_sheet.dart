import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../config/design_tokens.dart';
import '../models/event.dart';
import '../models/ticket.dart';
import '../utils/share_utils.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_toast.dart';

Future<void> showShareSheet(BuildContext context, Event event) {
  return showAppBottomSheet(
    context: context,
    builder: (_) => _ShareSheetContent(event: event),
  );
}

Future<void> showTicketShareSheet(BuildContext context, TicketSale ticket) {
  return showAppBottomSheet(
    context: context,
    builder: (_) => _TicketShareSheetContent(ticket: ticket),
  );
}

class _ShareSheetContent extends StatelessWidget {
  final Event event;
  const _ShareSheetContent({required this.event});

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppTheme.textSecondaryOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share Event',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          AppSpacing.vLg,

          _ShareOption(
            icon: Icons.email_outlined,
            iconColor: const Color(0xFFEA4335),
            label: 'Gmail',
            subtitle: 'Send via email',
            onTap: () => _openGmail(context),
          ),
          _divider(context),
          _ShareOption(
            icon: Icons.chat_rounded,
            iconColor: const Color(0xFF25D366),
            label: 'WhatsApp',
            subtitle: 'Share with contacts',
            onTap: () => _openWhatsApp(context),
          ),
          _divider(context),
          _ShareOption(
            icon: Icons.copy_rounded,
            iconColor: textSecondary,
            label: 'Copy Link',
            subtitle: 'Copy event URL to clipboard',
            onTap: () => _copyLink(context),
          ),
          _divider(context),
          _ShareOption(
            icon: Icons.share_rounded,
            iconColor: AppTheme.accentColor,
            label: 'More...',
            subtitle: 'Other apps',
            onTap: () => _nativeShare(context),
          ),

          AppSpacing.vSm,
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(height: 1, color: AppTheme.dividerOf(context));
  }

  Future<void> _openGmail(BuildContext context) async {
    Navigator.pop(context);
    final uri = ShareUtils.gmailUrl(
      event.title,
      event.id,
      dateInfo: ShareUtils.dateInfoString(event),
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        AppToast.error(context, 'Could not open Gmail');
      }
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    Navigator.pop(context);
    final uri = ShareUtils.whatsAppUrl(event.title, event.id);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        AppToast.error(context, 'Could not open WhatsApp');
      }
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    Navigator.pop(context);
    final url = ShareUtils.eventUrl(event.id);
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      AppToast.success(context, 'Event link copied!');
    }
  }

  Future<void> _nativeShare(BuildContext context) async {
    Navigator.pop(context);
    final text = ShareUtils.shareText(event.title, event.id);
    await Share.share(text);
  }
}

class _TicketShareSheetContent extends StatelessWidget {
  final TicketSale ticket;
  const _TicketShareSheetContent({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppTheme.textSecondaryOf(context);
    final eventTitle = ticket.eventTitle ?? 'Event';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share Ticket',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          AppSpacing.vLg,

          _ShareOption(
            icon: Icons.email_outlined,
            iconColor: const Color(0xFFEA4335),
            label: 'Gmail',
            subtitle: 'Send via email',
            onTap: () => _openGmail(context, eventTitle),
          ),
          Divider(height: 1, color: AppTheme.dividerOf(context)),
          _ShareOption(
            icon: Icons.chat_rounded,
            iconColor: const Color(0xFF25D366),
            label: 'WhatsApp',
            subtitle: 'Share with contacts',
            onTap: () => _openWhatsApp(context, eventTitle),
          ),
          Divider(height: 1, color: AppTheme.dividerOf(context)),
          _ShareOption(
            icon: Icons.copy_rounded,
            iconColor: textSecondary,
            label: 'Copy Link',
            subtitle: 'Copy event URL to clipboard',
            onTap: () => _copyLink(context),
          ),
          Divider(height: 1, color: AppTheme.dividerOf(context)),
          _ShareOption(
            icon: Icons.share_rounded,
            iconColor: AppTheme.accentColor,
            label: 'More...',
            subtitle: 'Other apps',
            onTap: () => _nativeShare(context, eventTitle),
          ),

          AppSpacing.vSm,
        ],
      ),
    );
  }

  Future<void> _openGmail(BuildContext context, String title) async {
    Navigator.pop(context);
    final uri = ShareUtils.ticketGmailUrl(
      eventTitle: title,
      eventId: ticket.eventId,
      tierName: ticket.tierName,
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) AppToast.error(context, 'Could not open Gmail');
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String title) async {
    Navigator.pop(context);
    final uri = ShareUtils.ticketWhatsAppUrl(
      eventTitle: title,
      eventId: ticket.eventId,
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) AppToast.error(context, 'Could not open WhatsApp');
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    Navigator.pop(context);
    final url = ShareUtils.eventUrl(ticket.eventId);
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) AppToast.success(context, 'Event link copied!');
  }

  Future<void> _nativeShare(BuildContext context, String title) async {
    Navigator.pop(context);
    final text = ShareUtils.ticketShareText(
      eventTitle: title,
      eventId: ticket.eventId,
      tierName: ticket.tierName,
      receiptNumber: ticket.receiptNumber,
    );
    await Share.share(text);
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareOption({
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
