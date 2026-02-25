import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event.dart';
import '../../../models/milestone.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/app_toast.dart';

class MilestoneTimeline extends StatefulWidget {
  final int eventId;
  final Event event;

  const MilestoneTimeline({required this.eventId, required this.event});

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
      final api = context.read<ApiService>();

      final auth = context.read<AuthProvider>();
      if (auth.user != null && auth.user!.isAdmin) {
        try {
          final flags = await api.getFeatureFlags();
          if (flags['feature_milestones_enabled'] == false) {
            if (mounted) setState(() { _featureEnabled = false; _loading = false; });
            return;
          }
        } catch (_) {}
      }

      final list = await api.getMilestones(widget.eventId);
      final milestones =
          list.map((j) => FundingMilestone.fromJson(j)).toList();

      final reactions = <int, String?>{};
      if (auth.user != null) {
        for (final ms in milestones) {
          try {
            final r = await api.getMyMilestoneReaction(widget.eventId, ms.id);
            reactions[ms.id] = r['reaction'];
          } catch (_) {}
        }
      }

      final discMap = <int, int>{};
      if (auth.user != null && (auth.user!.isOrganizer || auth.user!.isAdmin)) {
        try {
          final discounts = await api.getEventDiscounts(widget.eventId);
          for (final d in discounts) {
            if (d['discount_type'] == 'funding_milestone' && d['milestone_percent'] != null) {
              discMap[d['milestone_percent'] as int] = d['milestone_discount_value'] ?? d['value'] ?? 0;
            }
          }
        } catch (_) {}
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
      final api = context.read<ApiService>();
      final resp =
          await api.reactToMilestone(widget.eventId, milestoneId, reaction);
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

          // Timeline
          ..._milestones.asMap().entries.map((entry) {
            final idx = entry.key;
            final ms = entry.value;
            final isLast = idx == _milestones.length - 1;
            final isUnlocked = ms.isUnlocked;
            final myReaction = _myReactions[ms.id];

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vertical track + node
                  SizedBox(
                    width: 36,
                    child: Column(
                      children: [
                        // Node
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isUnlocked
                                ? AppTheme.accentColor
                                : AppTheme.dividerOf(context),
                            border: Border.all(
                              color: isUnlocked
                                  ? AppTheme.accentColor
                                  : AppTheme.textSecondaryOf(context),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: isUnlocked
                                ? Icon(Icons.check_rounded,
                                    size: AppIconSize.sm, color: Colors.white)
                                : Icon(Icons.lock_rounded,
                                    size: AppIconSize.sm, color: AppTheme.textSecondaryOf(context)),
                          ),
                        ),
                        // Connecting line
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: fundingPercent >= ms.unlockPercent
                                  ? AppTheme.accentColor
                                  : AppTheme.dividerOf(context),
                            ),
                          ),
                      ],
                    ),
                  ),

                  AppSpacing.hSm,

                  // Milestone card
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
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
                          // Percentage + badge row
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
                              if (_milestoneDiscounts.containsKey(ms.unlockPercent))
                                Container(
                                  margin: EdgeInsets.only(right: AppSpacing.xs),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                  decoration: BoxDecoration(
                                    color: context.fundingAccent.withValues(alpha: 0.12),
                                    borderRadius: AppRadius.sm,
                                  ),
                                  child: Text(
                                    '${_milestoneDiscounts[ms.unlockPercent]}% OFF',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: context.fundingAccent,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              Container(
                                padding: EdgeInsets.symmetric(
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
                                    fontSize: 10,
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
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                          ),

                          // Benefit description
                          if (ms.benefitDescription != null &&
                              ms.benefitDescription!.isNotEmpty) ...[
                            AppSpacing.vXs,
                            Text(
                              ms.benefitDescription!,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondaryOf(context),
                              ),
                            ),
                          ],

                          AppSpacing.vMd,

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
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: AppIconSize.sm,
                  color: isActive ? activeColor : AppTheme.textSecondaryOf(context)),
              AppSpacing.hXs,
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
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
