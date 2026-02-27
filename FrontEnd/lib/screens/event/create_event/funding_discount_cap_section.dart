import 'package:flutter/material.dart';

import '../../../config/theme.dart';

class FundingDiscountCapSection extends StatefulWidget {
  final int maxDiscountPercent;
  final ValueChanged<int> onMaxDiscountPercentChanged;
  final VoidCallback onMarkDirty;

  const FundingDiscountCapSection({
    super.key,
    required this.maxDiscountPercent,
    required this.onMaxDiscountPercentChanged,
    required this.onMarkDirty,
  });

  @override
  State<FundingDiscountCapSection> createState() =>
      _FundingDiscountCapSectionState();
}

class _FundingDiscountCapSectionState extends State<FundingDiscountCapSection> {
  bool _showDiscountCapSection = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(
              () => _showDiscountCapSection = !_showDiscountCapSection),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _showDiscountCapSection
                  ? context.fundingAccent.withValues(alpha: 0.08)
                  : AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showDiscountCapSection
                    ? context.fundingAccent.withValues(alpha: 0.3)
                    : AppTheme.dividerOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.tune_rounded,
                    size: 18,
                    color: _showDiscountCapSection
                        ? context.fundingAccent
                        : AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Maximum Discount Cap',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textPrimaryOf(context))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.fundingAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${widget.maxDiscountPercent}%',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.fundingAccent)),
                ),
                const SizedBox(width: 4),
                Icon(
                  _showDiscountCapSection
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerOf(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All discounts (common, pledge, milestone, early bird) stack up to this limit.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context)),
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16),
                  ),
                  child: Slider(
                    value: widget.maxDiscountPercent.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${widget.maxDiscountPercent}%',
                    activeColor: context.fundingAccent,
                    onChanged: (v) {
                      widget.onMaxDiscountPercentChanged(v.round());
                      widget.onMarkDirty();
                    },
                  ),
                ),
                Text(
                  widget.maxDiscountPercent == 100
                      ? 'No cap — discounts can cover the full ticket price'
                      : 'Total discount capped at ${widget.maxDiscountPercent}% of ticket price',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondaryOf(context)),
                ),
              ],
            ),
          ),
          crossFadeState: _showDiscountCapSection
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}
