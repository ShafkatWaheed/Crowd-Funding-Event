import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/event_form_models.dart';
import '../../../models/ticket_strategy.dart';
import '../../../widgets/searchable_dropdown.dart';

class TicketStrategySection extends StatefulWidget {
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
  final DateTime? fundingEndAt;
  final DateTime? startTime;
  final Widget Function(String) buildLoadingChip;
  final Widget Function(String, VoidCallback) buildErrorRetry;

  const TicketStrategySection({
    super.key,
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
    this.startTime,
    required this.buildLoadingChip,
    required this.buildErrorRetry,
  });

  @override
  State<TicketStrategySection> createState() => _TicketStrategySectionState();
}

class _TicketStrategySectionState extends State<TicketStrategySection> {
  bool _showStrategyForm = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (widget.fundingEndAt == null && widget.selectedStrategyId == null)
            ? AppTheme.warningColor.withValues(alpha: 0.08)
            : AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (widget.fundingEndAt == null && widget.selectedStrategyId == null)
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
            widget.buildErrorRetry(widget.strategiesError!, widget.onReloadStrategies),
          SearchableDropdown<TicketStrategy>(
            label: 'Ticket Strategy',
            hint: widget.strategiesLoading ? 'Loading…' : 'Search strategies…',
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
                  widget.startTime != null &&
                  widget.selectedStrategyId == null) {
                return 'Required when no funding deadline';
              }
              return null;
            },
          ),
          if (widget.selectedStrategyId != null && widget.localTiers.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildEditableTiersPreview(),
          ],
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(
                () => _showStrategyForm = !_showStrategyForm),
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
                Icon(Icons.tune, size: 14, color: AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Customize tiers for this event',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context), fontStyle: FontStyle.italic),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onAddLocalTier,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const Spacer(),
                          if (widget.localTiers.length > 1)
                            IconButton(
                              onPressed: () => widget.onRemoveLocalTier(i),
                              icon: const Icon(Icons.close, size: 16, color: AppTheme.errorColor),
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
                              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Platinum', isDense: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: t.priceCtrl,
                              decoration: const InputDecoration(labelText: 'Price (\$)', prefixText: '\$ ', isDense: true),
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
                          hintText: 'e.g. Front row seating, backstage access',
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
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium),
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
                          labelText: 'Description (what this tier provides)',
                          hintText: 'e.g. Front row seating, backstage access',
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
                            strokeWidth: 2,
                            color: Colors.white),
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
}
