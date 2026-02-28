import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/event_form_models.dart';

class FundingEarlyBirdSection extends StatefulWidget {
  final List<EarlyBirdInput> earlyBirdDiscounts;
  final VoidCallback onMarkDirty;
  final String Function(DateTime) fmtDt;

  /// Funding deadline — if set, "Early Pledge" is available.
  final DateTime? fundingEndAt;

  /// Event start time — if set (and no funding deadline), "Early Ticket" is available.
  final DateTime? startTime;

  const FundingEarlyBirdSection({
    super.key,
    required this.earlyBirdDiscounts,
    required this.onMarkDirty,
    required this.fmtDt,
    this.fundingEndAt,
    this.startTime,
  });

  @override
  State<FundingEarlyBirdSection> createState() =>
      _FundingEarlyBirdSectionState();
}

class _FundingEarlyBirdSectionState extends State<FundingEarlyBirdSection> {
  bool _showEarlyBirdSection = false;

  bool get _canEarlyPledge => widget.fundingEndAt != null;
  bool get _canEarlyTicket =>
      widget.fundingEndAt == null && widget.startTime != null;
  bool get _canAddAny => _canEarlyPledge || _canEarlyTicket;

  /// Max date for the window end picker based on the discount type.
  DateTime? _maxDateFor(EarlyBirdInput eb) {
    if (eb.appliesTo == 'funding') return widget.fundingEndAt;
    if (eb.appliesTo == 'tickets') return widget.startTime;
    return null;
  }

  /// Auto-pick the right default appliesTo when adding a new entry.
  String _defaultAppliesTo() {
    if (_canEarlyPledge) return 'funding';
    if (_canEarlyTicket) return 'tickets';
    return 'funding';
  }

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
                if (!_canAddAny) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              AppTheme.warningColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: AppTheme.warningColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Set a funding deadline (for Early Pledge) or an event start date without funding (for Early Ticket) in the Dates step first.',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.warningColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ...widget.earlyBirdDiscounts.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final eb = entry.value;
                  return _buildEarlyBirdCard(context, idx, eb);
                }),
                if (_canAddAny)
                  GestureDetector(
                    onTap: () => setState(() {
                      final input = EarlyBirdInput()
                        ..appliesTo = _defaultAppliesTo();
                      widget.earlyBirdDiscounts.add(input);
                    }),
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
    final maxDate = _maxDateFor(eb);

    // If the current windowEnd exceeds the max date, clear it.
    if (eb.windowEnd != null && maxDate != null && eb.windowEnd!.isAfter(maxDate)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => eb.windowEnd = null);
      });
    }

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
          if (_canEarlyPledge && _canEarlyTicket)
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'funding',
                  label: Text('Early Pledge',
                      style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: 'tickets',
                  label: Text('Early Ticket',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
              selected: {eb.appliesTo},
              onSelectionChanged: (s) {
                setState(() {
                  eb.appliesTo = s.first;
                  eb.windowEnd = null;
                });
              },
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.scheduleAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.bolt_rounded,
                      size: 14, color: context.scheduleAccent),
                  const SizedBox(width: 6),
                  Text(
                    eb.appliesTo == 'funding'
                        ? 'Early Pledge'
                        : 'Early Ticket',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.scheduleAccent),
                  ),
                ],
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
                        eb.discountType == 'percent' ? '%' : '\$',
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
              final now = DateTime.now();
              final limit = maxDate ?? now.add(const Duration(days: 365));
              // Ensure initialDate is within range
              var initial = eb.windowEnd ?? now.add(const Duration(days: 7));
              if (initial.isAfter(limit)) initial = limit;
              if (initial.isBefore(now)) initial = now;

              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: now,
                lastDate: limit,
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
          if (maxDate != null) ...[
            const SizedBox(height: 2),
            Text(
              eb.appliesTo == 'funding'
                  ? 'Window limited to funding deadline (${widget.fmtDt(maxDate)})'
                  : 'Window limited to event start (${widget.fmtDt(maxDate)})',
              style: TextStyle(
                  fontSize: 10,
                  color: context.scheduleAccent,
                  fontStyle: FontStyle.italic),
            ),
          ],
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
