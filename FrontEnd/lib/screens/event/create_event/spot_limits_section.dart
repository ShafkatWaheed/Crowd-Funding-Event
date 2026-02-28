import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event_form_models.dart';

class PerTierSpotLimits extends StatefulWidget {
  final TextEditingController capacityCtrl;
  final List<EditableTier> localTiers;
  final VoidCallback onMarkDirty;

  const PerTierSpotLimits({
    super.key,
    required this.capacityCtrl,
    required this.localTiers,
    required this.onMarkDirty,
  });

  @override
  State<PerTierSpotLimits> createState() => _PerTierSpotLimitsState();
}

class _PerTierSpotLimitsState extends State<PerTierSpotLimits> {
  @override
  Widget build(BuildContext context) {
    final capacity = int.tryParse(widget.capacityCtrl.text) ?? 0;
    int totalReservedSpots = 0;
    for (final tier in widget.localTiers) {
      totalReservedSpots += tier.maxReservedSpots;
    }
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
              Icon(Icons.event_seat_rounded,
                  size: 16, color: context.ticketAccent),
              const SizedBox(width: 6),
              Text('Per-Tier Reservation Limits',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.textPrimaryOf(context))),
              const Spacer(),
              if (totalReservedSpots > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: overCapacity
                        ? AppTheme.warningColor.withValues(alpha: 0.1)
                        : context.ticketAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$totalReservedSpots spot${totalReservedSpots == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: overCapacity
                          ? AppTheme.warningColor
                          : context.ticketAccent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Set how many spots can be reserved per tier during the funding phase.',
            style: TextStyle(
                fontSize: 11, color: AppTheme.textSecondaryOf(context)),
          ),
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

            return _SpotLimitTierRow(
              name: name,
              priceCents: priceCents,
              tier: tier,
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

class SpotLimitPerPledgerToggle extends StatefulWidget {
  final TextEditingController maxReservedSpotsCtrl;
  final VoidCallback onMarkDirty;

  const SpotLimitPerPledgerToggle({
    super.key,
    required this.maxReservedSpotsCtrl,
    required this.onMarkDirty,
  });

  @override
  State<SpotLimitPerPledgerToggle> createState() =>
      _SpotLimitPerPledgerToggleState();
}

class _SpotLimitPerPledgerToggleState
    extends State<SpotLimitPerPledgerToggle> {
  late bool _limitSpotsPerPledger;

  @override
  void initState() {
    super.initState();
    _limitSpotsPerPledger =
        (int.tryParse(widget.maxReservedSpotsCtrl.text) ?? 0) > 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentLimit =
        int.tryParse(widget.maxReservedSpotsCtrl.text) ?? 0;
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
                activeTrackColor: context.fundingAccent,
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
                helperText:
                    'Total spots one person can reserve across all tiers',
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
}

class SpotLimitsSection extends StatefulWidget {
  final TextEditingController capacityCtrl;
  final List<EditableTier> localTiers;
  final VoidCallback onMarkDirty;

  const SpotLimitsSection({
    super.key,
    required this.capacityCtrl,
    required this.localTiers,
    required this.onMarkDirty,
  });

  @override
  State<SpotLimitsSection> createState() => _SpotLimitsSectionState();
}

class _SpotLimitsSectionState extends State<SpotLimitsSection> {
  @override
  Widget build(BuildContext context) {
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
              Text('Per-Tier Spot Limits',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.textPrimaryOf(context))),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Maximum tickets available for each tier. Set 0 for unlimited.',
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
            return _SpotLimitTierRow(
              name: name,
              priceCents: (price * 100).round(),
              tier: tier,
              priceLabel: '\$${price.toStringAsFixed(2)} / ticket',
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

class _SpotLimitTierRow extends StatelessWidget {
  final String name;
  final int priceCents;
  final EditableTier tier;
  final String? priceLabel;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;

  const _SpotLimitTierRow({
    required this.name,
    required this.priceCents,
    required this.tier,
    this.priceLabel,
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
                Text(
                    priceLabel ??
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
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('${tier.maxReservedSpots}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
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
    );
  }
}
