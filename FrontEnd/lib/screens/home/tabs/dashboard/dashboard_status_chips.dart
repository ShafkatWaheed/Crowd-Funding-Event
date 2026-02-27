import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../config/design_tokens.dart';
import '../../../../config/theme.dart';
import '../../../../models/event.dart';
import '../../../../widgets/animated_list_item.dart';
import '../../home_shared.dart';

class DashboardStatusChips extends StatelessWidget {
  final List<dynamic> breakdown;
  final String? activeStatus;
  final ValueChanged<String> onStatusSelected;
  final VoidCallback onStatusCleared;

  const DashboardStatusChips({
    super.key,
    required this.breakdown,
    required this.activeStatus,
    required this.onStatusSelected,
    required this.onStatusCleared,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = breakdown
        .where(
            (item) => (item as Map<String, dynamic>)['status'] != 'draft')
        .toList();
    if (filtered.isEmpty) return const SizedBox.shrink();
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
      child: AnimatedListItem(
        index: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event Status',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryOf(context),
                letterSpacing: 0.5,
              ),
            ),
            AppSpacing.vMd,
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < filtered.length; i++) ...[
                    if (i > 0) AppSpacing.hSm,
                    Builder(builder: (ctx) {
                      final item = filtered[i] as Map<String, dynamic>;
                      final status = item['status'] as String;
                      final count = item['count'] as int? ?? 0;
                      final statusEnum = EventStatus.values.firstWhere(
                        (s) => s.name == status,
                        orElse: () => EventStatus.draft,
                      );
                      final color = statusChipColor(context, statusEnum);
                      final isActive = activeStatus == status;
                      return GestureDetector(
                        onTap: () {
                          if (isActive) {
                            onStatusCleared();
                          } else {
                            onStatusSelected(status);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? color
                                : color.withValues(
                                    alpha: isDark ? 0.2 : 0.1),
                            borderRadius: AppRadius.pill,
                            border: Border.all(
                                color: isActive
                                    ? color
                                    : color.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                statusDisplayName(statusEnum),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isActive ? Colors.white : color),
                              ),
                              AppSpacing.hXs,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : color.withValues(alpha: 0.2),
                                  borderRadius: AppRadius.pill,
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          isActive ? Colors.white : color),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: (80 * i).ms, duration: 300.ms)
                          .slideX(
                              begin: 0.1,
                              duration: 300.ms,
                              curve: Curves.easeOut);
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
