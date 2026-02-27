import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/event_form_models.dart';
import '../../../models/ticket_strategy.dart';
import 'ticket_strategy_section.dart';
import 'funding_section.dart';
import 'spot_limits_section.dart';

class StepTicketsFunding extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  // Capacity
  final TextEditingController capacityCtrl;
  // Ticket strategy
  final List<TicketStrategy> strategies;
  final bool strategiesLoading;
  final String? strategiesError;
  final VoidCallback onReloadStrategies;
  final int? selectedStrategyId;
  final ValueChanged<int?> onStrategyChanged;
  final List<EditableTier> localTiers;
  final VoidCallback onAddLocalTier;
  final ValueChanged<int> onRemoveLocalTier;
  final List<StrategyTierInput> strategyTiers;
  final VoidCallback onAddStrategyTier;
  final ValueChanged<int> onRemoveStrategyTier;
  final bool creatingStrategy;
  final TextEditingController strategyNameCtrl;
  final Future<void> Function() onCreateStrategyInline;
  // Funding
  final DateTime? fundingEndAt;
  final TextEditingController fundingGoalCtrl;
  final TextEditingController minPledgeCtrl;
  final TextEditingController maxReservedSpotsCtrl;
  final bool linkFundingToTiers;
  final ValueChanged<bool> onLinkFundingToTiersChanged;
  // Helpers
  final VoidCallback onMarkDirty;
  final Widget Function(String) buildLoadingChip;
  final Widget Function(String, VoidCallback) buildErrorRetry;

  const StepTicketsFunding({
    super.key,
    required this.formKey,
    required this.capacityCtrl,
    required this.strategies,
    required this.strategiesLoading,
    required this.strategiesError,
    required this.onReloadStrategies,
    required this.selectedStrategyId,
    required this.onStrategyChanged,
    required this.localTiers,
    required this.onAddLocalTier,
    required this.onRemoveLocalTier,
    required this.strategyTiers,
    required this.onAddStrategyTier,
    required this.onRemoveStrategyTier,
    required this.creatingStrategy,
    required this.strategyNameCtrl,
    required this.onCreateStrategyInline,
    required this.fundingEndAt,
    required this.fundingGoalCtrl,
    required this.minPledgeCtrl,
    required this.maxReservedSpotsCtrl,
    required this.linkFundingToTiers,
    required this.onLinkFundingToTiersChanged,
    required this.onMarkDirty,
    required this.buildLoadingChip,
    required this.buildErrorRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
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
                TextFormField(
                  controller: capacityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Max Capacity *',
                    prefixIcon: Icon(Icons.groups_rounded, size: 20),
                    helperText: 'Total attendees your event can hold',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (int.tryParse(v) == null) return 'Enter a number';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TicketStrategySection(
                  strategies: strategies,
                  strategiesLoading: strategiesLoading,
                  strategiesError: strategiesError,
                  onReloadStrategies: onReloadStrategies,
                  selectedStrategyId: selectedStrategyId,
                  onStrategyChanged: onStrategyChanged,
                  localTiers: localTiers,
                  onAddLocalTier: onAddLocalTier,
                  onRemoveLocalTier: onRemoveLocalTier,
                  strategyTiers: strategyTiers,
                  onAddStrategyTier: onAddStrategyTier,
                  onRemoveStrategyTier: onRemoveStrategyTier,
                  creatingStrategy: creatingStrategy,
                  strategyNameCtrl: strategyNameCtrl,
                  onCreateStrategyInline: onCreateStrategyInline,
                  fundingEndAt: fundingEndAt,
                  buildLoadingChip: buildLoadingChip,
                  buildErrorRetry: buildErrorRetry,
                ),
                if (fundingEndAt != null) ...[
                  const SizedBox(height: 24),
                  FundingGoalSection(fundingGoalCtrl: fundingGoalCtrl),
                ],
                if (localTiers.isNotEmpty && fundingEndAt != null) ...[
                  const SizedBox(height: 20),
                  TierLinkToggle(
                    linkFundingToTiers: linkFundingToTiers,
                    onLinkFundingToTiersChanged: onLinkFundingToTiersChanged,
                    onMarkDirty: onMarkDirty,
                  ),
                  if (linkFundingToTiers) ...[
                    const SizedBox(height: 16),
                    PerTierReservationCalculator(
                      fundingGoalCtrl: fundingGoalCtrl,
                      capacityCtrl: capacityCtrl,
                      localTiers: localTiers,
                      onMarkDirty: onMarkDirty,
                    ),
                    const SizedBox(height: 16),
                    SpotLimitPerPledgerToggle(
                      maxReservedSpotsCtrl: maxReservedSpotsCtrl,
                      onMarkDirty: onMarkDirty,
                    ),
                  ],
                ],
                if (fundingEndAt != null && !linkFundingToTiers) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: minPledgeCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Minimum Pledge (\$)',
                        prefixIcon: Icon(Icons.savings_rounded, size: 20),
                        prefixText: '\$ '),
                    keyboardType: TextInputType.number,
                  ),
                  if (localTiers.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    PerTierSpotLimits(
                      capacityCtrl: capacityCtrl,
                      localTiers: localTiers,
                      onMarkDirty: onMarkDirty,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SpotLimitPerPledgerToggle(
                    maxReservedSpotsCtrl: maxReservedSpotsCtrl,
                    onMarkDirty: onMarkDirty,
                  ),
                ],
                if (fundingEndAt == null && localTiers.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SpotLimitsSection(
                    capacityCtrl: capacityCtrl,
                    localTiers: localTiers,
                    onMarkDirty: onMarkDirty,
                  ),
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
            context.ticketAccent.withValues(alpha: 0.08),
            context.ticketAccent.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.ticketAccent.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.ticketAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.confirmation_number_rounded,
                size: 24, color: context.ticketAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tickets & Funding Strategy',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryOf(context),
                        letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text('Configure capacity, tiers, and funding goals.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
