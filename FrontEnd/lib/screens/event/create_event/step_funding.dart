import 'package:flutter/material.dart';

import '../../../config/theme.dart';
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
  });

  @override
  State<StepFunding> createState() => _StepFundingState();
}

class _StepFundingState extends State<StepFunding> {
  bool _showMilestoneSection = false;

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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: widget.minPledgeCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Minimum Pledge (\$)',
                        prefixIcon: Icon(Icons.savings_rounded, size: 20),
                        prefixText: '\$ '),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: widget.maxReservedSpotsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Max Reserved Spots Per User',
                      prefixIcon: Icon(Icons.event_seat_rounded, size: 20),
                      helperText:
                          'How many ticket spots each pledger can reserve (0 = disabled)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  _buildMilestoneSection(context),
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
            Colors.teal.withValues(alpha: 0.08),
            Colors.teal.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.teal.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.attach_money_rounded,
                size: 24, color: Colors.teal),
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
                          ? Colors.teal
                          : AppTheme.textSecondaryOf(context))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.timer_rounded,
                    size: 18,
                    color: widget.fundingEndAt != null
                        ? Colors.teal
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
                          ? Colors.teal
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
                  ? Colors.amber.withValues(alpha: 0.08)
                  : AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showMilestoneSection
                    ? Colors.amber.withValues(alpha: 0.3)
                    : AppTheme.dividerOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events_rounded,
                    size: 18,
                    color: _showMilestoneSection
                        ? Colors.amber[700]
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
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${widget.milestones.length}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber[800])),
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
                                  size: 18, color: Colors.red[400]),
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
}
