import 'package:flutter/material.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../models/event.dart';

String statusDisplayName(EventStatus s) {
  switch (s) {
    case EventStatus.draft:
      return 'Draft';
    case EventStatus.pending_approval:
      return 'Waiting Approval';
    case EventStatus.approved:
      return 'Funding';
    case EventStatus.selling_tickets:
      return 'Selling Tickets';
    case EventStatus.waiting_event_date:
      return 'Awaiting Date';
    case EventStatus.live:
      return 'Live';
    case EventStatus.completed:
      return 'Completed';
    case EventStatus.cancelled:
      return 'Cancelled';
    case EventStatus.under_review:
      return 'Under Review';
  }
}

Color statusChipColor(BuildContext context, EventStatus s) {
  switch (s) {
    case EventStatus.approved:
      return AppTheme.accentColor;
    case EventStatus.selling_tickets:
      return context.statusApproved;
    case EventStatus.live:
      return AppTheme.errorColor;
    case EventStatus.completed:
      return context.sponsorAccent;
    case EventStatus.cancelled:
      return context.statusCancelled;
    case EventStatus.draft:
      return context.statusDraft;
    case EventStatus.pending_approval:
      return context.statusPending;
    case EventStatus.waiting_event_date:
      return context.statusSelling;
    case EventStatus.under_review:
      return AppTheme.warningColor;
  }
}

IconData statusChipIcon(EventStatus s) {
  switch (s) {
    case EventStatus.approved:
      return Icons.check_circle_rounded;
    case EventStatus.selling_tickets:
      return Icons.confirmation_number_rounded;
    case EventStatus.live:
      return Icons.play_circle_rounded;
    case EventStatus.completed:
      return Icons.task_alt_rounded;
    case EventStatus.cancelled:
      return Icons.cancel_rounded;
    case EventStatus.draft:
      return Icons.edit_note_rounded;
    case EventStatus.pending_approval:
      return Icons.hourglass_top_rounded;
    case EventStatus.waiting_event_date:
      return Icons.event_rounded;
    case EventStatus.under_review:
      return Icons.warning_amber_rounded;
  }
}

String formatCents(int cents) =>
    '\$${(cents / 100).toStringAsFixed(2)}';

String relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays > 365) return '${diff.inDays ~/ 365}y ago';
  if (diff.inDays > 30) return '${diff.inDays ~/ 30}mo ago';
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'just now';
}

class SponsorBidEvent {
  final Event event;
  final int pending;
  final int accepted;
  final int rejected;
  final int paid;

  SponsorBidEvent({
    required this.event,
    this.pending = 0,
    this.accepted = 0,
    this.rejected = 0,
    this.paid = 0,
  });

  int get totalBids => pending + accepted + rejected + paid;
}

Widget customerQuickAction({
  required BuildContext context,
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.md,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: AppIconSize.md, color: color),
            AppSpacing.hSm,
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    ),
  );
}
