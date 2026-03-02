import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event.dart';
import '../../../models/milestone.dart';
import '../../../providers/auth_provider.dart';
import '../../../repositories/event_repository.dart';
import '../../../repositories/ticket_repository.dart';
import '../../../widgets/app_toast.dart';

class MilestoneTimeline extends StatefulWidget {
  final int eventId;
  final Event event;

  const MilestoneTimeline({super.key, required this.eventId, required this.event});

  @override
  State<MilestoneTimeline> createState() => _MilestoneTimelineState();
}

class _MilestoneTimelineState extends State<MilestoneTimeline> {
  List<FundingMilestone> _milestones = [];
  Map<int, String?> _myReactions = {};
  Map<int, int> _milestoneDiscounts = {}; // unlock_percent -> discount_value
  bool _loading = true;
  bool _featureEnabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<EventRepository>();
      final ticketRepo = context.read<TicketRepository>();
      final auth = context.read<AuthProvider>();
      if (auth.user != null && auth.user!.isAdmin) {
        try {
          final flags = await repo.getFeatureFlags();
          if (flags['feature_milestones_enabled'] == false) {
            if (mounted) setState(() { _featureEnabled = false; _loading = false; });
            return;
          }
        } catch (e) { debugPrint(e.toString()); }
      }

      final list = await repo.getMilestones(widget.eventId);
      final milestones =
          list.map((j) => FundingMilestone.fromJson(j)).toList();

      final reactions = <int, String?>{};
      if (auth.user != null) {
        for (final ms in milestones) {
          try {
            final r = await repo.getMyMilestoneReaction(widget.eventId, ms.id);
            reactions[ms.id] = r['reaction'];
          } catch (e) { debugPrint(e.toString()); }
        }
      }

      final discMap = <int, int>{};
      if (auth.user != null && (auth.user!.isOrganizer || auth.user!.isAdmin)) {
        try {
          final discounts = await ticketRepo.getEventDiscounts(widget.eventId);
          for (final d in discounts) {
            if (d['discount_type'] == 'funding_milestone' && d['milestone_percent'] != null) {
              discMap[d['milestone_percent'] as int] = d['milestone_discount_value'] ?? d['value'] ?? 0;
            }
          }
        } catch (e) { debugPrint(e.toString()); }
      }

      if (mounted) {
        setState(() {
          _milestones = milestones;
          _myReactions = reactions;
          _milestoneDiscounts = discMap;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _react(int milestoneId, String reaction) async {
    try {
      final repo = context.read<EventRepository>();
      final resp =
          await repo.reactToMilestone(widget.eventId, milestoneId, reaction);
      if (mounted) {
        setState(() {
          final action = resp['action'];
          _myReactions[milestoneId] = action == 'removed' ? null : reaction;
          final idx = _milestones.indexWhere((m) => m.id == milestoneId);
          if (idx != -1) {
            final old = _milestones[idx];
            _milestones[idx] = FundingMilestone(
              id: old.id,
              eventId: old.eventId,
              title: old.title,
              description: old.description,
              unlockPercent: old.unlockPercent,
              benefitDescription: old.benefitDescription,
              sortOrder: old.sortOrder,
              likeCount: resp['like_count'] ?? old.likeCount,
              dislikeCount: resp['dislike_count'] ?? old.dislikeCount,
              isUnlocked: old.isUnlocked,
              createdAt: old.createdAt,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) AppToast.fromError(context, e, fallback: 'Reaction failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_featureEnabled) return const SizedBox.shrink();
    if (_loading) {
      return Container(
        padding: AppSpacing.paddingXl,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_milestones.isEmpty) return const SizedBox.shrink();

    final goalCents = widget.event.fundingGoalCents ?? 0;
    final totalPledged = widget.event.totalPledgedCents ?? 0;
    final fundingPercent =
        goalCents > 0 ? (totalPledged / goalCents * 100).clamp(0.0, 100.0) : 0.0;

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.emoji_events_rounded,
                  size: AppIconSize.sm, color: context.photoAccent),
              AppSpacing.hSm,
              Text(
                'Funding Milestones',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondaryOf(context),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          AppSpacing.vLg,

          // Horizontal progress rail
          _buildProgressRail(fundingPercent),

          AppSpacing.vXl,

          // 2-column milestone grid
          _buildMilestoneGrid(),
        ],
      ),
    );
  }

  Widget _buildProgressRail(double fundingPercent) {
    return Column(
      children: [
        // Progress bar with milestone dots
        LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            return Column(
              children: [
                SizedBox(
                  height: 32,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Background bar
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 12,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.dividerOf(context),
                            borderRadius: AppRadius.pill,
                          ),
                        ),
                      ),
                      // Filled bar
                      Positioned(
                        left: 0,
                        top: 12,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: fundingPercent / 100),
                          duration: const Duration(milliseconds: 800),
                          curve: AppCurve.enter,
                          builder: (context, value, _) => Container(
                            width: barWidth * value,
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.accentColor,
                                  context.photoAccent,
                                ],
                              ),
                              borderRadius: AppRadius.pill,
                            ),
                          ),
                        ),
                      ),
                      // Milestone dots
                      ..._milestones.map((ms) {
                        final pos = (ms.unlockPercent / 100) * barWidth;
                        final isUnlocked = ms.isUnlocked;
                        return Positioned(
                          left: pos - 7,
                          top: 9,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isUnlocked
                                  ? AppTheme.accentColor
                                  : AppTheme.dividerOf(context),
                              border: Border.all(
                                color: isUnlocked
                                    ? AppTheme.accentColor
                                    : AppTheme.textSecondaryOf(context).withValues(alpha: 0.5),
                                width: 2,
                              ),
                              boxShadow: isUnlocked
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.accentColor.withValues(alpha: 0.4),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                AppSpacing.vSm,
                // Percentage labels under dots
                SizedBox(
                  height: 16,
                  child: Stack(
                    children: _milestones.map((ms) {
                      final pos = (ms.unlockPercent / 100) * barWidth;
                      return Positioned(
                        left: pos - 14,
                        child: SizedBox(
                          width: 28,
                          child: Text(
                            '${ms.unlockPercent}%',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: ms.isUnlocked
                                  ? AppTheme.accentColor
                                  : AppTheme.textSecondaryOf(context),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
        AppSpacing.vSm,
        // "Currently at X% funded"
        Center(
          child: Text(
            'Currently at ${fundingPercent.toStringAsFixed(0)}% funded',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: _milestones.asMap().entries.map((entry) {
            final idx = entry.key;
            final ms = entry.value;
            return SizedBox(
              width: cardWidth,
              child: _buildMilestoneCard(ms, idx),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildMilestoneCard(FundingMilestone ms, int index) {
    final isUnlocked = ms.isUnlocked;
    final myReaction = _myReactions[ms.id];

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: isUnlocked
            ? AppTheme.accentColor.withValues(alpha: 0.06)
            : AppTheme.surfaceOf(context),
        borderRadius: AppRadius.md,
        border: Border.all(
          color: isUnlocked
              ? AppTheme.accentColor.withValues(alpha: 0.3)
              : AppTheme.dividerOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Percentage + status badge
          Row(
            children: [
              Text(
                '${ms.unlockPercent}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isUnlocked
                      ? AppTheme.accentColor
                      : AppTheme.textSecondaryOf(context),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? AppTheme.successSurfaceOf(context)
                      : AppTheme.textSecondaryOf(context).withValues(alpha: 0.12),
                  borderRadius: AppRadius.sm,
                ),
                child: Text(
                  isUnlocked ? 'UNLOCKED' : 'LOCKED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isUnlocked
                        ? AppTheme.successColor
                        : AppTheme.textSecondaryOf(context),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vSm,

          // Title
          Text(
            ms.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // Benefit description
          if (ms.benefitDescription != null &&
              ms.benefitDescription!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              ms.benefitDescription!,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryOf(context),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Discount badge
          if (_milestoneDiscounts.containsKey(ms.unlockPercent)) ...[
            AppSpacing.vSm,
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: context.fundingAccent.withValues(alpha: 0.12),
                borderRadius: AppRadius.sm,
              ),
              child: Text(
                '${_milestoneDiscounts[ms.unlockPercent]}% OFF',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: context.fundingAccent,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],

          AppSpacing.vSm,

          // Like/dislike row
          Row(
            children: [
              _milestoneReactionBtn(
                icon: myReaction == 'like'
                    ? Icons.thumb_up
                    : Icons.thumb_up_outlined,
                count: ms.likeCount,
                isActive: myReaction == 'like',
                activeColor: AppTheme.accentColor,
                onTap: () => _react(ms.id, 'like'),
              ),
              AppSpacing.hSm,
              _milestoneReactionBtn(
                icon: myReaction == 'dislike'
                    ? Icons.thumb_down
                    : Icons.thumb_down_outlined,
                count: ms.dislikeCount,
                isActive: myReaction == 'dislike',
                activeColor: AppTheme.errorColor,
                onTap: () => _react(ms.id, 'dislike'),
              ),
            ],
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: 80 * index))
        .fadeIn(duration: AppDuration.normal, curve: AppCurve.enter)
        .slideY(begin: 0.1, end: 0, duration: AppDuration.normal, curve: AppCurve.enter);
  }

  Widget _milestoneReactionBtn({
    required IconData icon,
    required int count,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isActive
          ? activeColor.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: AppRadius.lg,
      child: InkWell(
        borderRadius: AppRadius.lg,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14,
                  color: isActive ? activeColor : AppTheme.textSecondaryOf(context)),
              const SizedBox(width: 3),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive ? activeColor : AppTheme.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
