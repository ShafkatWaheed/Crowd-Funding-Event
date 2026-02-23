import 'dart:math';

import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event_form_models.dart';
import '../../../models/ticket_strategy.dart';
import '../../../widgets/searchable_dropdown.dart';

class StepTicketsFunding extends StatefulWidget {
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
  State<StepTicketsFunding> createState() => _StepTicketsFundingState();
}

class _StepTicketsFundingState extends State<StepTicketsFunding> {
  bool _showStrategyForm = false;
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
                TextFormField(
                  controller: widget.capacityCtrl,
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
                _buildTicketStrategySection(),
                if (widget.fundingEndAt != null) ...[
                  const SizedBox(height: 24),
                  _buildFundingGoalSection(context),
                ],
                if (widget.localTiers.isNotEmpty &&
                    widget.fundingEndAt != null) ...[
                  const SizedBox(height: 20),
                  _buildTierLinkToggle(context),
                  if (widget.linkFundingToTiers) ...[
                    const SizedBox(height: 16),
                    _buildPerTierReservationCalculator(context),
                    const SizedBox(height: 16),
                    _buildSpotLimitPerPledgerToggle(context),
                  ],
                ],
                if (widget.fundingEndAt != null &&
                    !widget.linkFundingToTiers) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: widget.minPledgeCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Minimum Pledge (\$)',
                        prefixIcon: Icon(Icons.savings_rounded, size: 20),
                        prefixText: '\$ '),
                    keyboardType: TextInputType.number,
                  ),
                  if (widget.localTiers.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildPerTierSpotLimits(context),
                  ],
                  const SizedBox(height: 16),
                  _buildSpotLimitPerPledgerToggle(context),
                ],
                if (widget.fundingEndAt == null &&
                    widget.localTiers.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildSpotLimitsSection(context),
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

  Widget _buildTicketStrategySection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (widget.fundingEndAt == null &&
                widget.selectedStrategyId == null)
            ? AppTheme.warningColor.withValues(alpha: 0.08)
            : AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (widget.fundingEndAt == null &&
                  widget.selectedStrategyId == null)
              ? AppTheme.warningColor.withValues(alpha: 0.3)
              : AppTheme.dividerOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.confirmation_number,
                  size: 18,
                  color: widget.selectedStrategyId != null
                      ? AppTheme.successColor
                      : AppTheme.primaryOf(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.fundingEndAt == null
                      ? 'Ticket Strategy (Required)'
                      : 'Ticket Strategy (Optional — can set later)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: widget.selectedStrategyId != null
                        ? AppTheme.successColor
                        : AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.strategiesLoading)
            widget.buildLoadingChip('Loading strategies…')
          else if (widget.strategiesError != null)
            widget.buildErrorRetry(
                widget.strategiesError!, widget.onReloadStrategies),
          SearchableDropdown<TicketStrategy>(
            label: 'Ticket Strategy',
            hint: widget.strategiesLoading
                ? 'Loading…'
                : 'Search strategies…',
            items: widget.strategies,
            selectedItem: widget.strategies
                .where((s) => s.id == widget.selectedStrategyId)
                .firstOrNull,
            itemLabel: (s) => s.name,
            itemSubtitle: (s) => s.tiersSummary,
            filter: (s, q) =>
                s.name.toLowerCase().contains(q.toLowerCase()),
            onSelected: (s) => widget.onStrategyChanged(s?.id),
            validator: (_) {
              if (widget.fundingEndAt == null &&
                  widget.selectedStrategyId == null) {
                return 'Required when no funding deadline';
              }
              return null;
            },
          ),
          if (widget.selectedStrategyId != null &&
              widget.localTiers.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildEditableTiersPreview(),
          ],
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () =>
                setState(() => _showStrategyForm = !_showStrategyForm),
            child: Row(
              children: [
                Icon(
                  _showStrategyForm
                      ? Icons.expand_less
                      : Icons.add_circle_outline,
                  size: 20,
                  color: AppTheme.primaryOf(context),
                ),
                const SizedBox(width: 6),
                Text(
                  _showStrategyForm
                      ? 'Hide strategy form'
                      : 'Create a new strategy',
                  style: TextStyle(
                    color: AppTheme.primaryOf(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildInlineStrategyForm(),
            crossFadeState: _showStrategyForm
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
          if (widget.fundingEndAt != null &&
              widget.selectedStrategyId == null) ...[
            const SizedBox(height: 6),
            Text(
              'You can also set up ticketing later during the "Waiting on Event Date" state.',
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryOf(context),
                  fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditableTiersPreview() {
    if (widget.localTiers.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(top: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.tune,
                    size: 14,
                    color: AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Customize tiers for this event',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryOf(context),
                        fontStyle: FontStyle.italic),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onAddLocalTier,
                  icon: const Icon(Icons.add, size: 14),
                  label:
                      const Text('Add', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(widget.localTiers.length, (i) {
              final t = widget.localTiers[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('Tier ${i + 1}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                          const Spacer(),
                          if (widget.localTiers.length > 1)
                            IconButton(
                              onPressed: () =>
                                  widget.onRemoveLocalTier(i),
                              icon: const Icon(Icons.close,
                                  size: 16,
                                  color: AppTheme.errorColor),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: t.nameCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Name',
                                  hintText: 'e.g. Platinum',
                                  isDense: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: t.priceCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Price (\$)',
                                  prefixText: '\$ ',
                                  isDense: true),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: t.descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          hintText:
                              'e.g. Front row seating, backstage access',
                          isDense: true,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineStrategyForm() {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New Ticket Strategy',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.strategyNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Strategy Name',
                hintText: 'e.g. "Concert Standard"',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.layers,
                    size: 16,
                    color: AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 6),
                Text('Tiers',
                    style: Theme.of(context).textTheme.bodyMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: widget.onAddStrategyTier,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            ...List.generate(widget.strategyTiers.length, (i) {
              final t = widget.strategyTiers[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('Tier ${i + 1}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                          const Spacer(),
                          if (widget.strategyTiers.length > 1)
                            IconButton(
                              onPressed: () =>
                                  widget.onRemoveStrategyTier(i),
                              icon: const Icon(Icons.close,
                                  size: 16,
                                  color: AppTheme.errorColor),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: t.nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                hintText: 'e.g. Platinum',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: t.priceCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Price (\$)',
                                prefixText: '\$ ',
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: t.descCtrl,
                        decoration: const InputDecoration(
                          labelText:
                              'Description (what this tier provides)',
                          hintText:
                              'e.g. Front row seating, backstage access',
                          isDense: true,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                onPressed: widget.creatingStrategy
                    ? null
                    : widget.onCreateStrategyInline,
                icon: widget.creatingStrategy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(widget.creatingStrategy
                    ? 'Creating...'
                    : 'Create & Select Strategy'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFundingGoalSection(BuildContext context) {
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
            controller: widget.fundingGoalCtrl,
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

  Widget _buildPerTierReservationCalculator(BuildContext context) {
    final goalCents = ((double.tryParse(widget.fundingGoalCtrl.text) ?? 0) * 100).round();
    final capacity = int.tryParse(widget.capacityCtrl.text) ?? 0;

    int totalReservedValue = 0;
    int totalReservedSpots = 0;
    for (final tier in widget.localTiers) {
      final priceCents = ((double.tryParse(tier.priceCtrl.text) ?? 0) * 100).round();
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

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                    color:
                                        AppTheme.textPrimaryOf(context))),
                            Text(
                                '\$${(priceCents / 100).toStringAsFixed(2)} / spot',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondaryOf(
                                        context))),
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
                              child: Icon(
                                  Icons.remove_circle_outline,
                                  size: 22,
                                  color: tier.maxReservedSpots > 0
                                      ? context.ticketAccent
                                      : AppTheme.dividerOf(context)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6),
                              child: Text(
                                  '${tier.maxReservedSpots}',
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
                                  size: 22,
                                  color: context.ticketAccent),
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
                              color:
                                  AppTheme.textSecondaryOf(context))),
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
          }),
        ],
      ),
    );
  }

  Widget _buildPerTierSpotLimits(BuildContext context) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

  Widget _buildSpotLimitPerPledgerToggle(BuildContext context) {
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

  Widget _buildSpotLimitsSection(BuildContext context) {
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
                                color:
                                    AppTheme.textPrimaryOf(context))),
                        Text('\$${price.toStringAsFixed(2)} / ticket',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondaryOf(
                                    context))),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6),
                          child: Text(
                              '${tier.maxReservedSpots}',
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
