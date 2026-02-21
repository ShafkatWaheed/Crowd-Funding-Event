import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../config/design_tokens.dart';
import '../models/event.dart';
import 'event_lifecycle_bar.dart';

class EventCard extends StatefulWidget {
  final Event event;
  final VoidCallback? onTap;
  final bool isBookmarked;
  final VoidCallback? onBookmarkToggle;
  final String? imageUrl;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.isBookmarked = false,
    this.onBookmarkToggle,
    this.imageUrl,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  int get _attendeeCount =>
      widget.event.totalReservedSpots + widget.event.ticketsSoldCount;

  bool get _isFull =>
      widget.event.maxCapacity > 0 && _attendeeCount >= widget.event.maxCapacity;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final event = widget.event;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: AppDuration.fast,
        curve: AppCurve.standard,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          decoration: BoxDecoration(
            color: AppTheme.cardOf(context),
            borderRadius: AppRadius.lg,
            boxShadow: _pressed
                ? AppShadow.soft(isDark)
                : AppShadow.card(isDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, event, isDark),
              _buildBody(context, event),
              if (event.maxCapacity > 0)
                _buildCapacityBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Event event, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, 14, AppSpacing.lg, AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: _statusGradient(event.status),
        borderRadius: AppRadius.topLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EventLifecycleBar(event: event, compact: true),
          AppSpacing.vSm,
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
              AppSpacing.hSm,
              _FrostedStatusBadge(status: event.status),
              if (widget.onBookmarkToggle != null) ...[
                const SizedBox(width: 6),
                _BookmarkButton(
                  isBookmarked: widget.isBookmarked,
                  onTap: widget.onBookmarkToggle!,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, Event event) {
    return Padding(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            icon: Icons.schedule_rounded,
            text: event.startTime != null
                ? DateFormat('EEE, MMM d, y \u2022 h:mm a')
                    .format(event.startTime!)
                : 'Event date: TBD',
          ),
          const SizedBox(height: 6),

          if (event.venue != null)
            _InfoRow(
              icon: Icons.location_on_rounded,
              text: '${event.venue!.name}, ${event.venue!.city}',
            ),

          if (event.genre != null && event.genre!.isNotEmpty) ...[
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.label_rounded,
              text: event.genre![0].toUpperCase() + event.genre!.substring(1),
              color: AppTheme.accentColor,
            ),
          ],

          if (_attendeeCount > 0 || event.likeCount > 0) ...[
            AppSpacing.vMd,
            Row(
              children: [
                if (_attendeeCount > 0)
                  _StatChip(
                    icon: Icons.group_rounded,
                    value: event.maxCapacity > 0
                        ? '$_attendeeCount / ${event.maxCapacity}'
                        : '$_attendeeCount going',
                  ),
                if (event.likeCount > 0)
                  _StatChip(
                    icon: Icons.favorite_rounded,
                    value: '${event.likeCount}',
                  ),
              ],
            ),
          ],

          if (event.fundingGoalCents != null &&
              event.fundingGoalCents! > 0) ...[
            AppSpacing.vMd,
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
                    color: AppTheme.textSecondaryOf(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: AppRadius.sm,
              child: LinearProgressIndicator(
                value: event.fundingProgress.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: AppTheme.dividerOf(context),
                valueColor: AlwaysStoppedAnimation(
                  event.fundingProgress >= 1.0
                      ? AppTheme.successColor
                      : AppTheme.accentColor,
                ),
              ),
            ),
            if (event.fundingEndAt != null) ...[
              AppSpacing.vXs,
              Text(
                event.fundingTimeLeftFormatted,
                style: TextStyle(
                  color: event.fundingHasTimeLeft
                      ? AppTheme.textSecondaryOf(context)
                      : AppTheme.errorColor,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCapacityBar(BuildContext context) {
    final progress = (_attendeeCount / widget.event.maxCapacity).clamp(0.0, 1.0);
    final color = _isFull ? AppTheme.errorColor : AppTheme.accentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: AppTheme.dividerOf(context),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: color,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.md,
          ),
          child: Text(
            _isFull
                ? 'FULL'
                : '${widget.event.maxCapacity - _attendeeCount} spots left',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _isFull ? AppTheme.errorColor : AppTheme.textSecondaryOf(context),
            ),
          ),
        ),
      ],
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

// ─── Frosted glass status badge ───

class _FrostedStatusBadge extends StatelessWidget {
  final EventStatus status;
  const _FrostedStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      EventStatus.draft => 'Draft',
      EventStatus.pending_approval => 'Under Review',
      EventStatus.approved => 'Funding',
      EventStatus.live => 'LIVE',
      EventStatus.selling_tickets => 'Tickets',
      EventStatus.waiting_event_date => 'Awaiting',
      EventStatus.completed => 'Completed',
      EventStatus.cancelled => 'Cancelled',
    };

    return ClipRRect(
      borderRadius: AppRadius.pill,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: AppRadius.pill,
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
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
        ),
      ),
    );
  }
}

// ─── Animated bookmark button ───

class _BookmarkButton extends StatefulWidget {
  final bool isBookmarked;
  final VoidCallback onTap;
  const _BookmarkButton({required this.isBookmarked, required this.onTap});

  @override
  State<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<_BookmarkButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDuration.normal,
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: AppCurve.overshoot));
  }

  @override
  void didUpdateWidget(covariant _BookmarkButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isBookmarked != widget.isBookmarked) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Icon(
          widget.isBookmarked
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          color: Colors.white.withValues(alpha: 0.9),
          size: AppIconSize.lg,
        ),
      ),
    );
  }
}

// ─── Info row ───

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _InfoRow({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final fallback = AppTheme.textSecondaryOf(context);
    return Row(
      children: [
        Icon(icon, size: AppIconSize.sm, color: color ?? fallback),
        AppSpacing.hSm,
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color ?? fallback,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Stat chip ───

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  const _StatChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: AppRadius.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondaryOf(context)),
          AppSpacing.hXs,
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}
