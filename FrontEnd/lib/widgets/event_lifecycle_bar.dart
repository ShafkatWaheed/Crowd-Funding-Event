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
      _Step('Published', Icons.check_circle_outline, EventStatus.approved),
      _Step('Funding', Icons.volunteer_activism, EventStatus.approved,
          isFundingActive: true),
      _Step('Tickets', Icons.confirmation_number, EventStatus.selling_tickets),
      _Step('Live', Icons.play_circle_filled, EventStatus.live),
      _Step('Done', Icons.flag, EventStatus.completed),
    ];
  } else if (hasFunding && !hasEventDate) {
    return [
      _Step('Published', Icons.check_circle_outline, EventStatus.approved),
      _Step('Funding', Icons.volunteer_activism, EventStatus.approved,
          isFundingActive: true),
      _Step('Set Date', Icons.calendar_month, EventStatus.waiting_event_date),
      _Step('Tickets', Icons.confirmation_number, EventStatus.selling_tickets),
      _Step('Live', Icons.play_circle_filled, EventStatus.live),
      _Step('Done', Icons.flag, EventStatus.completed),
    ];
  } else {
    return [
      _Step('Published', Icons.check_circle_outline, EventStatus.approved),
      _Step('Tickets', Icons.confirmation_number, EventStatus.selling_tickets),
      _Step('Live', Icons.play_circle_filled, EventStatus.live),
      _Step('Done', Icons.flag, EventStatus.completed),
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

// ─── EventLifecycleBreadcrumb (Lifecycle B — scrollable pills + progress bar) ───

/// Compact lifecycle breadcrumb: thin progress bar + horizontal scrollable step pills.
/// Designed to sit inside the floating title card on the event detail screen.
class EventLifecycleBreadcrumb extends StatelessWidget {
  final Event event;

  const EventLifecycleBreadcrumb({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final steps = _stepsForEvent(event);
    final activeIndex = _activeIndexForEvent(event, steps);

    if (activeIndex == -1) return const SizedBox.shrink();

    final currentStep = steps[activeIndex];
    final progress = (activeIndex + 1) / steps.length;
    final activeColor = _stepActiveColor(context, currentStep);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thin progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: AppTheme.dividerOf(context),
            valueColor: AlwaysStoppedAnimation<Color>(activeColor),
          ),
        ),
        const SizedBox(height: 10),
        // Scrollable step pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(steps.length, (i) {
              final step = steps[i];
              final isActive = i <= activeIndex;
              final isCurrent = i == activeIndex;
              return _BreadcrumbPill(
                step: step,
                isActive: isActive,
                isCurrent: isCurrent,
                activeColor: activeColor,
                isLast: i == steps.length - 1,
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _BreadcrumbPill extends StatelessWidget {
  final _Step step;
  final bool isActive;
  final bool isCurrent;
  final Color activeColor;
  final bool isLast;

  const _BreadcrumbPill({
    required this.step,
    required this.isActive,
    required this.isCurrent,
    required this.activeColor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isCurrent
        ? activeColor
        : isActive
            // past: very subtle fill (matches combined_design.html rgba(0,0,0,.05))
            ? (isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05))
            : Colors.transparent; // future: no background
    final Color fg = isCurrent
        ? Colors.white
        : isActive
            ? (isDark
                ? AppTheme.textSecondaryOf(context)
                : const Color(0xFF5C5C5C))
            : AppTheme.textSecondaryOf(context).withValues(alpha: 0.55);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCurrent ? step.icon : (isActive ? Icons.check : step.icon),
                size: 12,
                color: fg,
              ),
              const SizedBox(width: 4),
              Text(
                step.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            size: 14,
            color: AppTheme.textSecondaryOf(context),
          ),
          const SizedBox(width: 4),
        ],
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
