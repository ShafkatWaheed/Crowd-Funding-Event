import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/sponsor.dart';
import '../sponsor_payment_receipt_screen.dart';
import 'receipt_section_helpers.dart';

class SponsorshipSpotsCard extends StatelessWidget {
  final SponsorTicketModel ticket;

  const SponsorshipSpotsCard({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Sponsorship Spots',
      icon: Icons.workspace_premium_rounded,
      children: [
        ...ticket.categories.map((cat) => _SpotRow(category: cat)),
        Divider(height: 1, color: AppTheme.dividerOf(context)),
        const SizedBox(height: 10),
        if (ticket.hasRefunds) ...[
          _TotalRow(
            label: 'Subtotal',
            value: ticket.totalAmountDisplay,
            color: AppTheme.textSecondaryOf(context),
            fontSize: 13,
            valueFontSize: 14,
          ),
          const SizedBox(height: 4),
          _TotalRow(
            label: 'Refunded',
            value: '-${ticket.refundedTotalDisplay}',
            color: AppTheme.errorColor,
            fontSize: 13,
            valueFontSize: 14,
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: AppTheme.dividerOf(context)),
          const SizedBox(height: 6),
        ],
        _TotalRow(
          label: ticket.hasRefunds ? 'Net Total' : 'Total',
          value: ticket.hasRefunds
              ? ticket.activeTotalDisplay
              : ticket.totalAmountDisplay,
          color: AppTheme.textPrimaryOf(context),
          fontSize: 15,
          valueFontSize: 18,
          bold: true,
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final double fontSize;
  final double valueFontSize;
  final bool bold;

  const _TotalRow({
    required this.label,
    required this.value,
    required this.color,
    this.fontSize = 13,
    this.valueFontSize = 14,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: valueFontSize,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SpotRow extends StatelessWidget {
  final SponsorTicketCategory category;

  const _SpotRow({required this.category});

  @override
  Widget build(BuildContext context) {
    final cat = category;
    final isRefunded = cat.isRefunded;
    final isPaid = cat.isPaid;
    final statusColor = isRefunded
        ? AppTheme.errorColor
        : isPaid
            ? AppTheme.successColor
            : AppTheme.warningColor;
    final statusIcon = isRefunded
        ? Icons.undo_rounded
        : isPaid
            ? Icons.check_circle_rounded
            : Icons.hourglass_top_rounded;
    final statusLabel = isRefunded
        ? 'Refunded'
        : isPaid
            ? 'Paid'
            : 'Accepted — Pending Payment';
    final hasReceipt = cat.paymentId != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: statusColor.withValues(alpha: 0.06),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, cat, statusIcon, statusColor, statusLabel,
                    isRefunded),
                if (cat.paymentReceiptNumber != null)
                  _buildReceiptRow(context, cat),
                if (cat.prerequisites.isNotEmpty && !isRefunded)
                  _buildPrerequisites(context, cat),
                if (hasReceipt)
                  _buildViewReceiptRow(context, statusColor, isRefunded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    SponsorTicketCategory cat,
    IconData statusIcon,
    Color statusColor,
    String statusLabel,
    bool isRefunded,
  ) {
    return Row(
      children: [
        Icon(statusIcon, size: 20, color: statusColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cat.name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isRefunded
                      ? AppTheme.textSecondaryOf(context)
                      : AppTheme.textPrimaryOf(context),
                  decoration: isRefunded ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Text(
          isRefunded ? '-${cat.amountDisplay}' : cat.amountDisplay,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: isRefunded
                ? AppTheme.errorColor
                : AppTheme.textPrimaryOf(context),
            decoration: isRefunded ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptRow(BuildContext context, SponsorTicketCategory cat) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 30),
      child: Row(
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 12, color: AppTheme.textSecondaryOf(context)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              cat.paymentReceiptNumber!,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondaryOf(context),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrerequisites(
      BuildContext context, SponsorTicketCategory cat) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Requirements',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondaryOf(context),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          ...cat.prerequisites.map((prereq) {
            final uploaded = prereq.isUploaded;
            final uploadColor = uploaded
                ? (prereq.uploadStatus == 'approved'
                    ? AppTheme.successColor
                    : prereq.uploadStatus == 'rejected'
                        ? AppTheme.errorColor
                        : AppTheme.warningColor)
                : AppTheme.textSecondaryOf(context);
            final uploadLabel = uploaded
                ? (prereq.uploadStatus == 'approved'
                    ? 'Approved'
                    : prereq.uploadStatus == 'rejected'
                        ? 'Rejected'
                        : 'Pending')
                : 'Not uploaded';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    uploaded
                        ? Icons.check_circle_outline_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 14,
                    color: uploadColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      prereq.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: uploadColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      uploadLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: uploadColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildViewReceiptRow(
      BuildContext context, Color statusColor, bool isRefunded) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 30),
      child: Row(
        children: [
          Icon(Icons.open_in_new_rounded, size: 12, color: statusColor),
          const SizedBox(width: 4),
          Text(
            isRefunded ? 'View Refund Receipt' : 'View Payment Receipt',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, size: 16, color: statusColor),
        ],
      ),
    );
  }
}
