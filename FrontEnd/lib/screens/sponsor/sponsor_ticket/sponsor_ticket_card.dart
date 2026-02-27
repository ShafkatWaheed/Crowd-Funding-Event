import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/sponsor.dart';
import '../../../utils/date_time_utils.dart';
import '../sponsor_payment_receipt_screen.dart';

class SponsorTicketCard extends StatefulWidget {
  final SponsorTicketModel ticket;
  final VoidCallback onTap;

  const SponsorTicketCard({
    super.key,
    required this.ticket,
    required this.onTap,
  });

  @override
  State<SponsorTicketCard> createState() => _SponsorTicketCardState();
}

class _SponsorTicketCardState extends State<SponsorTicketCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    DateTime? startDt;
    if (ticket.eventStartTime != null) {
      try {
        startDt = DateTime.parse(ticket.eventStartTime!);
      } catch (e) {
        debugPrint(e.toString());
      }
    }

    final paidCount = ticket.categories.where((c) => c.isPaid).length;
    final refundedCount = ticket.categories.where((c) => c.isRefunded).length;
    final pendingCount = ticket.categories.length - paidCount - refundedCount;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, ticket, startDt, paidCount, refundedCount,
              pendingCount),
          _buildExpandToggle(context, ticket),
          _buildCategoriesPanel(context, ticket),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    SponsorTicketModel ticket,
    DateTime? startDt,
    int paidCount,
    int refundedCount,
    int pendingCount,
  ) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D3B66), Color(0xFF1B5E8A)],
          ),
          borderRadius: _expanded
              ? const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                )
              : BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.confirmation_number_rounded,
                color: Colors.white70, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.eventTitle ?? 'Event #${ticket.eventId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildEventMeta(startDt, ticket.venueName),
                  const SizedBox(height: 6),
                  _buildStatusChips(ticket, paidCount, refundedCount,
                      pendingCount),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'SPONSOR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (ticket.scannedAt != null) ...[
                  const SizedBox(height: 6),
                  Icon(Icons.verified_rounded,
                      size: 16, color: AppTheme.successColor),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventMeta(DateTime? startDt, String? venueName) {
    return Row(
      children: [
        if (startDt != null) ...[
          const Icon(Icons.schedule_rounded, size: 12, color: Colors.white60),
          const SizedBox(width: 4),
          Text(
            AppDateFormat.dateOnly(startDt),
            style: const TextStyle(fontSize: 11, color: Colors.white60),
          ),
          if (venueName != null)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: Text('\u2022',
                  style: TextStyle(fontSize: 8, color: Colors.white38)),
            ),
        ],
        if (venueName != null) ...[
          const Icon(Icons.location_on_rounded,
              size: 12, color: Colors.white60),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              venueName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusChips(
    SponsorTicketModel ticket,
    int paidCount,
    int refundedCount,
    int pendingCount,
  ) {
    return Row(
      children: [
        _headerChip(
          '${ticket.categories.length} categor${ticket.categories.length == 1 ? "y" : "ies"}',
          Colors.white24,
          Colors.white70,
        ),
        const SizedBox(width: 6),
        if (paidCount > 0)
          _headerChip('$paidCount paid',
              AppTheme.successColor.withValues(alpha: 0.3), Colors.white),
        if (paidCount > 0 && refundedCount > 0) const SizedBox(width: 6),
        if (refundedCount > 0)
          _headerChip('$refundedCount refunded',
              AppTheme.errorColor.withValues(alpha: 0.3), Colors.white),
        if ((paidCount > 0 || refundedCount > 0) && pendingCount > 0)
          const SizedBox(width: 6),
        if (pendingCount > 0)
          _headerChip('$pendingCount pending',
              AppTheme.warningColor.withValues(alpha: 0.3), Colors.white),
      ],
    );
  }

  Widget _buildExpandToggle(BuildContext context, SponsorTicketModel ticket) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            border: Border(
              top: BorderSide(color: AppTheme.dividerOf(context)),
              bottom: _expanded
                  ? BorderSide(color: AppTheme.dividerOf(context))
                  : BorderSide.none,
            ),
            borderRadius: _expanded
                ? BorderRadius.zero
                : const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
          ),
          child: Row(
            children: [
              Text(
                ticket.receiptNumber,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryOf(context),
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Text(
                _expanded ? 'Hide categories' : 'Show categories',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentColor,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20, color: AppTheme.accentColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesPanel(
      BuildContext context, SponsorTicketModel ticket) {
    return AnimatedCrossFade(
      firstChild: const SizedBox(width: double.infinity, height: 0),
      secondChild: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: ticket.categories.map((cat) {
            return _CategoryRow(category: cat);
          }).toList(),
        ),
      ),
      crossFadeState:
          _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 250),
    );
  }

  Widget _headerChip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style:
              TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final SponsorTicketCategory category;

  const _CategoryRow({required this.category});

  @override
  Widget build(BuildContext context) {
    final cat = category;
    final isRefunded = cat.isRefunded;
    final isPaid = cat.isPaid;
    final hasReceipt = cat.paymentId != null;
    final color = isRefunded
        ? AppTheme.errorColor
        : isPaid
            ? AppTheme.successColor
            : AppTheme.warningColor;
    final icon = isRefunded
        ? Icons.undo_rounded
        : isPaid
            ? Icons.check_circle_rounded
            : Icons.hourglass_top_rounded;
    final statusLabel = isRefunded
        ? 'Refunded'
        : isPaid
            ? 'Paid'
            : 'Pending';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: hasReceipt
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SponsorPaymentReceiptScreen(
                          paymentId: cat.paymentId!),
                    ),
                  )
              : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cat.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textPrimaryOf(context),
                          decoration:
                              isRefunded ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    Text(
                      isRefunded ? '-${cat.amountDisplay}' : cat.amountDisplay,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isRefunded
                            ? AppTheme.errorColor
                            : AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const SizedBox(width: 24),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (cat.paymentReceiptNumber != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text('\u2022',
                            style: TextStyle(
                                fontSize: 9,
                                color: AppTheme.textSecondaryOf(context))),
                      ),
                      Icon(Icons.receipt_long_rounded,
                          size: 11,
                          color: AppTheme.textSecondaryOf(context)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          cat.paymentReceiptNumber!,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondaryOf(context),
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (hasReceipt) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded,
                          size: 16,
                          color: AppTheme.textSecondaryOf(context)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
