import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event_form_models.dart';

class StepFunding extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fundingGoalCtrl;
  final TextEditingController minPledgeCtrl;
  final TextEditingController maxReservedSpotsCtrl;
  final DateTime? fundingEndAt;
  final VoidCallback onPickFundingDeadline;
  final VoidCallback onClearFundingDeadline;
  final int refundDeadlineDays;
  final ValueChanged<int> onRefundDeadlineDaysChanged;
  final List<MilestoneInput> milestones;
  final VoidCallback onMarkDirty;
  final String Function(DateTime) fmtDt;
  final bool linkFundingToTiers;
  final ValueChanged<bool> onLinkFundingToTiersChanged;
  final List<EditableTier> localTiers;
  final int maxDiscountPercent;
  final ValueChanged<int> onMaxDiscountPercentChanged;
  final List<EarlyBirdInput> earlyBirdDiscounts;

  const StepFunding({
    super.key,
    required this.formKey,
    required this.fundingGoalCtrl,
    required this.minPledgeCtrl,
    required this.maxReservedSpotsCtrl,
    required this.fundingEndAt,
    required this.onPickFundingDeadline,
    required this.onClearFundingDeadline,
    required this.refundDeadlineDays,
    required this.onRefundDeadlineDaysChanged,
    required this.milestones,
    required this.onMarkDirty,
    required this.fmtDt,
    required this.linkFundingToTiers,
    required this.onLinkFundingToTiersChanged,
    required this.localTiers,
    required this.maxDiscountPercent,
    required this.onMaxDiscountPercentChanged,
    required this.earlyBirdDiscounts,
  });

  @override
  State<StepFunding> createState() => _StepFundingState();
}

class _StepFundingState extends State<StepFunding> {
  bool _showMilestoneSection = false;
  bool _showEarlyBirdSection = false;
  bool _showDiscountCapSection = false;
  late bool _limitSpotsPerPledger;

  @override
  void initState() {
    super.initState();
    _limitSpotsPerPledger = (int.tryParse(widget.maxReservedSpotsCtrl.text) ?? 0) > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                _buildFundingDeadlineCard(context),
                if (widget.fundingEndAt != null) ...[
                  const SizedBox(height: 20),
                  _buildRefundDeadlineCard(context),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: widget.fundingGoalCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Funding Goal (\$)',
                        prefixIcon: Icon(Icons.flag_rounded, size: 20),
                        prefixText: '\$ '),
                    keyboardType: TextInputType.number,
                  ),

                  if (widget.localTiers.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildTierLinkToggle(context),
                    if (widget.linkFundingToTiers) ...[
                      const SizedBox(height: 16),
                      _buildPerTierReservationConfig(context),
                      const SizedBox(height: 16),
                      _buildSpotLimitToggle(context),
                    ],
                  ],

                  if (!widget.linkFundingToTiers) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: widget.minPledgeCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Minimum Pledge (\$)',
                          prefixIcon: Icon(Icons.savings_rounded, size: 20),
                          prefixText: '\$ '),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _buildSpotLimitToggle(context),
                  ],
                  const SizedBox(height: 24),
                  _buildMilestoneSection(context),
                  const SizedBox(height: 16),
                  _buildEarlyBirdSection(context),
                  const SizedBox(height: 16),
                  _buildDiscountCapSection(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.fundingAccent.withValues(alpha: 0.08),
            context.fundingAccent.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.fundingAccent.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.fundingAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.attach_money_rounded,
                size: 24, color: context.fundingAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Funding Settings',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryOf(context),
                        letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text(
                  'Set a funding deadline to run a crowdfunding phase. If skipped, dates become required next.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFundingDeadlineCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.fundingEndAt != null
            ? AppTheme.successColor.withValues(alpha: 0.06)
            : AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.fundingEndAt != null
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
                  color: (widget.fundingEndAt != null
                          ? context.fundingAccent
                          : AppTheme.textSecondaryOf(context))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.timer_rounded,
                    size: 18,
                    color: widget.fundingEndAt != null
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
                  onPressed: widget.onPickFundingDeadline,
                  icon: Icon(Icons.calendar_month_rounded,
                      size: 18,
                      color: widget.fundingEndAt != null
                          ? context.fundingAccent
                          : AppTheme.textSecondaryOf(context)),
                  label: Text(
                    widget.fundingEndAt != null
                        ? widget.fmtDt(widget.fundingEndAt!)
                        : 'Set Funding Deadline',
                    style: TextStyle(
                      color: widget.fundingEndAt != null
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
              if (widget.fundingEndAt != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: widget.onClearFundingDeadline,
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

  Widget _buildRefundDeadlineCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Builder(builder: (context) {
        final fundDuration =
            widget.fundingEndAt!.difference(DateTime.now()).inDays;
        final maxDays = (fundDuration * 0.2).ceil().clamp(1, 365);
        final effectiveDays = widget.refundDeadlineDays > maxDays
            ? maxDays
            : widget.refundDeadlineDays;
        if (effectiveDays != widget.refundDeadlineDays) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onRefundDeadlineDaysChanged(effectiveDays);
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
                    widget.onRefundDeadlineDaysChanged(v.round()),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildTierLinkToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.linkFundingToTiers
            ? context.ticketAccent.withValues(alpha: 0.06)
            : AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.linkFundingToTiers
              ? context.ticketAccent.withValues(alpha: 0.25)
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
                  color: (widget.linkFundingToTiers
                          ? context.ticketAccent
                          : AppTheme.textSecondaryOf(context))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.link_rounded,
                    size: 18,
                    color: widget.linkFundingToTiers
                        ? context.ticketAccent
                        : AppTheme.textSecondaryOf(context)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Link Spot Reservation to Tiers',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimaryOf(context))),
              ),
              Switch.adaptive(
                value: widget.linkFundingToTiers,
                onChanged: (v) {
                  widget.onLinkFundingToTiersChanged(v);
                  widget.onMarkDirty();
                },
                activeColor: context.ticketAccent,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.linkFundingToTiers
                ? 'Pledgers reserve spots by tier. Min pledge = tier price × spots.'
                : 'Enable to let pledgers reserve spots for specific ticket tiers.',
            style: TextStyle(
                fontSize: 12, color: AppTheme.textSecondaryOf(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildPerTierReservationConfig(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_seat_rounded,
                  size: 16, color: context.ticketAccent),
              const SizedBox(width: 6),
              Text('Per-Tier Reservation Limits',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.textPrimaryOf(context))),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Set how many spots pledgers can reserve per tier. Set 0 to disable reservations for a tier.',
            style: TextStyle(
                fontSize: 11, color: AppTheme.textSecondaryOf(context)),
          ),
          const SizedBox(height: 12),
          ...widget.localTiers.asMap().entries.map((entry) {
            final tier = entry.value;
            final name = tier.nameCtrl.text.isEmpty
                ? 'Tier ${entry.key + 1}'
                : tier.nameCtrl.text;
            final price = double.tryParse(tier.priceCtrl.text) ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: AppRadius.sm,
                border: Border.all(color: AppTheme.dividerOf(context)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppTheme.textPrimaryOf(context))),
                        Text('\$${price.toStringAsFixed(2)} / spot',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondaryOf(context))),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        InkWell(
                          onTap: tier.maxReservedSpots > 0
                              ? () => setState(() {
                                    tier.maxReservedSpots--;
                                    widget.onMarkDirty();
                                  })
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Icon(Icons.remove_circle_outline,
                              size: 22,
                              color: tier.maxReservedSpots > 0
                                  ? context.ticketAccent
                                  : AppTheme.dividerOf(context)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text('${tier.maxReservedSpots}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        InkWell(
                          onTap: () => setState(() {
                            tier.maxReservedSpots++;
                            widget.onMarkDirty();
                          }),
                          borderRadius: BorderRadius.circular(12),
                          child: Icon(Icons.add_circle_outline,
                              size: 22, color: context.ticketAccent),
                        ),
                      ],
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

  Widget _buildSpotLimitToggle(BuildContext context) {
    final currentLimit = int.tryParse(widget.maxReservedSpotsCtrl.text) ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _limitSpotsPerPledger
            ? context.fundingAccent.withValues(alpha: 0.06)
            : AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _limitSpotsPerPledger
              ? context.fundingAccent.withValues(alpha: 0.25)
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
                  color: (_limitSpotsPerPledger
                          ? context.fundingAccent
                          : AppTheme.textSecondaryOf(context))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.person_pin_rounded,
                    size: 18,
                    color: _limitSpotsPerPledger
                        ? context.fundingAccent
                        : AppTheme.textSecondaryOf(context)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Limit Spots Per Pledger',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimaryOf(context))),
              ),
              Switch.adaptive(
                value: _limitSpotsPerPledger,
                onChanged: (v) {
                  setState(() {
                    _limitSpotsPerPledger = v;
                    if (!v) {
                      widget.maxReservedSpotsCtrl.text = '0';
                    } else if (currentLimit == 0) {
                      widget.maxReservedSpotsCtrl.text = '1';
                    }
                  });
                  widget.onMarkDirty();
                },
                activeColor: context.fundingAccent,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _limitSpotsPerPledger
                ? 'Each pledger can reserve up to $currentLimit spot${currentLimit == 1 ? '' : 's'} across all tiers.'
                : 'No per-person limit on spot reservations.',
            style: TextStyle(
                fontSize: 12, color: AppTheme.textSecondaryOf(context)),
          ),
          if (_limitSpotsPerPledger) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.maxReservedSpotsCtrl,
              decoration: const InputDecoration(
                labelText: 'Max Spots Per Pledger',
                prefixIcon: Icon(Icons.event_seat_rounded, size: 20),
                helperText: 'Total spots one person can reserve across all tiers',
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMilestoneSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(
              () => _showMilestoneSection = !_showMilestoneSection),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _showMilestoneSection
                  ? context.reviewAccent.withValues(alpha: 0.08)
                  : AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showMilestoneSection
                    ? context.reviewAccent.withValues(alpha: 0.3)
                    : AppTheme.dividerOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events_rounded,
                    size: 18,
                    color: _showMilestoneSection
                        ? context.photoAccent
                        : AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Funding Milestones (Optional)',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textPrimaryOf(context))),
                ),
                if (widget.milestones.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.reviewAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${widget.milestones.length}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.reviewAccent)),
                  ),
                const SizedBox(width: 4),
                Icon(
                  _showMilestoneSection
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
                  'Define milestones that unlock as your event reaches funding goals.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context)),
                ),
                const SizedBox(height: 12),
                ...widget.milestones.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final ms = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: AppTheme.dividerOf(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text('Milestone ${idx + 1}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            const Spacer(),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  size: 18, color: AppTheme.errorColor),
                              onPressed: () => setState(
                                  () => widget.milestones.removeAt(idx)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: ms.titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            hintText: 'e.g. DJ Sound System Upgrade',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text('Unlock at:',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondaryOf(
                                        context))),
                            Expanded(
                              child: Slider(
                                value: ms.unlockPercent.toDouble(),
                                min: 1,
                                max: 100,
                                divisions: 99,
                                label: '${ms.unlockPercent}%',
                                onChanged: (v) => setState(
                                    () => ms.unlockPercent = v.round()),
                              ),
                            ),
                            SizedBox(
                              width: 42,
                              child: Text('${ms.unlockPercent}%',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13),
                                  textAlign: TextAlign.right),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: ms.benefitCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Benefit Description',
                            hintText:
                                'e.g. Premium sound system for all attendees',
                            isDense: true,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.discount_rounded,
                                size: 14,
                                color: context.fundingAccent),
                            const SizedBox(width: 6),
                            Text('Discount for early pledgers',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondaryOf(
                                        context))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: ms.discountValueCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Discount %',
                                  hintText: '0',
                                  isDense: true,
                                  suffixText: '%',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pledgers at this milestone get this % off tickets',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondaryOf(context)),
                        ),
                      ],
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () => setState(
                      () => widget.milestones.add(MilestoneInput())),
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
                        Text('Add Milestone',
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
          crossFadeState: _showMilestoneSection
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildEarlyBirdSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () =>
              setState(() => _showEarlyBirdSection = !_showEarlyBirdSection),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.scheduleAccent.withValues(alpha: 0.15),
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
                      fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                ),
                const SizedBox(height: 12),
                ...widget.earlyBirdDiscounts.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final eb = entry.value;
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
                                    label: Text('%',
                                        style: TextStyle(fontSize: 12))),
                                ButtonSegment(
                                    value: 'fixed_cents',
                                    label: Text('\$',
                                        style: TextStyle(fontSize: 12))),
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
                }),
                GestureDetector(
                  onTap: () =>
                      setState(() => widget.earlyBirdDiscounts.add(EarlyBirdInput())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.dividerOf(context)),
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
                                color: AppTheme.textSecondaryOf(context))),
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

  Widget _buildDiscountCapSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(
              () => _showDiscountCapSection = !_showDiscountCapSection),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16),
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
