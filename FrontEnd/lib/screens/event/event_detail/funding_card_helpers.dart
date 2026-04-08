import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';

// ── Shared milestone state enum ──
enum FundingMsState { hit, next, locked }

// ── Shimmer progress bar ──
class FundingShimmerBar extends StatefulWidget {
  final double progress;
  final bool active;
  final List<Color> fillColors;
  final Color trackColor;
  final Color glowColor;

  const FundingShimmerBar({
    super.key,
    required this.progress,
    this.active = true,
    required this.fillColors,
    required this.trackColor,
    required this.glowColor,
  });

  @override
  State<FundingShimmerBar> createState() => _FundingShimmerBarState();
}

class _FundingShimmerBarState extends State<FundingShimmerBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fillFraction = widget.progress.clamp(0.0, 1.0);
    return SizedBox(
      height: 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Stack(
          children: [
            // track
            Container(color: widget.trackColor),
            // fill
            FractionallySizedBox(
              widthFactor: fillFraction,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: widget.fillColors),
                  boxShadow: [
                    BoxShadow(
                        color: widget.glowColor.withValues(alpha: 0.45),
                        blurRadius: 6),
                  ],
                ),
              ),
            ),
            // shimmer sweep (only when active)
            if (widget.active && fillFraction > 0)
              FractionallySizedBox(
                widthFactor: fillFraction,
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) {
                    final pos = _ctrl.value;
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(pos * 3 - 1.5, 0),
                          end: Alignment(pos * 3 - 0.9, 0),
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Stat cell (used in stats strip) ──
class FundingStatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const FundingStatCell({
    super.key,
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: valueColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.8),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Milestone row (shared by FundingCard and FundingResultsCard) ──
class FundingMilestoneRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final FundingMsState state;
  final double nextFillFraction;
  final bool isDark;

  const FundingMilestoneRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.state,
    this.nextFillFraction = 0,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconBg, iconFg, amountColor;
    final IconData iconData;
    switch (state) {
      case FundingMsState.hit:
        iconBg = AppTheme.successColor.withValues(alpha: 0.12);
        iconFg = AppTheme.successColor;
        amountColor = AppTheme.successColor.withValues(alpha: 0.8);
        iconData = Icons.check_rounded;
      case FundingMsState.next:
        iconBg = AppTheme.purpleColor.withValues(alpha: 0.18);
        iconFg = AppTheme.purpleColor.withValues(alpha: 0.7);
        amountColor = AppTheme.purpleColor.withValues(alpha: 0.7);
        iconData = Icons.star_outline_rounded;
      case FundingMsState.locked:
        iconBg = isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.04);
        iconFg = AppTheme.textSecondaryOf(context).withValues(alpha: 0.5);
        amountColor = isDark
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.2);
        iconData = Icons.lock_outline_rounded;
    }

    return ClipRRect(
      borderRadius: AppRadius.md,
      child: Stack(
        children: [
          // progress fill behind "next" row
          if (state == FundingMsState.next && nextFillFraction > 0)
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: nextFillFraction,
                child: Container(
                  color: AppTheme.purpleColor.withValues(alpha: 0.09),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.025)
                  : Colors.black.withValues(alpha: 0.025),
              borderRadius: AppRadius.md,
              border: Border.all(
                color: state == FundingMsState.next
                    ? AppTheme.purpleColor.withValues(alpha: 0.25)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: iconFg.withValues(alpha: 0.4)),
                  ),
                  child: Icon(iconData, size: 14, color: iconFg),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: state == FundingMsState.locked
                              ? AppTheme.textSecondaryOf(context)
                                  .withValues(alpha: 0.65)
                              : AppTheme.textPrimaryOf(context).withValues(
                                  alpha:
                                      state == FundingMsState.hit ? 0.7 : 1),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: AppTheme.textSecondaryOf(context)
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amount,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: amountColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
