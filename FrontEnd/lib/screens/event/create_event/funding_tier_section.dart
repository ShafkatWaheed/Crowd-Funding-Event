import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event_form_models.dart';

class FundingTierLinkCard extends StatelessWidget {
  final bool linkFundingToTiers;
  final ValueChanged<bool> onLinkFundingToTiersChanged;
  final VoidCallback onMarkDirty;

  const FundingTierLinkCard({
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
                activeTrackColor: context.ticketAccent,
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

class PerTierReservationConfig extends StatefulWidget {
  final List<EditableTier> localTiers;
  final VoidCallback onMarkDirty;

  const PerTierReservationConfig({
    super.key,
    required this.localTiers,
    required this.onMarkDirty,
  });

  @override
  State<PerTierReservationConfig> createState() =>
      _PerTierReservationConfigState();
}

class _PerTierReservationConfigState extends State<PerTierReservationConfig> {
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                color:
                                    AppTheme.textSecondaryOf(context))),
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
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6),
                          child: Text('${tier.maxReservedSpots}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
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
}

class FundingSpotLimitToggle extends StatefulWidget {
  final TextEditingController maxReservedSpotsCtrl;
  final VoidCallback onMarkDirty;

  const FundingSpotLimitToggle({
    super.key,
    required this.maxReservedSpotsCtrl,
    required this.onMarkDirty,
  });

  @override
  State<FundingSpotLimitToggle> createState() =>
      _FundingSpotLimitToggleState();
}

class _FundingSpotLimitToggleState extends State<FundingSpotLimitToggle> {
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
