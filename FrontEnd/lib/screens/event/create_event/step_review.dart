import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/event_form_models.dart';

class StepReview extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final bool publishImmediately;
  final ValueChanged<bool> onPublishChanged;
  final ValueChanged<int> onGoToStep;

  // Basics
  final String title;
  final String? genre;
  final int imageCount;

  // Funding
  final DateTime? fundingEndAt;
  final String fundingGoal;
  final String minPledge;
  final List<MilestoneInput> milestones;

  // Dates & Tickets
  final DateTime? startTime;
  final DateTime? endTime;
  final String registrationType;
  final String? selectedStrategyName;
  final List<EditableTier> localTiers;
  final int selectedDiscountCount;

  // Location & Sponsors
  final String? selectedVenueName;
  final String capacity;
  final List<EditableSponsorCategory> localCategories;

  const StepReview({
    super.key,
    required this.formKey,
    required this.publishImmediately,
    required this.onPublishChanged,
    required this.onGoToStep,
    required this.title,
    required this.genre,
    required this.imageCount,
    required this.fundingEndAt,
    required this.fundingGoal,
    required this.minPledge,
    required this.milestones,
    required this.startTime,
    required this.endTime,
    required this.registrationType,
    required this.selectedStrategyName,
    required this.localTiers,
    required this.selectedDiscountCount,
    required this.selectedVenueName,
    required this.capacity,
    required this.localCategories,
  });

  static String _fmtDt(DateTime dt) =>
      '${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

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
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.successColor.withValues(alpha: 0.08),
                        AppTheme.successColor.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          AppTheme.successColor.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.successColor
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.check_circle_rounded,
                            size: 24, color: AppTheme.successColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Review & Publish',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        AppTheme.textPrimaryOf(context),
                                    letterSpacing: -0.3)),
                            const SizedBox(height: 2),
                            Text(
                                'Review your event details. Tap any section to edit.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondaryOf(
                                        context))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _reviewCard(
                  context: context,
                  step: 0,
                  icon: Icons.edit_note_rounded,
                  color: Colors.indigo,
                  title: 'Basics',
                  items: {
                    'Title': title.trim(),
                    'Genre': genre ?? '',
                    'Images': imageCount == 0
                        ? ''
                        : '$imageCount selected',
                  },
                ),
                _reviewCard(
                  context: context,
                  step: 1,
                  icon: Icons.attach_money_rounded,
                  color: Colors.teal,
                  title: 'Funding',
                  items: {
                    'Deadline': fundingEndAt != null
                        ? _fmtDt(fundingEndAt!)
                        : 'Not set',
                    if (fundingEndAt != null) ...{
                      'Goal': fundingGoal.isNotEmpty
                          ? '\$$fundingGoal'
                          : 'Not set',
                      'Min Pledge': '\$$minPledge',
                      'Milestones': milestones.isEmpty
                          ? 'None'
                          : '${milestones.length}',
                    },
                  },
                ),
                _reviewCard(
                  context: context,
                  step: 2,
                  icon: Icons.event_rounded,
                  color: Colors.blue,
                  title: 'Dates & Tickets',
                  items: {
                    'Start': startTime != null
                        ? _fmtDt(startTime!)
                        : 'Not set',
                    'End': endTime != null
                        ? _fmtDt(endTime!)
                        : 'Not set',
                    'Registration': registrationType == 'open'
                        ? 'Open'
                        : 'Closed (Waitlist)',
                    'Ticket Strategy': selectedStrategyName ?? 'Not set',
                    'Tiers': localTiers.isEmpty
                        ? 'None'
                        : '${localTiers.length} tiers',
                    'Discounts': selectedDiscountCount == 0
                        ? 'None'
                        : '$selectedDiscountCount selected',
                  },
                ),
                _reviewCard(
                  context: context,
                  step: 3,
                  icon: Icons.location_on_rounded,
                  color: Colors.orange,
                  title: 'Location & Sponsors',
                  items: {
                    'Venue': selectedVenueName ?? 'Not set',
                    'Capacity':
                        capacity.isNotEmpty ? capacity : 'Not set',
                    'Sponsors': localCategories.isEmpty
                        ? 'None'
                        : () {
                            final totalPrereqs =
                                localCategories.fold<int>(
                                    0, (s, c) => s + c.prereqs.length);
                            final base =
                                '${localCategories.length} sponsorship${localCategories.length == 1 ? '' : 's'}';
                            return totalPrereqs > 0
                                ? '$base, $totalPrereqs prereqs'
                                : base;
                          }(),
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text(
                    publishImmediately
                        ? 'Publish immediately'
                        : 'Save as draft',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    publishImmediately
                        ? 'Event will be visible to everyone right away'
                        : 'You can publish it later from the event detail page',
                  ),
                  value: publishImmediately,
                  activeColor: AppTheme.accentColor,
                  onChanged: onPublishChanged,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reviewCard({
    required BuildContext context,
    required int step,
    required IconData icon,
    required Color color,
    required String title,
    required Map<String, String> items,
  }) {
    return GestureDetector(
      onTap: () => onGoToStep(step),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: color)),
                ),
                Text('Edit',
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Icon(Icons.chevron_right, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 10),
            ...items.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(e.key,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryOf(
                                    context))),
                      ),
                      Expanded(
                        child: Text(
                          e.value.isNotEmpty ? e.value : 'Not set',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: e.value.isNotEmpty
                                ? FontWeight.w500
                                : FontWeight.normal,
                            color: e.value.isNotEmpty
                                ? AppTheme.textPrimaryOf(context)
                                : AppTheme.textSecondaryOf(context),
                            fontStyle: e.value.isNotEmpty
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
