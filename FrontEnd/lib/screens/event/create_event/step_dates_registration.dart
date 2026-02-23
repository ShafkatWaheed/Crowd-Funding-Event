import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/event_form_models.dart';

class StepDatesRegistration extends StatefulWidget {
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
  final VoidCallback onPickFundingDeadline;
  final VoidCallback onClearFundingDeadline;
  final int refundDeadlineDays;
  final ValueChanged<int> onRefundDeadlineDaysChanged;
  // Milestones
  final List<MilestoneInput> milestones;
  // Schedule
  final bool hasSchedule;
  final ValueChanged<bool> onHasScheduleChanged;
  final List<ScheduleDayInput> scheduleDays;
  // Helpers
  final VoidCallback onMarkDirty;
  final String Function(DateTime) fmtDt;

  const StepDatesRegistration({
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
    required this.onPickFundingDeadline,
    required this.onClearFundingDeadline,
    required this.refundDeadlineDays,
    required this.onRefundDeadlineDaysChanged,
    required this.milestones,
    required this.hasSchedule,
    required this.onHasScheduleChanged,
    required this.scheduleDays,
    required this.onMarkDirty,
    required this.fmtDt,
  });

  @override
  State<StepDatesRegistration> createState() => _StepDatesRegistrationState();
}

class _StepDatesRegistrationState extends State<StepDatesRegistration> {
  bool _showMilestoneSection = false;
  bool _showScheduleSection = false;

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
                _buildHeader(context),
                const SizedBox(height: 24),
                _buildEventDatesCard(context, needsDates, hasDates, statusColor),
                const SizedBox(height: 20),
                _buildFundingDeadlineCard(context),
                if (widget.fundingEndAt != null) ...[
                  const SizedBox(height: 20),
                  _buildRefundDeadlineCard(context),
                  const SizedBox(height: 16),
                  _buildMilestoneSection(context),
                ],
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

  Widget _buildHeader(BuildContext context) {
    return Container(
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
                Text('Dates & Registration, Funding',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryOf(context),
                        letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text('Set event dates, funding deadline, and registration type.',
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

  Widget _buildEventDatesCard(
      BuildContext context, bool needsDates, bool hasDates, Color statusColor) {
    return Container(
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
                        : 'Set either funding deadline or both start & end dates.',
            style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondaryOf(context),
                fontStyle: FontStyle.italic),
          ),
          if (widget.startTime != null &&
              widget.endTime != null &&
              !widget.endTime!.isAfter(widget.startTime!))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Icon(Icons.error_outline, size: 14, color: AppTheme.errorColor),
                const SizedBox(width: 4),
                Text('End time must be after start time',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          if (widget.startTime != null &&
              widget.fundingEndAt != null &&
              !widget.startTime!.isAfter(widget.fundingEndAt!))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Icon(Icons.error_outline, size: 14, color: AppTheme.errorColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('Event start must be after funding deadline',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.errorColor,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
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
                          ? context.fundingAccent
                          : AppTheme.textSecondaryOf(context))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.timer_rounded,
                    size: 18,
                    color: widget.fundingEndAt != null
                        ? context.fundingAccent
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
                          ? context.fundingAccent
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
                    return _buildScheduleDay(dayIdx, day, dateLabel);
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

  Widget _buildScheduleDay(int dayIdx, ScheduleDayInput day, String dateLabel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: context.feedAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: day.date ?? widget.startTime!,
                    firstDate: widget.startTime!,
                    lastDate: widget.endTime!,
                  );
                  if (picked != null) {
                    setState(() => day.date = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.feedAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 14, color: context.feedAccent),
                      const SizedBox(width: 6),
                      Text(dateLabel,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.feedAccent)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18, color: AppTheme.errorColor),
                onPressed: () => setState(
                    () => widget.scheduleDays.removeAt(dayIdx)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...day.slots.asMap().entries.map((slotEntry) {
            final slotIdx = slotEntry.key;
            final slot = slotEntry.value;
            return _buildScheduleSlot(day, slotIdx, slot);
          }),
          GestureDetector(
            onTap: () => setState(
                () => day.slots.add(ScheduleSlotInput())),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.dividerOf(context)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded,
                      size: 16,
                      color: AppTheme.textSecondaryOf(context)),
                  const SizedBox(width: 4),
                  Text('Add Time Slot',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppTheme.textSecondaryOf(context))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSlot(
      ScheduleDayInput day, int slotIdx, ScheduleSlotInput slot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Slot ${slotIdx + 1}',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context))),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 16, color: AppTheme.errorColor),
                onPressed: () =>
                    setState(() => day.slots.removeAt(slotIdx)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context,
                        initialTime: slot.startTime);
                    if (t != null) {
                      setState(() => slot.startTime = t);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppTheme.dividerOf(context)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(slot.startTime.format(context),
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textPrimaryOf(context))),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('–',
                    style: TextStyle(
                        color: AppTheme.textSecondaryOf(context))),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context,
                        initialTime: slot.endTime);
                    if (t != null) {
                      setState(() => slot.endTime = t);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppTheme.dividerOf(context)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(slot.endTime.format(context),
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textPrimaryOf(context))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: slot.titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. Opening Keynote',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: slot.descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              isDense: true,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: slot.imageUrlCtrl,
            decoration: InputDecoration(
              labelText: 'Image URL (optional)',
              hintText: 'https://example.com/logo.png',
              isDense: true,
              prefixIcon: Icon(Icons.image_rounded,
                  size: 18,
                  color: AppTheme.textSecondaryOf(context)),
            ),
          ),
          if (slot.imageUrlCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            TextFormField(
              controller: slot.imageCaptionCtrl,
              decoration: const InputDecoration(
                labelText: 'Image caption / alt text',
                isDense: true,
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextFormField(
            controller: slot.linkUrlCtrl,
            decoration: InputDecoration(
              labelText: 'Link URL (optional)',
              hintText: 'https://speaker-website.com',
              isDense: true,
              prefixIcon: Icon(Icons.link_rounded,
                  size: 18,
                  color: AppTheme.textSecondaryOf(context)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Funding Milestones ──

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
                  ? context.reviewAccent.withValues(alpha: 0.08)
                  : AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showMilestoneSection
                    ? context.reviewAccent.withValues(alpha: 0.3)
                    : AppTheme.dividerOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events_rounded,
                    size: 18,
                    color: _showMilestoneSection
                        ? context.photoAccent
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
                      color:
                          context.reviewAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${widget.milestones.length}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.reviewAccent)),
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
                  return _buildMilestoneCard(idx, ms);
                }),
                GestureDetector(
                  onTap: () => setState(
                      () => widget.milestones.add(MilestoneInput())),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.dividerOf(context)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded,
                            size: 18,
                            color:
                                AppTheme.textSecondaryOf(context)),
                        const SizedBox(width: 6),
                        Text('Add Milestone',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppTheme.textSecondaryOf(
                                    context))),
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

  Widget _buildMilestoneCard(int idx, MilestoneInput ms) {
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
              Text('Milestone ${idx + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18, color: AppTheme.errorColor),
                onPressed: () =>
                    setState(() => widget.milestones.removeAt(idx)),
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
                      color: AppTheme.textSecondaryOf(context))),
              Expanded(
                child: Slider(
                  value: ms.unlockPercent.toDouble(),
                  min: 1,
                  max: 100,
                  divisions: 99,
                  label: '${ms.unlockPercent}%',
                  onChanged: (v) =>
                      setState(() => ms.unlockPercent = v.round()),
                ),
              ),
              SizedBox(
                width: 42,
                child: Text('${ms.unlockPercent}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
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
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.discount_rounded,
                  size: 14, color: context.fundingAccent),
              const SizedBox(width: 6),
              Text('Discount for early pledgers',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondaryOf(context))),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: ms.discountValueCtrl,
            decoration: const InputDecoration(
              labelText: 'Discount %',
              hintText: '0',
              isDense: true,
              suffixText: '%',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 2),
          Text(
            'Pledgers at this milestone get this % off tickets',
            style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondaryOf(context)),
          ),
        ],
      ),
    );
  }
}
