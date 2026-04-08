import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../config/app_icons.dart';
import '../../config/app_typography.dart';
import '../../config/theme.dart';
import '../../config/design_tokens.dart';
import '../../models/event.dart';
import '../../utils/date_time_utils.dart';
import 'event_lifecycle_bar.dart';

class EventCard extends StatefulWidget {
  final Event event;
  final VoidCallback? onTap;
  final bool isBookmarked;
  final VoidCallback? onBookmarkToggle;
  final String? imageUrl;
  final bool isOrganizerOrAdmin;
  final int? myPledgeAmountCents;
  final int? myTicketCount;
  final bool showSponsorBadge;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.isBookmarked = false,
    this.onBookmarkToggle,
    this.imageUrl,
    this.isOrganizerOrAdmin = true,
    this.myPledgeAmountCents,
    this.myTicketCount,
    this.showSponsorBadge = false,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  int get _attendeeCount =>
      widget.event.totalReservedSpots + widget.event.ticketsSoldCount;

  bool get _showTicketStats =>
      widget.event.status == EventStatus.selling_tickets ||
      widget.event.status == EventStatus.live ||
      widget.event.status == EventStatus.completed ||
      widget.event.status == EventStatus.under_review;

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
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context, event, isDark),
              _buildBody(context, event, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Event event, bool isDark) {
    final url = widget.imageUrl;
    final hasImage = url != null && url.isNotEmpty;

    return SizedBox(
      height: 130,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: hasImage
                ? CachedNetworkImage(
                    imageUrl: ApiConfig.imageUrl(url),
                    fit: BoxFit.cover,
                    memCacheHeight: 260,
                    errorWidget: (_, __, ___) => Container(
                      decoration: BoxDecoration(gradient: _statusGradient(event.status)),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: _statusGradient(event.status),
                      borderRadius: AppRadius.topLg,
                    ),
                  ),
          ),
          // Lifecycle bar pinned to top of header
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: EventLifecycleBar(event: event, compact: true),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.72)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((widget.myPledgeAmountCents ?? 0) > 0 ||
                      (widget.myTicketCount ?? 0) > 0 ||
                      widget.showSponsorBadge) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: AppRadius.pill,
                        border: Border.all(
                            color: AppTheme.successColor.withValues(alpha: 0.3),
                            width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 9, color: AppTheme.successColor),
                          const SizedBox(width: 3),
                          Text(
                            'Activity',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  AppSpacing.vSm,
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            _FrostedStatusBadge(status: event.status, hasFunding: event.isFunding),
                            if (event.isPrivate)
                              Icon(Icons.lock_outline, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                          ],
                        ),
                      ),
                      if (widget.onBookmarkToggle != null)
                        _BookmarkButton(
                          isBookmarked: widget.isBookmarked,
                          onTap: widget.onBookmarkToggle!,
                        ),
                    ],
                  ),
                  AppSpacing.vXs,
                  Text(
                    event.title,
                    style: AppTypography.titleLarge.copyWith(
                      color: Colors.white,
                      letterSpacing: -0.3,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, Event event, bool isDark) {
    final hasFunding = (event.fundingGoalCents ?? 0) > 0 &&
        event.fundingEndAt != null &&
        (event.status == EventStatus.approved ||
         event.status == EventStatus.under_review);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            icon: AppIcons.cardTime.icon,
            text: event.startTime != null
                ? AppDateFormat.eventCard(event.startTime!)
                : 'Event date: TBD',
          ),
          if (event.venue != null) ...[
            Divider(height: 1, thickness: 0.5, color: AppTheme.dividerOf(context).withValues(alpha: 0.6)),
            _InfoRow(
              icon: AppIcons.cardLocation.icon,
              text: '${event.venue!.name}, ${event.venue!.city}',
              color: AppIcons.cardLocation.color(isDark),
            ),
          ],
          AppSpacing.vSm,
          Row(
            children: [
              _StatChip(
                icon: AppIcons.cardLikes.icon,
                value: '${event.likeCount}',
                color: AppIcons.cardLikes.color(isDark),
              ),
              if (widget.isOrganizerOrAdmin) ...[
                if (_attendeeCount > 0)
                  Flexible(
                    child: _StatChip(
                      icon: AppIcons.cardAttendees.icon,
                      value: event.maxCapacity > 0
                          ? '$_attendeeCount / ${event.maxCapacity}'
                          : '$_attendeeCount going',
                      color: AppIcons.cardAttendees.color(isDark),
                    ),
                  ),
              ] else if (_showTicketStats) ...[
                if (event.totalTierCapacity > 0)
                  Flexible(
                    child: _StatChip(
                      icon: AppIcons.cardTickets.icon,
                      value: event.ticketsSoldCount >= event.totalTierCapacity
                          ? 'Sold Out'
                          : '${event.ticketsSoldCount}/${event.totalTierCapacity}',
                      color: event.ticketsSoldCount >= event.totalTierCapacity
                          ? AppTheme.errorColor
                          : AppIcons.cardTickets.color(isDark),
                    ),
                  )
                else if (event.ticketsSoldCount > 0)
                  Flexible(
                    child: _StatChip(
                      icon: AppIcons.cardTickets.icon,
                      value: '${event.ticketsSoldCount}',
                      color: AppIcons.cardTickets.color(isDark),
                    ),
                  ),
              ],
            ],
          ),
          if (hasFunding) ...[
            AppSpacing.vSm,
            _FundingBarA(event: event, isDark: isDark),
          ],
        ],
      ),
    );
  }

  LinearGradient _statusGradient(EventStatus _) {
    return AppTheme.darkGradient;
  }
}

// ─── Activity hero chip ───

// ─── Colored status badge with icon ───

class _FrostedStatusBadge extends StatelessWidget {
  final EventStatus status;
  final bool hasFunding;
  const _FrostedStatusBadge({required this.status, this.hasFunding = false});

  @override
  Widget build(BuildContext context) {
    final label = status == EventStatus.approved
        ? (hasFunding ? 'Funding' : 'Tickets')
        : status == EventStatus.live
            ? 'LIVE'
            : AppIcons.forEventStatus(status).displayName;

    final meta = AppIcons.forEventStatus(status);
    // Always on a dark hero — use the dark variant for legibility
    final color = meta.color(true);
    final icon = hasFunding && status == EventStatus.approved
        ? Icons.volunteer_activism_rounded
        : meta.icon;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.50),
        borderRadius: AppRadius.pill,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == EventStatus.live)
            const _LivePulseDot()
          else
            Icon(icon, size: 11, color: color),
          AppSpacing.hXs,
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Live pulse dot ───

class _LivePulseDot extends StatefulWidget {
  const _LivePulseDot();

  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _anim = Tween(begin: 1.0, end: 0.3)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.successColor,
          boxShadow: [
            BoxShadow(
              color: AppTheme.successColor.withValues(alpha: 0.6),
              blurRadius: 5,
            ),
          ],
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
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
    final c = color ?? fallback;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: AppRadius.sm,
            ),
            child: Icon(icon, size: 14, color: c),
          ),
          AppSpacing.hSm,
          Expanded(
            child: Text(
              text,
              style: AppTypography.caption.copyWith(
                color: AppTheme.textPrimaryOf(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Funding bar (Option A: gradient bar + glow) ───

class _FundingBarA extends StatelessWidget {
  final Event event;
  final bool isDark;
  const _FundingBarA({required this.event, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final pct = (event.fundingProgress * 100).clamp(0, 999).toStringAsFixed(0);
    final isFunded = event.fundingProgress >= 1.0;
    final barColor = isFunded ? AppTheme.successColor : AppTheme.orangeColor;
    final progress = event.fundingProgress.clamp(0.0, 1.0);
    final timeLabel = event.fundingEndAt != null
        ? (event.fundingHasTimeLeft ? event.fundingTimeLeftFormatted : 'Ended')
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.dividerOf(context),
                borderRadius: AppRadius.sm,
              ),
            ),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.sm,
                  gradient: LinearGradient(
                    colors: isFunded
                        ? [AppTheme.successColor, AppTheme.tealColor]
                        : [AppTheme.orangeColor, AppTheme.warningColor],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: barColor.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '$pct% raised',
              style: AppTypography.labelSmall.copyWith(
                color: isFunded ? AppTheme.successColor : AppTheme.orangeColor,
              ),
            ),
            if (timeLabel != null) ...[
              const Spacer(),
              Icon(Icons.timer_rounded, size: 11,
                  color: AppTheme.textSecondaryOf(context)),
              AppSpacing.hXs,
              Text(
                timeLabel,
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ─── Stat chip ───

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color? color;
  const _StatChip({required this.icon, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: AppRadius.sm,
        border: Border.all(
          color: AppTheme.dividerOf(context),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppTheme.textSecondaryOf(context)),
          AppSpacing.hXs,
          Flexible(
            child: Text(
              value,
              style: AppTypography.labelMedium.copyWith(
                letterSpacing: 0,
                color: color ?? AppTheme.textPrimaryOf(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
