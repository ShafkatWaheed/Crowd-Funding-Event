import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/event.dart';

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
    final steps = _buildSteps();
    final activeIndex = _activeStepIndex(steps);

    if (compact) {
      return _CompactBar(steps: steps, activeIndex: activeIndex);
    }
    return _FullBar(steps: steps, activeIndex: activeIndex);
  }

  List<_Step> _buildSteps() {
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

  int _activeStepIndex(List<_Step> steps) {
    final status = event.status;
    if (status == EventStatus.cancelled) return -1;
    if (status == EventStatus.draft ||
        status == EventStatus.pending_approval) {
      return -1;
    }
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
}

class _Step {
  final String label;
  final IconData icon;
  final EventStatus status;
  final bool isFundingActive;

  _Step(this.label, this.icon, this.status, {this.isFundingActive = false});
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

// ─── Full bar: segments + icons + labels (for detail) ───

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
    return switch (step.status) {
      EventStatus.approved => AppTheme.accentColor,
      EventStatus.selling_tickets => context.statusSelling,
      EventStatus.waiting_event_date => context.statusPending,
      EventStatus.live => AppTheme.successColor,
      EventStatus.completed => AppTheme.textSecondaryOf(context),
      _ => AppTheme.accentColor,
    };
  }
}
