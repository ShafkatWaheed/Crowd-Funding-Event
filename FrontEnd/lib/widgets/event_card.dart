import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/event.dart';
import 'event_lifecycle_bar.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;

  const EventCard({super.key, required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                gradient: _statusGradient(event.status),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EventLifecycleBar(event: event, compact: true),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(status: event.status),
                    ],
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date
                  _infoRow(
                    Icons.schedule_rounded,
                    event.startTime != null
                        ? DateFormat('EEE, MMM d, y \u2022 h:mm a')
                            .format(event.startTime!)
                        : 'Event date: TBD',
                  ),
                  const SizedBox(height: 6),

                  // Venue
                  if (event.venue != null)
                    _infoRow(
                      Icons.location_on_rounded,
                      '${event.venue!.name}, ${event.venue!.city}',
                    ),

                  // Genre
                  if (event.genre != null && event.genre!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _infoRow(
                      Icons.label_rounded,
                      event.genre![0].toUpperCase() + event.genre!.substring(1),
                      color: AppTheme.accentColor,
                    ),
                  ],

                  // Stats row
                  if (event.registrationCount > 0 || event.likeCount > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (event.registrationCount > 0)
                          _stat(Icons.group_rounded,
                              '${event.registrationCount} going'),
                        if (event.likeCount > 0)
                          _stat(Icons.favorite_rounded,
                              '${event.likeCount}'),
                      ],
                    ),
                  ],

                  // Funding
                  if (event.fundingGoalCents != null &&
                      event.fundingGoalCents! > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${event.totalPledgedFormatted} raised',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.successColor,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Goal: ${event.fundingGoalFormatted}',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: event.fundingProgress.clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: AppTheme.dividerColor,
                        valueColor: AlwaysStoppedAnimation(
                          event.fundingProgress >= 1.0
                              ? AppTheme.successColor
                              : AppTheme.accentColor,
                        ),
                      ),
                    ),
                    if (event.fundingDaysLeft != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${event.fundingDaysLeft} days left',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                color: color ?? AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _stat(IconData icon, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  LinearGradient _statusGradient(EventStatus status) {
    return switch (status) {
      EventStatus.live => const LinearGradient(
          colors: [Color(0xFF05944F), Color(0xFF0A7544)]),
      EventStatus.selling_tickets => const LinearGradient(
          colors: [Color(0xFF00838F), Color(0xFF00695C)]),
      EventStatus.waiting_event_date => const LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFBF360C)]),
      EventStatus.completed => const LinearGradient(
          colors: [Color(0xFF424242), Color(0xFF212121)]),
      EventStatus.cancelled => const LinearGradient(
          colors: [Color(0xFF8B0000), Color(0xFF5D0000)]),
      EventStatus.draft => const LinearGradient(
          colors: [Color(0xFF757575), Color(0xFF545454)]),
      EventStatus.pending_approval => const LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFBF360C)]),
      _ => const LinearGradient(
          colors: [Color(0xFF141414), Color(0xFF2C2C2C)]),
    };
  }
}

class _StatusBadge extends StatelessWidget {
  final EventStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      EventStatus.draft => 'Draft',
      EventStatus.pending_approval => 'Pending',
      EventStatus.approved => 'Open',
      EventStatus.live => 'LIVE',
      EventStatus.selling_tickets => 'Tickets',
      EventStatus.waiting_event_date => 'Awaiting',
      EventStatus.completed => 'Done',
      EventStatus.cancelled => 'Cancelled',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
