import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/event_form_models.dart';
import '../../../widgets/create_discount_btn.dart';

class StepDiscountsMilestones extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  // Discounts
  final List<Map<String, dynamic>> discounts;
  final bool discountsLoading;
  final String? discountsError;
  final VoidCallback onReloadDiscounts;
  final Map<int, bool> selectedDiscounts;
  final void Function(int id, bool autoApply) onAddDiscount;
  final ValueChanged<int> onRemoveDiscount;
  // Early Bird
  final List<EarlyBirdInput> earlyBirdDiscounts;
  // Discount Cap
  final int maxDiscountPercent;
  final ValueChanged<int> onMaxDiscountPercentChanged;
  // Funding state
  final DateTime? fundingEndAt;
  final int? selectedStrategyId;
  // Helpers
  final VoidCallback onMarkDirty;
  final String Function(DateTime) fmtDt;
  final Widget Function(String) buildLoadingChip;
  final Widget Function(String, VoidCallback) buildErrorRetry;

  const StepDiscountsMilestones({
    super.key,
    required this.formKey,
    required this.discounts,
    required this.discountsLoading,
    required this.discountsError,
    required this.onReloadDiscounts,
    required this.selectedDiscounts,
    required this.onAddDiscount,
    required this.onRemoveDiscount,
    required this.earlyBirdDiscounts,
    required this.maxDiscountPercent,
    required this.onMaxDiscountPercentChanged,
    required this.fundingEndAt,
    required this.selectedStrategyId,
    required this.onMarkDirty,
    required this.fmtDt,
    required this.buildLoadingChip,
    required this.buildErrorRetry,
  });

  @override
  State<StepDiscountsMilestones> createState() =>
      _StepDiscountsMilestonesState();
}

class _StepDiscountsMilestonesState extends State<StepDiscountsMilestones> {
  bool _showEarlyBirdSection = false;
  bool _showDiscountCapSection = false;
  String _discountSearch = '';

  @override
  Widget build(BuildContext context) {
    final hasAnyContent = widget.selectedStrategyId != null ||
        widget.fundingEndAt != null;
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
                const SizedBox(height: 16),
                if (!hasAnyContent)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardOf(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.dividerOf(context)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18,
                            color: AppTheme.textSecondaryOf(context)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Set up a ticket strategy or funding deadline first to configure discounts.',
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    AppTheme.textSecondaryOf(context)),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (widget.selectedStrategyId != null) ...[
                  const SizedBox(height: 8),
                  _buildDiscountSection(),
                ],
                const SizedBox(height: 16),
                _buildEarlyBirdSection(context),
                const SizedBox(height: 16),
                _buildDiscountCapSection(context),
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
            context.reviewAccent.withValues(alpha: 0.08),
            context.reviewAccent.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.reviewAccent.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.reviewAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.discount_rounded,
                size: 24, color: context.reviewAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Discounts',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryOf(context),
                        letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text(
                    'Configure discount strategies and early bird offers.',
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

  // ── Discount Strategies ──

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
            widget.buildErrorRetry(
                widget.discountsError!, widget.onReloadDiscounts),
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
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: context.sponsorAccent
                                  .withValues(alpha: 0.3),
                              width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(_discountLabel(d),
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: autoApply
                                    ? AppTheme.successSurfaceOf(context)
                                    : AppTheme.warningSurfaceOf(context),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                autoApply ? 'Auto' : 'Claimable',
                                style: TextStyle(
                                  color: autoApply
                                      ? AppTheme.successColor
                                      : context.fundingAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
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
                          color: AppTheme.textSecondaryOf(context)),
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
                  color: AppTheme.textSecondaryOf(context), size: 20),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: AppTheme.dividerOf(context)),
              ),
            ),
            onChanged: (v) =>
                setState(() => _discountSearch = v.toLowerCase()),
          ),
          ..._buildAvailableDiscountList(),
        ],
      ),
    );
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
                  fontSize: 12,
                  color: AppTheme.textSecondaryOf(context))),
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
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 6),
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
                onTap: () =>
                    widget.onAddDiscount(d['id'] as int, true),
              ),
              const SizedBox(width: 6),
              CreateDiscountBtn(
                label: 'Add',
                color: context.sponsorAccent,
                onTap: () =>
                    widget.onAddDiscount(d['id'] as int, false),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  String _discountLabel(Map<String, dynamic> d) {
    final name = d['name'] ?? '';
    final type = d['discount_type'] ?? '';
    final val = d['value'] ?? 0;
    final target = d['target'] ?? 'all';
    final typeLabel = type == 'ticket_percent' ? '% ticket' : '% pledge';
    return '$name · $val$typeLabel · $target';
  }

  // ── Early Bird Discounts ──

  Widget _buildEarlyBirdSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(
              () => _showEarlyBirdSection = !_showEarlyBirdSection),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
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
                      color: context.scheduleAccent
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                        '${widget.earlyBirdDiscounts.length}',
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
              border:
                  Border.all(color: AppTheme.dividerOf(context)),
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
                const SizedBox(height: 12),
                ...widget.earlyBirdDiscounts
                    .asMap()
                    .entries
                    .map((entry) {
                  final idx = entry.key;
                  final eb = entry.value;
                  return _buildEarlyBirdCard(idx, eb);
                }),
                GestureDetector(
                  onTap: () => setState(() =>
                      widget.earlyBirdDiscounts
                          .add(EarlyBirdInput())),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.dividerOf(context)),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded,
                            size: 18,
                            color: AppTheme.textSecondaryOf(
                                context)),
                        const SizedBox(width: 6),
                        Text('Add Early Bird Discount',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color:
                                    AppTheme.textSecondaryOf(
                                        context))),
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

  Widget _buildEarlyBirdCard(int idx, EarlyBirdInput eb) {
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
  }

  // ── Discount Cap ──

  Widget _buildDiscountCapSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(
              () => _showDiscountCapSection = !_showDiscountCapSection),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.fundingAccent
                        .withValues(alpha: 0.12),
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
              border:
                  Border.all(color: AppTheme.dividerOf(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All discounts (common, pledge, milestone, early bird) stack up to this limit.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context)),
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16),
                  ),
                  child: Slider(
                    value:
                        widget.maxDiscountPercent.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${widget.maxDiscountPercent}%',
                    activeColor: context.fundingAccent,
                    onChanged: (v) {
                      widget.onMaxDiscountPercentChanged(
                          v.round());
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
