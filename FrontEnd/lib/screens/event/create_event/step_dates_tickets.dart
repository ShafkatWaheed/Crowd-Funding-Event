import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/event_form_models.dart';
import '../../../models/ticket_strategy.dart';
import '../../../widgets/searchable_dropdown.dart';
import '../../../widgets/create_discount_btn.dart';

class StepDatesTickets extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final DateTime? startTime;
  final DateTime? endTime;
  final VoidCallback onPickStartTime;
  final VoidCallback onPickEndTime;
  final VoidCallback onClearStartTime;
  final VoidCallback onClearEndTime;
  final String? registrationType;
  final ValueChanged<String?> onRegistrationTypeChanged;
  final DateTime? fundingEndAt;
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
  // Discounts
  final List<Map<String, dynamic>> discounts;
  final bool discountsLoading;
  final String? discountsError;
  final VoidCallback onReloadDiscounts;
  final Map<int, bool> selectedDiscounts;
  final void Function(int id, bool autoApply) onAddDiscount;
  final ValueChanged<int> onRemoveDiscount;
  // Schedule
  final bool hasSchedule;
  final ValueChanged<bool> onHasScheduleChanged;
  final List<ScheduleDayInput> scheduleDays;
  // Helpers
  final VoidCallback onMarkDirty;
  final String Function(DateTime) fmtDt;
  final Widget Function(String) buildLoadingChip;
  final Widget Function(String, VoidCallback) buildErrorRetry;

  const StepDatesTickets({
    super.key,
    required this.formKey,
    required this.startTime,
    required this.endTime,
    required this.onPickStartTime,
    required this.onPickEndTime,
    required this.onClearStartTime,
    required this.onClearEndTime,
    required this.registrationType,
    required this.onRegistrationTypeChanged,
    required this.fundingEndAt,
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
    required this.discounts,
    required this.discountsLoading,
    required this.discountsError,
    required this.onReloadDiscounts,
    required this.selectedDiscounts,
    required this.onAddDiscount,
    required this.onRemoveDiscount,
    required this.hasSchedule,
    required this.onHasScheduleChanged,
    required this.scheduleDays,
    required this.onMarkDirty,
    required this.fmtDt,
    required this.buildLoadingChip,
    required this.buildErrorRetry,
  });

  @override
  State<StepDatesTickets> createState() => _StepDatesTicketsState();
}

class _StepDatesTicketsState extends State<StepDatesTickets> {
  bool _showStrategyForm = false;
  bool _showScheduleSection = false;
  String _discountSearch = '';

  @override
  Widget build(BuildContext context) {
    final needsDates = widget.fundingEndAt == null;
    final hasDates = widget.startTime != null && widget.endTime != null;
    final statusColor = (needsDates && !hasDates)
        ? AppTheme.warningColor
        : AppTheme.successColor;
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
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.managementAccent.withValues(alpha: 0.08),
                        context.managementAccent.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.managementAccent.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: context.managementAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.event_rounded,
                            size: 24, color: context.managementAccent),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dates & Tickets',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimaryOf(context),
                                    letterSpacing: -0.3)),
                            const SizedBox(height: 2),
                            Text('Schedule your event and configure ticketing.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondaryOf(context))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.25),
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
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              (needsDates && !hasDates)
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 18,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              needsDates
                                  ? 'Start & end dates are required (no funding deadline set)'
                                  : 'Event dates (optional — funding deadline is set)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: (needsDates && !hasDates)
                                    ? AppTheme.textPrimaryOf(context)
                                    : statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Event Date',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.textSecondaryOf(context))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: widget.onPickStartTime,
                              icon: Icon(Icons.play_circle_outline_rounded,
                                  size: 18,
                                  color: widget.startTime != null
                                      ? AppTheme.primaryOf(context)
                                      : AppTheme.textSecondaryOf(context)),
                              label: Text(
                                widget.startTime != null
                                    ? widget.fmtDt(widget.startTime!)
                                    : 'Start Date & Time',
                                style: TextStyle(
                                  color: widget.startTime != null
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
                          if (widget.startTime != null) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: widget.onClearStartTime,
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: widget.onPickEndTime,
                              icon: Icon(Icons.stop_circle_outlined,
                                  size: 18,
                                  color: widget.endTime != null
                                      ? AppTheme.primaryOf(context)
                                      : AppTheme.textSecondaryOf(context)),
                              label: Text(
                                widget.endTime != null
                                    ? widget.fmtDt(widget.endTime!)
                                    : 'End Date & Time',
                                style: TextStyle(
                                  color: widget.endTime != null
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
                          if (widget.endTime != null) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: widget.onClearEndTime,
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.startTime != null && widget.fundingEndAt != null
                            ? 'Funding runs until deadline, then tickets go on sale.'
                            : widget.fundingEndAt != null && widget.startTime == null
                                ? 'After funding, you will have a grace period to set an event date.'
                                : widget.startTime != null && widget.fundingEndAt == null
                                    ? 'No funding phase — event goes straight to ticket sales.'
                                    : '',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondaryOf(context),
                            fontStyle: FontStyle.italic),
                      ),
                      if (widget.startTime != null && widget.endTime != null && !widget.endTime!.isAfter(widget.startTime!))
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(children: [
                            Icon(Icons.error_outline, size: 14, color: AppTheme.errorColor),
                            const SizedBox(width: 4),
                            Text('End time must be after start time',
                                style: TextStyle(fontSize: 11, color: AppTheme.errorColor, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      if (widget.startTime != null && widget.fundingEndAt != null && !widget.startTime!.isAfter(widget.fundingEndAt!))
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(children: [
                            Icon(Icons.error_outline, size: 14, color: AppTheme.errorColor),
                            const SizedBox(width: 4),
                            Text('Start time should be after funding deadline',
                                style: TextStyle(fontSize: 11, color: AppTheme.errorColor, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: widget.registrationType,
                  decoration: const InputDecoration(
                    labelText: 'Registration Type',
                    prefixIcon: Icon(Icons.how_to_reg_rounded, size: 20),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'open', child: Text('Open')),
                    DropdownMenuItem(
                        value: 'closed',
                        child: Text('Closed (Waitlist)')),
                  ],
                  onChanged: widget.onRegistrationTypeChanged,
                ),
                const SizedBox(height: 24),
                _buildTicketStrategySection(),
                if (widget.selectedStrategyId != null) ...[
                  const SizedBox(height: 16),
                  _buildDiscountSection(),
                ],
                if (widget.startTime != null && widget.endTime != null) ...[
                  const SizedBox(height: 24),
                  _buildScheduleSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Ticket Strategy ──

  Widget _buildTicketStrategySection() {
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

  // ── Editable Tiers Preview ──

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

  // ── Inline Strategy Form ──

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
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('Tier ${i + 1}',
                              style: const TextStyle(
                                  fontWeight:
                                      FontWeight.w600,
                                  fontSize: 12)),
                          const Spacer(),
                          if (widget.strategyTiers.length > 1)
                            IconButton(
                              onPressed: () =>
                                  widget.onRemoveStrategyTier(i),
                              icon: const Icon(Icons.close,
                                  size: 16,
                                  color:
                                      AppTheme.errorColor),
                              padding: EdgeInsets.zero,
                              constraints:
                                  const BoxConstraints(),
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
                              decoration:
                                  const InputDecoration(
                                labelText: 'Name',
                                hintText:
                                    'e.g. Platinum',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: t.priceCtrl,
                              decoration:
                                  const InputDecoration(
                                labelText: 'Price (\$)',
                                prefixText: '\$ ',
                                isDense: true,
                              ),
                              keyboardType:
                                  TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: t.descCtrl,
                        decoration:
                            const InputDecoration(
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
                        child: const CircularProgressIndicator(
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

  // ── Discounts ──

  String _discountLabel(Map<String, dynamic> d) {
    final name = d['name'] ?? '';
    final type = d['discount_type'] ?? '';
    final val = d['value'] ?? 0;
    final target = d['target'] ?? 'all';
    final typeLabel = type == 'ticket_percent' ? '% ticket' : '% pledge';
    return '$name · $val$typeLabel · $target';
  }

  List<Widget> _buildAvailableDiscountList() {
    final available = widget.discounts.where((d) {
      final id = d['id'] as int;
      if (widget.selectedDiscounts.containsKey(id)) return false;
      if (_discountSearch.isEmpty) return true;
      return _discountLabel(d).toLowerCase().contains(_discountSearch);
    }).toList();
    if (available.isEmpty && _discountSearch.isNotEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('No matching discounts',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondaryOf(context))),
        ),
      ];
    }
    if (available.isEmpty) return [];
    return available.take(3).map((d) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          decoration: BoxDecoration(
            color: context.sponsorSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(_discountLabel(d),
                    style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 6),
              CreateDiscountBtn(
                label: 'Add + Apply',
                color: AppTheme.successColor,
                onTap: () => widget.onAddDiscount(d['id'] as int, true),
              ),
              const SizedBox(width: 6),
              CreateDiscountBtn(
                label: 'Add',
                color: context.sponsorAccent,
                onTap: () => widget.onAddDiscount(d['id'] as int, false),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildDiscountSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.sponsorSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: context.sponsorAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.discount_rounded,
                  size: 18, color: context.sponsorAccent),
              const SizedBox(width: 8),
              Text('Discounts (Optional)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textPrimaryOf(context))),
            ],
          ),
          if (widget.discountsLoading)
            widget.buildLoadingChip('Loading discounts…')
          else if (widget.discountsError != null)
            widget.buildErrorRetry(widget.discountsError!, widget.onReloadDiscounts),
          const SizedBox(height: 8),
          if (widget.selectedDiscounts.isNotEmpty) ...[
            ...widget.selectedDiscounts.entries.map((entry) {
              final d = widget.discounts.firstWhere(
                (s) => s['id'] == entry.key,
                orElse: () => {
                  'name': '?',
                  'discount_type': '',
                  'value': 0,
                  'target': ''
                },
              );
              final autoApply = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.sponsorAccent
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                              color: context.sponsorAccent
                                  .withValues(alpha: 0.3),
                              width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                  _discountLabel(d),
                                  style:
                                      const TextStyle(
                                          fontSize: 12)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2),
                              decoration: BoxDecoration(
                                color: autoApply
                                    ? AppTheme.successSurfaceOf(context)
                                    : AppTheme.warningSurfaceOf(context),
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                              child: Text(
                                autoApply
                                    ? 'Auto'
                                    : 'Claimable',
                                style: TextStyle(
                                  color: autoApply
                                      ? AppTheme.successColor
                                      : context.fundingAccent,
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => widget.onRemoveDiscount(entry.key),
                      child: Icon(Icons.close,
                          size: 16,
                          color: AppTheme.textSecondaryOf(
                              context)),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
          TextField(
            decoration: InputDecoration(
              hintText: 'Search discounts…',
              hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryOf(context)),
              prefixIcon: Icon(Icons.search,
                  color: AppTheme.textSecondaryOf(context),
                  size: 20),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: AppTheme.dividerOf(context)),
              ),
            ),
            onChanged: (v) => setState(
                () => _discountSearch = v.toLowerCase()),
          ),
          ..._buildAvailableDiscountList(),
        ],
      ),
    );
  }

  // ── Schedule ──

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(
              () => _showScheduleSection = !_showScheduleSection),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _showScheduleSection
                  ? context.feedAccent.withValues(alpha: 0.08)
                  : AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showScheduleSection
                    ? context.feedAccent.withValues(alpha: 0.3)
                    : AppTheme.dividerOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    size: 18,
                    color: _showScheduleSection
                        ? context.feedAccent
                        : AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Event Schedule (Optional)',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color:
                              AppTheme.textPrimaryOf(context))),
                ),
                if (widget.scheduleDays.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.feedAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                        '${widget.scheduleDays.fold<int>(0, (sum, d) => sum + d.slots.length)}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.feedAccent)),
                  ),
                const SizedBox(width: 4),
                Icon(
                  _showScheduleSection
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
              border: Border.all(
                  color: AppTheme.dividerOf(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Use structured schedule',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryOf(
                                  context))),
                    ),
                    Switch(
                      value: widget.hasSchedule,
                      onChanged: (v) {
                        widget.onHasScheduleChanged(v);
                      },
                    ),
                  ],
                ),
                if (widget.hasSchedule) ...[
                  const SizedBox(height: 8),
                  Text('Add time slots for each day of your event.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryOf(
                              context))),
                  const SizedBox(height: 12),
                  ...widget.scheduleDays
                      .asMap()
                      .entries
                      .map((dayEntry) {
                    final dayIdx = dayEntry.key;
                    final day = dayEntry.value;
                    final dateLabel = day.date != null
                        ? '${day.date!.month}/${day.date!.day}/${day.date!.year}'
                        : 'Select date';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                            color: context.feedAccent
                                .withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  final picked =
                                      await showDatePicker(
                                    context: context,
                                    initialDate:
                                        day.date ??
                                            widget.startTime!,
                                    firstDate:
                                        widget.startTime!,
                                    lastDate: widget.endTime!,
                                  );
                                  if (picked != null) {
                                    setState(() =>
                                        day.date =
                                            picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets
                                      .symmetric(
                                      horizontal: 10,
                                      vertical: 6),
                                  decoration: BoxDecoration(
                                    color: context.feedAccent
                                        .withValues(
                                            alpha: 0.08),
                                    borderRadius:
                                        BorderRadius
                                            .circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: [
                                      Icon(
                                          Icons
                                              .calendar_today_rounded,
                                          size: 14,
                                          color:
                                              context.feedAccent),
                                      const SizedBox(
                                          width: 6),
                                      Text(dateLabel,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                              color: context.feedAccent)),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon:                               Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color:
                                        AppTheme.errorColor),
                                onPressed: () => setState(
                                    () => widget.scheduleDays
                                        .removeAt(
                                            dayIdx)),
                                padding: EdgeInsets.zero,
                                constraints:
                                    const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...day.slots
                              .asMap()
                              .entries
                              .map((slotEntry) {
                            final slotIdx =
                                slotEntry.key;
                            final slot =
                                slotEntry.value;
                            return Container(
                              margin:
                                  const EdgeInsets.only(
                                      bottom: 8),
                              padding:
                                  const EdgeInsets.all(
                                      10),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.surfaceOf(
                                        context),
                                borderRadius:
                                    BorderRadius
                                        .circular(8),
                                border: Border.all(
                                    color: AppTheme
                                        .dividerOf(
                                            context)),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .stretch,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                          'Slot ${slotIdx + 1}',
                                          style: TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                              fontSize:
                                                  12,
                                              color: AppTheme
                                                  .textSecondaryOf(
                                                      context))),
                                      const Spacer(),
                                      IconButton(
                                        icon: Icon(
                                            Icons
                                                .delete_outline,
                                            size: 16,
                                            color: AppTheme.errorColor),
                                        onPressed: () =>
                                            setState(() =>
                                                day.slots
                                                    .removeAt(
                                                        slotIdx)),
                                        padding:
                                            EdgeInsets
                                                .zero,
                                        constraints:
                                            const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                      height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child:
                                            GestureDetector(
                                          onTap:
                                              () async {
                                            final t = await showTimePicker(
                                                context:
                                                    context,
                                                initialTime:
                                                    slot.startTime);
                                            if (t !=
                                                null) {
                                              setState(() =>
                                                  slot.startTime =
                                                      t);
                                            }
                                          },
                                          child:
                                              Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal:
                                                    10,
                                                vertical:
                                                    8),
                                            decoration:
                                                BoxDecoration(
                                              border: Border.all(
                                                  color:
                                                      AppTheme.dividerOf(context)),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8),
                                            ),
                                            child: Text(
                                                slot.startTime
                                                    .format(
                                                        context),
                                                style: TextStyle(
                                                    fontSize:
                                                        12,
                                                    color:
                                                        AppTheme.textPrimaryOf(context))),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal:
                                                8),
                                        child: Text(
                                            '–',
                                            style: TextStyle(
                                                color: AppTheme
                                                    .textSecondaryOf(
                                                        context))),
                                      ),
                                      Expanded(
                                        child:
                                            GestureDetector(
                                          onTap:
                                              () async {
                                            final t = await showTimePicker(
                                                context:
                                                    context,
                                                initialTime:
                                                    slot.endTime);
                                            if (t !=
                                                null) {
                                              setState(() =>
                                                  slot.endTime =
                                                      t);
                                            }
                                          },
                                          child:
                                              Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal:
                                                    10,
                                                vertical:
                                                    8),
                                            decoration:
                                                BoxDecoration(
                                              border: Border.all(
                                                  color:
                                                      AppTheme.dividerOf(context)),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8),
                                            ),
                                            child: Text(
                                                slot.endTime
                                                    .format(
                                                        context),
                                                style: TextStyle(
                                                    fontSize:
                                                        12,
                                                    color:
                                                        AppTheme.textPrimaryOf(context))),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                      height: 8),
                                  TextFormField(
                                    controller:
                                        slot.titleCtrl,
                                    decoration:
                                        const InputDecoration(
                                      labelText:
                                          'Title',
                                      hintText:
                                          'e.g. Opening Keynote',
                                      isDense: true,
                                    ),
                                  ),
                                  const SizedBox(
                                      height: 8),
                                  TextFormField(
                                    controller:
                                        slot.descCtrl,
                                    decoration:
                                        const InputDecoration(
                                      labelText:
                                          'Description (optional)',
                                      isDense: true,
                                    ),
                                    maxLines: 2,
                                  ),
                                  const SizedBox(
                                      height: 8),
                                  TextFormField(
                                    controller:
                                        slot.imageUrlCtrl,
                                    decoration:
                                        InputDecoration(
                                      labelText:
                                          'Image URL (optional)',
                                      hintText:
                                          'https://example.com/logo.png',
                                      isDense: true,
                                      prefixIcon: Icon(
                                          Icons.image_rounded,
                                          size: 18,
                                          color: AppTheme.textSecondaryOf(context)),
                                    ),
                                  ),
                                  if (slot.imageUrlCtrl.text.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller:
                                          slot.imageCaptionCtrl,
                                      decoration:
                                          const InputDecoration(
                                        labelText:
                                            'Image caption / alt text',
                                        isDense: true,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(
                                      height: 8),
                                  TextFormField(
                                    controller:
                                        slot.linkUrlCtrl,
                                    decoration:
                                        InputDecoration(
                                      labelText:
                                          'Link URL (optional)',
                                      hintText:
                                          'https://speaker-website.com',
                                      isDense: true,
                                      prefixIcon: Icon(
                                          Icons.link_rounded,
                                          size: 18,
                                          color: AppTheme.textSecondaryOf(context)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          GestureDetector(
                            onTap: () => setState(() =>
                                day.slots.add(
                                    ScheduleSlotInput())),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(
                                        8),
                                border: Border.all(
                                    color: AppTheme
                                        .dividerOf(
                                            context)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                children: [
                                  Icon(Icons.add_rounded,
                                      size: 16,
                                      color: AppTheme
                                          .textSecondaryOf(
                                              context)),
                                  const SizedBox(width: 4),
                                  Text('Add Time Slot',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight
                                                  .w600,
                                          fontSize: 12,
                                          color: AppTheme
                                              .textSecondaryOf(
                                                  context))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: () => setState(() =>
                        widget.scheduleDays
                            .add(ScheduleDayInput())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                AppTheme.dividerOf(context)),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 18,
                              color:
                                  AppTheme.textSecondaryOf(
                                      context)),
                          const SizedBox(width: 6),
                          Text('Add Date',
                              style: TextStyle(
                                  fontWeight:
                                      FontWeight.w600,
                                  fontSize: 13,
                                  color: AppTheme
                                      .textSecondaryOf(
                                          context))),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          crossFadeState: _showScheduleSection
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}
