import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/sponsor.dart';
import '../../../utils/date_time_utils.dart';
import '../sponsor_payment_receipt_screen.dart';
import 'receipt_section_helpers.dart';

class PaymentHistoryCard extends StatelessWidget {
  final SponsorTicketModel ticket;

  const PaymentHistoryCard({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    final paidCategories =
        ticket.categories.where((c) => c.paymentReceiptNumber != null).toList();
    if (paidCategories.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      title: 'Payment History',
      icon: Icons.receipt_long_rounded,
      children:
          paidCategories.map((cat) => _PaymentRow(category: cat)).toList(),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final SponsorTicketCategory category;

  const _PaymentRow({required this.category});

  @override
  Widget build(BuildContext context) {
    final cat = category;
    DateTime? payDt;
    if (cat.paymentCreatedAt != null) {
      try {
        payDt = DateTime.parse(cat.paymentCreatedAt!);
      } catch (e) {
        debugPrint(e.toString());
      }
    }
    final isRefund = cat.isRefunded;
    final payColor = isRefund ? AppTheme.errorColor : AppTheme.successColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: payColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: cat.paymentId != null
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
                color: payColor.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isRefund ? Icons.undo_rounded : Icons.payment_rounded,
                      size: 18,
                      color: payColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isRefund
                            ? 'Refund — ${cat.name}'
                            : 'Payment — ${cat.name}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    Text(
                      isRefund
                          ? '-${cat.amountDisplay}'
                          : cat.amountDisplay,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: payColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const SizedBox(width: 26),
                    Icon(Icons.tag_rounded,
                        size: 11,
                        color: AppTheme.textSecondaryOf(context)),
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
                    if (cat.paymentId != null)
                      Icon(Icons.chevron_right_rounded,
                          size: 16,
                          color: AppTheme.textSecondaryOf(context)),
                  ],
                ),
                if (payDt != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const SizedBox(width: 26),
                      Icon(Icons.access_time_rounded,
                          size: 11,
                          color: AppTheme.textSecondaryOf(context)),
                      const SizedBox(width: 4),
                      Text(
                        AppDateFormat.fullDateTime(payDt),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
