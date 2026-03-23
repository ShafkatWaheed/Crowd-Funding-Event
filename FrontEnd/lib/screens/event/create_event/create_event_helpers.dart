import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../models/event.dart';
import '../../../models/event_form_models.dart';
import '../../../models/ticket_strategy.dart';
import '../../../models/venue.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/date_time_utils.dart';
import '../../../widgets/app_toast.dart';

String fmtDt(DateTime dt) => AppDateFormat.fullDateTime(dt);

Widget buildLoadingChip(BuildContext context, String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
      ],
    ),
  );
}

Widget buildErrorRetry(BuildContext context, String message, VoidCallback onRetry) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(Icons.error_outline, size: 16, color: AppTheme.errorColor),
        const SizedBox(width: 6),
        Expanded(child: Text(message, style: TextStyle(fontSize: 12, color: AppTheme.errorColor))),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Retry', style: TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );
}

bool validateCreateEventStep({
  required BuildContext context,
  required int currentStep,
  required GlobalKey<FormState> formKey,
  required String title,
  required String? genre,
  required DateTime? fundingEndAt,
  required DateTime? startTime,
  required DateTime? endTime,
  required String capacityText,
  required int? selectedVenueId,
  required ValueChanged<int> onStepError,
  required ValueChanged<int> onStepClear,
}) {
  bool fail(String msg) {
    AppToast.error(context, msg);
    onStepError(currentStep);
    return false;
  }
  bool pass() {
    onStepClear(currentStep);
    return true;
  }

  final formState = formKey.currentState;
  if (formState != null && !formState.validate()) return fail('Please fix the highlighted fields');

  switch (currentStep) {
    case 0:
      if (title.trim().isEmpty) return fail('Event title is required');
      if (genre == null) return fail('Please select a genre');
      return pass();
    case 1:
      if (fundingEndAt == null && (startTime == null || endTime == null)) {
        return fail('Set both start & end dates, or set a funding deadline');
      }
      if (startTime != null && endTime == null) return fail('End time is required when start time is set');
      if (startTime != null && endTime != null && !endTime.isAfter(startTime)) {
        return fail('End time must be after start time');
      }
      if (startTime != null && fundingEndAt != null && !startTime.isAfter(fundingEndAt)) {
        return fail('Event start must be after funding deadline');
      }
      return pass();
    case 2:
      if (capacityText.trim().isEmpty || int.tryParse(capacityText.trim()) == null) {
        return fail('Please enter a valid max capacity');
      }
      return pass();
    case 3:
      return pass();
    case 4:
      if (selectedVenueId == null) return fail('Please select a venue');
      return pass();
    case 5:
      return pass();
  }
  return pass();
}

Event buildPreviewEvent({
  required BuildContext context,
  required String title,
  required String description,
  required DateTime? startTime,
  required DateTime? endTime,
  required DateTime? fundingEndAt,
  required String fundingGoalText,
  required String minPledgeText,
  required String capacityText,
  required String registrationType,
  required String? genre,
  required bool communityRules,
  required bool postsEnabled,
  required bool faqEnabled,
  required int refundDeadlineDays,
  required int? selectedStrategyId,
  required List<TicketStrategy> strategies,
  required int? selectedVenueId,
  required List<Venue> venues,
  required bool hasSchedule,
  required List<ScheduleDayInput> scheduleDays,
  required bool linkFundingToTiers,
  required bool ageRestricted,
  required int minAge,
}) {
  final user = context.read<AuthProvider>().user;
  final venue = venues.where((v) => v.id == selectedVenueId).firstOrNull;

  int parseCents(String text) {
    final val = double.tryParse(text) ?? 0;
    return (val * 100).round();
  }

  return Event(
    id: 0,
    organizerId: user?.id ?? 0,
    organizerName: user?.displayName ?? 'You',
    venueId: selectedVenueId ?? 0,
    title: title.trim().isNotEmpty ? title.trim() : 'Untitled Event',
    description: description.trim().isNotEmpty ? description.trim() : null,
    startTime: startTime,
    endTime: endTime,
    fundingGoalCents: fundingEndAt != null ? parseCents(fundingGoalText) : null,
    fundingEndAt: fundingEndAt,
    minPledgeCents: parseCents(minPledgeText),
    status: EventStatus.draft,
    registrationType: registrationType == 'open' ? RegistrationType.open : RegistrationType.closed,
    maxCapacity: int.tryParse(capacityText) ?? 0,
    commonDiscountPercent: 0,
    pledgeDiscountPercent: 0,
    genre: genre,
    communityRules: communityRules,
    postsEnabled: postsEnabled,
    faqEnabled: faqEnabled,
    refundDeadlineDays: refundDeadlineDays,
    ticketStrategyId: selectedStrategyId,
    ticketStrategyName: strategies.where((s) => s.id == selectedStrategyId).firstOrNull?.name,
    venue: venue,
    hasSchedule: hasSchedule && scheduleDays.isNotEmpty,
    linkFundingToTiers: linkFundingToTiers,
    ageRestricted: ageRestricted,
    minAge: minAge,
    createdAt: DateTime.now(),
  );
}
