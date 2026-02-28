import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/event_form_models.dart';
import '../../../models/ticket_strategy.dart';
import 'discount_section.dart';
import 'schedule_section_tickets.dart';
import 'ticket_strategy_section.dart';

class StepDatesTickets extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final needsDates = fundingEndAt == null;
    final hasDates = startTime != null && endTime != null;
    final statusColor = (needsDates && !hasDates)
        ? AppTheme.warningColor
        : AppTheme.successColor;
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
                _buildEventDatesCard(context, needsDates, hasDates, statusColor),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: registrationType,
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
                  onChanged: onRegistrationTypeChanged,
                ),
                const SizedBox(height: 24),
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
                  startTime: startTime,
                  buildLoadingChip: buildLoadingChip,
                  buildErrorRetry: buildErrorRetry,
                ),
                if (selectedStrategyId != null) ...[
                  const SizedBox(height: 16),
                  DiscountSection(
                    discounts: discounts,
                    discountsLoading: discountsLoading,
                    discountsError: discountsError,
                    onReloadDiscounts: onReloadDiscounts,
                    selectedDiscounts: selectedDiscounts,
                    onAddDiscount: onAddDiscount,
                    onRemoveDiscount: onRemoveDiscount,
                    buildLoadingChip: buildLoadingChip,
                    buildErrorRetry: buildErrorRetry,
                  ),
                ],
                if (startTime != null && endTime != null) ...[
                  const SizedBox(height: 24),
                  ScheduleSectionTickets(
                    hasSchedule: hasSchedule,
                    onHasScheduleChanged: onHasScheduleChanged,
                    scheduleDays: scheduleDays,
                    startTime: startTime!,
                    endTime: endTime!,
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
                  onPressed: onPickStartTime,
                  icon: Icon(Icons.play_circle_outline_rounded,
                      size: 18,
                      color: startTime != null
                          ? AppTheme.primaryOf(context)
                          : AppTheme.textSecondaryOf(context)),
                  label: Text(
                    startTime != null
                        ? fmtDt(startTime!)
                        : 'Start Date & Time',
                    style: TextStyle(
                      color: startTime != null
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
              if (startTime != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onClearStartTime,
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
                  onPressed: onPickEndTime,
                  icon: Icon(Icons.stop_circle_outlined,
                      size: 18,
                      color: endTime != null
                          ? AppTheme.primaryOf(context)
                          : AppTheme.textSecondaryOf(context)),
                  label: Text(
                    endTime != null
                        ? fmtDt(endTime!)
                        : 'End Date & Time',
                    style: TextStyle(
                      color: endTime != null
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
              if (endTime != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onClearEndTime,
                  icon: const Icon(Icons.clear, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            startTime != null && fundingEndAt != null
                ? 'Funding runs until deadline, then tickets go on sale.'
                : fundingEndAt != null && startTime == null
                    ? 'After funding, you will have a grace period to set an event date.'
                    : startTime != null && fundingEndAt == null
                        ? 'No funding phase — event goes straight to ticket sales.'
                        : '',
            style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondaryOf(context),
                fontStyle: FontStyle.italic),
          ),
          if (startTime != null && endTime != null && !endTime!.isAfter(startTime!))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Icon(Icons.error_outline, size: 14, color: AppTheme.errorColor),
                const SizedBox(width: 4),
                Text('End time must be after start time',
                    style: TextStyle(fontSize: 11, color: AppTheme.errorColor, fontWeight: FontWeight.w600)),
              ]),
            ),
          if (startTime != null && fundingEndAt != null && !startTime!.isAfter(fundingEndAt!))
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
    );
  }
}
