import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/event_form_models.dart';

class FundingEarlyBirdSection extends StatefulWidget {
  final List<EarlyBirdInput> earlyBirdDiscounts;
  final VoidCallback onMarkDirty;
  final String Function(DateTime) fmtDt;

  const FundingEarlyBirdSection({
    super.key,
    required this.earlyBirdDiscounts,
    required this.onMarkDirty,
    required this.fmtDt,
  });

  @override
  State<FundingEarlyBirdSection> createState() =>
      _FundingEarlyBirdSectionState();
}

class _FundingEarlyBirdSectionState extends State<FundingEarlyBirdSection> {
  bool _showEarlyBirdSection = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () =>
              setState(() => _showEarlyBirdSection = !_showEarlyBirdSection),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _showEarlyBirdSection
                  ? context.scheduleAccent.withValues(alpha: 0.08)
                  : AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showEarlyBirdSection
                    ? context.scheduleAccent.withValues(alpha: 0.3)
                    : AppTheme.dividerOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded,
                    size: 18,
                    color: _showEarlyBirdSection
                        ? context.scheduleAccent
                        : AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Early Bird Discounts (Optional)',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textPrimaryOf(context))),
                ),
                if (widget.earlyBirdDiscounts.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          context.scheduleAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${widget.earlyBirdDiscounts.length}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.scheduleAccent)),
                  ),
                const SizedBox(width: 4),
                Icon(
                  _showEarlyBirdSection
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Reward early supporters with time-limited discounts on tickets.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context)),
                ),
                const SizedBox(height: 12),
                ...widget.earlyBirdDiscounts.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final eb = entry.value;
                  return _buildEarlyBirdCard(context, idx, eb);
                }),
                GestureDetector(
                  onTap: () => setState(
                      () => widget.earlyBirdDiscounts.add(EarlyBirdInput())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: AppTheme.dividerOf(context)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded,
                            size: 18,
                            color: AppTheme.textSecondaryOf(context)),
                        const SizedBox(width: 6),
                        Text('Add Early Bird Discount',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color:
                                    AppTheme.textSecondaryOf(context))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          crossFadeState: _showEarlyBirdSection
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildEarlyBirdCard(
      BuildContext context, int idx, EarlyBirdInput eb) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Early Bird ${idx + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18, color: AppTheme.errorColor),
                onPressed: () => setState(
                    () => widget.earlyBirdDiscounts.removeAt(idx)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'funding',
                  label: Text('Early Pledge',
                      style: TextStyle(fontSize: 12))),
              ButtonSegment(
                  value: 'tickets',
                  label: Text('Early Ticket',
                      style: TextStyle(fontSize: 12))),
            ],
            selected: {eb.appliesTo},
            onSelectionChanged: (s) =>
                setState(() => eb.appliesTo = s.first),
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: eb.valueCtrl,
                  decoration: InputDecoration(
                    labelText: 'Discount',
                    isDense: true,
                    suffixText:
                        eb.discountType == 'percent' ? '%' : '¢',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'percent',
                      label:
                          Text('%', style: TextStyle(fontSize: 12))),
                  ButtonSegment(
                      value: 'fixed_cents',
                      label:
                          Text('\$', style: TextStyle(fontSize: 12))),
                ],
                selected: {eb.discountType},
                onSelectionChanged: (s) =>
                    setState(() => eb.discountType = s.first),
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: eb.windowEnd ??
                    DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate:
                    DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => eb.windowEnd = picked);
                widget.onMarkDirty();
              }
            },
            icon: Icon(Icons.timer_outlined,
                size: 16, color: context.scheduleAccent),
            label: Text(
              eb.windowEnd != null
                  ? 'Ends: ${widget.fmtDt(eb.windowEnd!)}'
                  : 'Set Window End Date',
              style: TextStyle(
                  fontSize: 12,
                  color: eb.windowEnd != null
                      ? AppTheme.textPrimaryOf(context)
                      : AppTheme.textSecondaryOf(context)),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            eb.appliesTo == 'funding'
                ? 'Pledgers within this window get the discount on tickets'
                : 'Ticket buyers within this window get the discount',
            style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondaryOf(context)),
          ),
        ],
      ),
    );
  }
}
