import 'package:flutter/material.dart';

import '../../../config/theme.dart';

class BidLeaderboard extends StatelessWidget {
  final List<int> bidAmounts;

  const BidLeaderboard({super.key, required this.bidAmounts});

  @override
  Widget build(BuildContext context) {
    final sorted = List<int>.from(bidAmounts)..sort((a, b) => b.compareTo(a));
    final top = sorted.take(5).toList();
    final maxAmount = top.first;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, size: 16, color: Color(0xFFD4A017)),
              const SizedBox(width: 6),
              Text(
                'Top Bids',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondaryOf(context),
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Text(
                '${bidAmounts.length} total',
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(top.length, (i) {
            final cents = top[i];
            final amount = '\$${(cents / 100).toStringAsFixed(2)}';
            final fraction = maxAmount > 0 ? cents / maxAmount : 0.0;

            final (IconData? icon, Color color) = switch (i) {
              0 => (Icons.emoji_events_rounded, const Color(0xFFD4A017)),
              1 => (Icons.emoji_events_rounded, const Color(0xFF9E9E9E)),
              2 => (Icons.emoji_events_rounded, const Color(0xFFCD7F32)),
              _ => (null, AppTheme.textSecondaryOf(context)),
            };

            return Padding(
              padding: EdgeInsets.only(bottom: i < top.length - 1 ? 6 : 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: icon != null
                        ? Icon(icon, size: 16, color: color)
                        : Text(
                            '#${i + 1}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    amount,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w600,
                      color: i == 0
                          ? AppTheme.textPrimaryOf(context)
                          : AppTheme.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 6,
                        backgroundColor: AppTheme.dividerOf(context),
                        valueColor: AlwaysStoppedAnimation(
                          i == 0
                              ? const Color(0xFFD4A017)
                              : i == 1
                                  ? const Color(0xFF9E9E9E)
                                  : i == 2
                                      ? const Color(0xFFCD7F32)
                                      : AppTheme.accentColor.withValues(alpha: 0.4),
                        ),
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
}
