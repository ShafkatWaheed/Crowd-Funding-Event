import 'package:flutter/material.dart';
import '../config/app_icons.dart';
import '../config/theme.dart';
import '../models/event.dart';

// ─── Shared step model ───

class _Step {
  final String label;
  final IconData icon;
  final EventStatus status;
  final bool isFundingActive;

  _Step(this.label, this.icon, this.status, {this.isFundingActive = false});
}

// ─── Shared helpers (used by both EventLifecycleBar and EventLifecycleBreadcrumb) ───

List<_Step> _stepsForEvent(Event event) {
  final hasFunding = event.fundingEndAt != null;
  final hasEventDate = event.startTime != null;

  if (hasFunding && hasEventDate) {
    return [
      _Step('Published', Icons.check_circle_rounded, EventStatus.approved),
      _Step('Funding', Icons.volunteer_activism_rounded, EventStatus.approved,
          isFundingActive: true),
      _Step('Tickets', Icons.confirmation_number_rounded, EventStatus.selling_tickets),
      _Step('Live', Icons.play_circle_rounded, EventStatus.live),
      _Step('Done', Icons.flag_rounded, EventStatus.completed),
    ];
  } else if (hasFunding && !hasEventDate) {
    return [
      _Step('Published', Icons.check_circle_rounded, EventStatus.approved),
      _Step('Funding', Icons.volunteer_activism_rounded, EventStatus.approved,
          isFundingActive: true),
      _Step('Set Date', Icons.calendar_month_rounded, EventStatus.waiting_event_date),
      _Step('Tickets', Icons.confirmation_number_rounded, EventStatus.selling_tickets),
      _Step('Live', Icons.play_circle_rounded, EventStatus.live),
      _Step('Done', Icons.flag_rounded, EventStatus.completed),
    ];
  } else {
    return [
      _Step('Published', Icons.check_circle_rounded, EventStatus.approved),
      _Step('Tickets', Icons.confirmation_number_rounded, EventStatus.selling_tickets),
      _Step('Live', Icons.play_circle_rounded, EventStatus.live),
      _Step('Done', Icons.flag_rounded, EventStatus.completed),
    ];
  }
}

int _activeIndexForEvent(Event event, List<_Step> steps) {
  final status = event.status;
  if (status == EventStatus.cancelled) { return -1; }
  if (status == EventStatus.draft ||
      status == EventStatus.pending_approval) { return -1; }
  for (int i = steps.length - 1; i >= 0; i--) {
    final step = steps[i];
    if (step.status == status) {
      if (step.isFundingActive && !event.isFunding) continue;
      return i;
    }
  }
  if (status == EventStatus.approved) return 0;
  return -1;
}

Color _stepActiveColor(BuildContext context, _Step step) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return AppIcons.forEventStatus(step.status).color(isDark);
}

// ─── EventLifecycleBar (original — compact bar for cards, full bar for detail) ───

/// Uber-style lifecycle progress bar for events.
class EventLifecycleBar extends StatelessWidget {
  final Event event;
  final bool compact;

  const EventLifecycleBar({
    super.key,
    required this.event,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final steps = _stepsForEvent(event);
    final activeIndex = _activeIndexForEvent(event, steps);

    if (compact) {
      return _CompactBar(steps: steps, activeIndex: activeIndex);
    }
    return _FullBar(steps: steps, activeIndex: activeIndex);
  }
}

// ─── EventLifecycleBreadcrumb (full-width stepper with icon circles) ───

/// Full-width lifecycle stepper that fills the title card horizontally.
/// Each step shows a coloured icon circle + label; steps are connected by lines.
class EventLifecycleBreadcrumb extends StatelessWidget {
  final Event event;

  const EventLifecycleBreadcrumb({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final steps = _stepsForEvent(event);
    final activeIndex = _activeIndexForEvent(event, steps);

    if (activeIndex == -1) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentStep = steps[activeIndex];
    final activeColor = _stepActiveColor(context, currentStep);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final stepColor = _stepActiveColor(context, step);
        final isActive = i <= activeIndex;
        final isCurrent = i == activeIndex;
        final isPast = i < activeIndex;

        return Expanded(
          child: _BreadcrumbStep(
            step: step,
            stepColor: stepColor,
            activeColor: activeColor,
            isActive: isActive,
            isCurrent: isCurrent,
            isPast: isPast,
            isFirst: i == 0,
            isLast: i == steps.length - 1,
            isDark: isDark,
          ),
        );
      }),
    );
  }
}

class _BreadcrumbStep extends StatelessWidget {
  final _Step step;
  final Color stepColor;
  final Color activeColor;
  final bool isActive;
  final bool isCurrent;
  final bool isPast;
  final bool isFirst;
  final bool isLast;
  final bool isDark;

  const _BreadcrumbStep({
    required this.step,
    required this.stepColor,
    required this.activeColor,
    required this.isActive,
    required this.isCurrent,
    required this.isPast,
    required this.isFirst,
    required this.isLast,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Circle colours
    final Color circleBg = isCurrent
        ? stepColor
        : isPast
            ? stepColor.withValues(alpha: isDark ? 0.22 : 0.14)
            : AppTheme.dividerOf(context).withValues(alpha: isDark ? 0.6 : 1.0);
    final Color iconColor = isCurrent
        ? Colors.white
        : isPast
            ? stepColor
            : AppTheme.textSecondaryOf(context).withValues(alpha: 0.45);
    final Color labelColor = isCurrent
        ? stepColor
        : isPast
            ? AppTheme.textSecondaryOf(context)
            : AppTheme.textSecondaryOf(context).withValues(alpha: 0.45);

    final IconData icon = isPast ? Icons.check_rounded : step.icon;

    // Connector line colour
    final Color connectorColor = isPast
        ? activeColor.withValues(alpha: 0.35)
        : AppTheme.dividerOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circle + connector row
        Row(
          children: [
            // Left connector
            Expanded(
              child: Container(
                height: 1.5,
                color: isFirst ? Colors.transparent : connectorColor,
              ),
            ),
            // Icon circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: circleBg,
                shape: BoxShape.circle,
                border: isCurrent
                    ? null
                    : Border.all(
                        color: isPast
                            ? stepColor.withValues(alpha: 0.35)
                            : AppTheme.dividerOf(context),
                        width: 1,
                      ),
              ),
              child: Icon(icon, size: 13, color: iconColor),
            ),
            // Right connector
            Expanded(
              child: Container(
                height: 1.5,
                color: isLast
                    ? Colors.transparent
                    : (isCurrent || isPast)
                        ? connectorColor
                        : AppTheme.dividerOf(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          step.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: labelColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── Compact bar: coloured segments (for cards) ───

class _CompactBar extends StatelessWidget {
  final List<_Step> steps;
  final int activeIndex;

  const _CompactBar({required this.steps, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i <= activeIndex;
        final isCurrent = i == activeIndex;
        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: i < steps.length - 1 ? 2 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: activeIndex == -1
                  ? Colors.white.withValues(alpha: 0.25)
                  : isActive
                      ? _segmentColor(i, isCurrent)
                      : Colors.white.withValues(alpha: 0.2),
            ),
          ),
        );
      }),
    );
  }

  Color _segmentColor(int index, bool isCurrent) {
    if (isCurrent) return Colors.white;
    return Colors.white.withValues(alpha: 0.55);
  }
}

// ─── Full bar: segments + icons + labels (for detail, legacy) ───

class _FullBar extends StatelessWidget {
  final List<_Step> steps;
  final int activeIndex;

  const _FullBar({required this.steps, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(steps.length, (i) {
            final isActive = i <= activeIndex;
            final isCurrent = i == activeIndex;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < steps.length - 1 ? 3 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: activeIndex == -1
                      ? AppTheme.dividerOf(context)
                      : isActive
                          ? _segmentColor(context, steps[i], isCurrent)
                          : AppTheme.dividerOf(context),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(steps.length, (i) {
            final step = steps[i];
            final isActive = i <= activeIndex;
            final isCurrent = i == activeIndex;
            final color = activeIndex == -1
                ? AppTheme.textSecondaryOf(context)
                : isCurrent
                    ? _segmentColor(context, step, true)
                    : isActive
                        ? AppTheme.textPrimaryOf(context).withValues(alpha: 0.6)
                        : AppTheme.textSecondaryOf(context);

            return Expanded(
              child: Column(
                children: [
                  Icon(
                    isCurrent
                        ? step.icon
                        : (isActive ? Icons.check_circle : step.icon),
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Color _segmentColor(BuildContext context, _Step step, bool isCurrent) {
    if (!isCurrent) return AppTheme.accentColor.withValues(alpha: 0.4);
    return _stepActiveColor(context, step);
  }
}
