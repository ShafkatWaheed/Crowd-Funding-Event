import 'dart:math';

import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event_form_models.dart';

class FundingGoalSection extends StatelessWidget {
  final TextEditingController fundingGoalCtrl;

  const FundingGoalSection({super.key, required this.fundingGoalCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fundingAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.fundingAccent.withValues(alpha: 0.25),
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
                  color: context.fundingAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.flag_rounded,
                    size: 18, color: context.fundingAccent),
              ),
              const SizedBox(width: 10),
              Text('Funding Goal',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.textPrimaryOf(context))),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: fundingGoalCtrl,
            decoration: const InputDecoration(
                labelText: 'Funding Goal (\$)',
                prefixIcon: Icon(Icons.flag_rounded, size: 20),
                prefixText: '\$ '),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }
}

class TierLinkToggle extends StatelessWidget {
  final bool linkFundingToTiers;
  final ValueChanged<bool> onLinkFundingToTiersChanged;
  final VoidCallback onMarkDirty;

  const TierLinkToggle({
    super.key,
    required this.linkFundingToTiers,
    required this.onLinkFundingToTiersChanged,
    required this.onMarkDirty,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: linkFundingToTiers
            ? context.ticketAccent.withValues(alpha: 0.06)
            : AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: linkFundingToTiers
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
                  color: (linkFundingToTiers
                          ? context.ticketAccent
                          : AppTheme.textSecondaryOf(context))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.link_rounded,
                    size: 18,
                    color: linkFundingToTiers
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
                value: linkFundingToTiers,
                onChanged: (v) {
                  onLinkFundingToTiersChanged(v);
                  onMarkDirty();
                },
                activeColor: context.ticketAccent,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            linkFundingToTiers
                ? 'Pledgers reserve spots by tier. Min pledge = tier price × spots.'
                : 'Enable to let pledgers reserve spots for specific ticket tiers.',
            style: TextStyle(
                fontSize: 12, color: AppTheme.textSecondaryOf(context)),
          ),
        ],
      ),
    );
  }
}

class PerTierReservationCalculator extends StatefulWidget {
  final TextEditingController fundingGoalCtrl;
  final TextEditingController capacityCtrl;
  final List<EditableTier> localTiers;
  final VoidCallback onMarkDirty;

  const PerTierReservationCalculator({
    super.key,
    required this.fundingGoalCtrl,
    required this.capacityCtrl,
    required this.localTiers,
    required this.onMarkDirty,
  });

  @override
  State<PerTierReservationCalculator> createState() =>
      _PerTierReservationCalculatorState();
}

class _PerTierReservationCalculatorState
    extends State<PerTierReservationCalculator> {
  @override
  Widget build(BuildContext context) {
    final goalCents =
        ((double.tryParse(widget.fundingGoalCtrl.text) ?? 0) * 100).round();
    final capacity = int.tryParse(widget.capacityCtrl.text) ?? 0;

    int totalReservedValue = 0;
    int totalReservedSpots = 0;
    for (final tier in widget.localTiers) {
      final priceCents =
          ((double.tryParse(tier.priceCtrl.text) ?? 0) * 100).round();
      totalReservedValue += tier.maxReservedSpots * priceCents;
      totalReservedSpots += tier.maxReservedSpots;
    }

    final remaining = goalCents - totalReservedValue;
    final progress = goalCents > 0
        ? (totalReservedValue / goalCents).clamp(0.0, 1.0)
        : 0.0;
    final goalMet = remaining <= 0;
    final overCapacity = capacity > 0 && totalReservedSpots > capacity;

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
              Icon(Icons.calculate_rounded,
                  size: 16, color: context.ticketAccent),
              const SizedBox(width: 6),
              Text('Per-Tier Reservation Calculator',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.textPrimaryOf(context))),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Set reserved spots per tier. The calculator shows minimum spots needed to meet the funding goal.',
            style: TextStyle(
                fontSize: 11, color: AppTheme.textSecondaryOf(context)),
          ),
          if (goalCents > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppTheme.dividerOf(context),
                valueColor: AlwaysStoppedAnimation(
                    goalMet ? AppTheme.successColor : context.ticketAccent),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Total reserved value: \$${(totalReservedValue / 100).toStringAsFixed(2)} / \$${(goalCents / 100).toStringAsFixed(2)} goal',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: goalMet
                    ? AppTheme.successColor
                    : AppTheme.warningColor,
              ),
            ),
          ],
          if (overCapacity)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded,
                    size: 14, color: AppTheme.warningColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Total reserved spots ($totalReservedSpots) exceeds max capacity ($capacity)',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 12),
          ...widget.localTiers.asMap().entries.map((entry) {
            final tier = entry.value;
            final name = tier.nameCtrl.text.isEmpty
                ? 'Tier ${entry.key + 1}'
                : tier.nameCtrl.text;
            final priceCents =
                ((double.tryParse(tier.priceCtrl.text) ?? 0) * 100).round();
            final contributes = tier.maxReservedSpots * priceCents;
            final otherValue = totalReservedValue - contributes;
            final remainingForTier = goalCents - otherValue;
            final minSpots = priceCents > 0
                ? max(0, (remainingForTier / priceCents).ceil())
                : 0;

            return _TierReservationRow(
              name: name,
              priceCents: priceCents,
              tier: tier,
              contributes: contributes,
              goalCents: goalCents,
              minSpots: minSpots,
              onIncrement: () => setState(() {
                tier.maxReservedSpots++;
                widget.onMarkDirty();
              }),
              onDecrement: tier.maxReservedSpots > 0
                  ? () => setState(() {
                        tier.maxReservedSpots--;
                        widget.onMarkDirty();
                      })
                  : null,
            );
          }),
        ],
      ),
    );
  }
}

class _TierReservationRow extends StatelessWidget {
  final String name;
  final int priceCents;
  final EditableTier tier;
  final int contributes;
  final int goalCents;
  final int minSpots;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;

  const _TierReservationRow({
    required this.name,
    required this.priceCents,
    required this.tier,
    required this.contributes,
    required this.goalCents,
    required this.minSpots,
    required this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: AppRadius.sm,
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    Text(
                        '\$${(priceCents / 100).toStringAsFixed(2)} / spot',
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
                      onTap: onDecrement,
                      borderRadius: BorderRadius.circular(12),
                      child: Icon(Icons.remove_circle_outline,
                          size: 22,
                          color: tier.maxReservedSpots > 0
                              ? context.ticketAccent
                              : AppTheme.dividerOf(context)),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('${tier.maxReservedSpots}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ),
                    InkWell(
                      onTap: onIncrement,
                      borderRadius: BorderRadius.circular(12),
                      child: Icon(Icons.add_circle_outline,
                          size: 22, color: context.ticketAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                  'Contributes: \$${(contributes / 100).toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondaryOf(context))),
              const SizedBox(width: 12),
              if (goalCents > 0 && priceCents > 0)
                Text(
                  'Min spots needed: $minSpots',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: tier.maxReservedSpots >= minSpots
                        ? AppTheme.successColor
                        : AppTheme.textSecondaryOf(context),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
