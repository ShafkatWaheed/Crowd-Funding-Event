import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/ticket_strategy.dart';
import '../../../widgets/searchable_dropdown.dart';

class EditFundingSection extends StatelessWidget {
  final TextEditingController fundingGoalCtrl;
  final TextEditingController minPledgeCtrl;
  final TextEditingController maxReservedSpotsCtrl;
  final bool communityRules;
  final bool communityRulesFeatureEnabled;
  final bool isDraft;
  final ValueChanged<bool> onCommunityRulesChanged;
  final int refundDeadlineDays;
  final ValueChanged<int> onRefundDeadlineDaysChanged;
  final DateTime? fundingEndAt;
  final List<TicketStrategy> strategies;
  final int? selectedStrategyId;
  final ValueChanged<int?> onStrategyChanged;

  const EditFundingSection({
    super.key,
    required this.fundingGoalCtrl,
    required this.minPledgeCtrl,
    required this.maxReservedSpotsCtrl,
    required this.communityRules,
    required this.communityRulesFeatureEnabled,
    required this.isDraft,
    required this.onCommunityRulesChanged,
    required this.refundDeadlineDays,
    required this.onRefundDeadlineDaysChanged,
    required this.fundingEndAt,
    required this.strategies,
    required this.selectedStrategyId,
    required this.onStrategyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isDraft) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Community Event Rules'),
            subtitle: Text(
              communityRulesFeatureEnabled
                  ? 'Apply platform community rules (e.g. max ticket price, capacity limits)'
                  : 'Community rules are currently disabled by the platform',
            ),
            value: communityRules,
            onChanged:
                communityRulesFeatureEnabled ? onCommunityRulesChanged : null,
          ),
          const SizedBox(height: 16),
        ],

        Text('Funding', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),

        TextFormField(
          controller: fundingGoalCtrl,
          decoration: const InputDecoration(
            labelText: 'Funding Goal (\$)',
            prefixText: '\$ ',
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: minPledgeCtrl,
          decoration: const InputDecoration(
            labelText: 'Minimum Pledge (\$)',
            prefixText: '\$ ',
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: maxReservedSpotsCtrl,
          decoration: const InputDecoration(
            labelText: 'Max Reserved Spots Per User',
            helperText:
                'How many ticket spots each pledger can reserve (0 = disabled)',
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),

        Text('Ticket Strategy',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SearchableDropdown<TicketStrategy>(
          label: 'Ticket Strategy',
          hint: 'Search strategies…',
          items: strategies,
          selectedItem: strategies
              .where((s) => s.id == selectedStrategyId)
              .firstOrNull,
          itemLabel: (s) => s.name,
          itemSubtitle: (s) => s.tiersSummary,
          filter: (s, q) =>
              s.name.toLowerCase().contains(q.toLowerCase()),
          onSelected: (s) => onStrategyChanged(s?.id),
        ),
        const SizedBox(height: 16),

        if (fundingEndAt != null)
          _buildRefundDeadline(context),
      ],
    );
  }

  Widget _buildRefundDeadline(BuildContext context) {
    final fundDuration =
        fundingEndAt!.difference(DateTime.now()).inDays;
    final maxDays = (fundDuration * 0.2).ceil().clamp(1, 365);
    final effectiveDays = refundDeadlineDays.clamp(0, maxDays);

    if (effectiveDays != refundDeadlineDays) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onRefundDeadlineDaysChanged(effectiveDays);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Refund Deadline: $effectiveDays day${effectiveDays == 1 ? '' : 's'} before funding ends',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Max $maxDays days (20% of funding duration). Customers can get a refund if they unregister before this cutoff.',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryOf(context),
          ),
        ),
        const SizedBox(height: 8),
        Slider(
          value: effectiveDays.toDouble(),
          min: 0,
          max: maxDays.toDouble(),
          divisions: maxDays > 0 ? maxDays : 1,
          label: '$effectiveDays days',
          activeColor: AppTheme.primaryColor,
          onChanged: (v) => onRefundDeadlineDaysChanged(v.round()),
        ),
      ],
    );
  }
}
