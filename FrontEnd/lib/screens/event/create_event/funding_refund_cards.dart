import 'package:flutter/material.dart';

import '../../../config/theme.dart';

class FundingDeadlineCard extends StatelessWidget {
  final DateTime? fundingEndAt;
  final VoidCallback onPickFundingDeadline;
  final VoidCallback onClearFundingDeadline;
  final String Function(DateTime) fmtDt;

  const FundingDeadlineCard({
    super.key,
    required this.fundingEndAt,
    required this.onPickFundingDeadline,
    required this.onClearFundingDeadline,
    required this.fmtDt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fundingEndAt != null
            ? AppTheme.successColor.withValues(alpha: 0.06)
            : AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: fundingEndAt != null
              ? AppTheme.successColor.withValues(alpha: 0.25)
              : AppTheme.dividerOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (fundingEndAt != null
                          ? context.fundingAccent
                          : AppTheme.textSecondaryOf(context))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.timer_rounded,
                    size: 18,
                    color: fundingEndAt != null
                        ? context.fundingAccent
                        : AppTheme.textSecondaryOf(context)),
              ),
              const SizedBox(width: 10),
              Text('Funding Deadline',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.textPrimaryOf(context))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickFundingDeadline,
                  icon: Icon(Icons.calendar_month_rounded,
                      size: 18,
                      color: fundingEndAt != null
                          ? context.fundingAccent
                          : AppTheme.textSecondaryOf(context)),
                  label: Text(
                    fundingEndAt != null
                        ? fmtDt(fundingEndAt!)
                        : 'Set Funding Deadline',
                    style: TextStyle(
                      color: fundingEndAt != null
                          ? AppTheme.textPrimaryOf(context)
                          : AppTheme.textSecondaryOf(context),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (fundingEndAt != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onClearFundingDeadline,
                  icon: const Icon(Icons.clear, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class RefundDeadlineCard extends StatelessWidget {
  final DateTime fundingEndAt;
  final int refundDeadlineDays;
  final ValueChanged<int> onRefundDeadlineDaysChanged;

  const RefundDeadlineCard({
    super.key,
    required this.fundingEndAt,
    required this.refundDeadlineDays,
    required this.onRefundDeadlineDaysChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Builder(builder: (context) {
        final fundDuration =
            fundingEndAt.difference(DateTime.now()).inDays;
        final maxDays = (fundDuration * 0.2).ceil().clamp(1, 365);
        final effectiveDays = refundDeadlineDays > maxDays
            ? maxDays
            : refundDeadlineDays;
        if (effectiveDays != refundDeadlineDays) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onRefundDeadlineDaysChanged(effectiveDays);
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.shield_rounded,
                      size: 18, color: AppTheme.warningColor),
                ),
                const SizedBox(width: 10),
                Text(
                  'Refund Deadline',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context)),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$effectiveDays day${effectiveDays == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.warningColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Max $maxDays days (20% of funding duration). Customers can refund if they unregister before this cutoff.',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondaryOf(context)),
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: effectiveDays
                    .toDouble()
                    .clamp(0, maxDays.toDouble()),
                min: 0,
                max: maxDays.toDouble(),
                divisions: maxDays > 0 ? maxDays : 1,
                label: '$effectiveDays days',
                activeColor: AppTheme.accentColor,
                onChanged: (v) =>
                    onRefundDeadlineDaysChanged(v.round()),
              ),
            ),
          ],
        );
      }),
    );
  }
}
