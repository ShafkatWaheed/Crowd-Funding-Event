import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event.dart';
import '../../../models/milestone.dart';
import '../../../providers/pledge_provider.dart';
import '../../../providers/event_provider.dart';
import 'funding_card_helpers.dart';

/// Shown during selling_tickets / live / completed phases.
/// Displays a frozen snapshot of the funding results + milestone history.
class FundingResultsCard extends StatefulWidget {
  final int eventId;
  final Event event;

  const FundingResultsCard({super.key, required this.eventId, required this.event});

  @override
  State<FundingResultsCard> createState() => _FundingResultsCardState();
}

class _FundingResultsCardState extends State<FundingResultsCard> {
  int _totalPledgedCents = 0;
  int _backersCount = 0;
  int? _goalCents;
  int _fundingCommissionPercent = 0;
  List<FundingMilestone> _milestones = [];
  bool _loading = true;

  Event get event => widget.event;

  @override
  void initState() {
    super.initState();
    _totalPledgedCents = event.totalPledgedCents ?? 0;
    _goalCents = event.fundingGoalCents;
    _load();
  }

  Future<void> _load() async {
    try {
      final pledgeProvider = context.read<PledgeProvider>();
      final eventProvider = context.read<EventProvider>();
      final results = await Future.wait([
        pledgeProvider.getFundingSummary(widget.eventId),
        eventProvider.getMilestones(widget.eventId),
      ]);
      if (mounted) {
        final summary = results[0] as dynamic; // FundingSummary
        final milestones = results[1] as List<FundingMilestone>;
        setState(() {
          _totalPledgedCents = summary.totalPledgedCents as int;
          _backersCount = summary.backersCount as int;
          _goalCents = (summary.goalCents as int) > 0 ? summary.goalCents as int : _goalCents;
          _fundingCommissionPercent = summary.fundingCommissionPercent as int;
          _milestones = milestones;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _progress {
    if (_goalCents == null || _goalCents == 0) return 0;
    return (_totalPledgedCents / _goalCents!).clamp(0.0, 2.0);
  }

  String get _avgPledge {
    if (_backersCount == 0) return '\$—';
    return '\$${(_totalPledgedCents / _backersCount / 100).toStringAsFixed(0)}';
  }

  String get _closedDate {
    if (event.fundingEndAt == null) return '—';
    final d = event.fundingEndAt!;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final progress = _progress;
    final progressPct = (progress * 100).clamp(0, 999);
    final isFunded = _goalCents != null && _totalPledgedCents >= _goalCents!;

    final accentColor = const Color(0xFF10B981);
    final bgColor = isDark ? const Color(0xFF0A1410) : const Color(0xFFF0FDF4);
    final cardBorder = isDark
        ? const Color(0xFF10B981).withValues(alpha: 0.2)
        : const Color(0xFF10B981).withValues(alpha: 0.25);

    final sorted = List<FundingMilestone>.from(_milestones)
      ..sort((a, b) => a.unlockPercent.compareTo(b.unlockPercent));

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.lg,
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.18 : 0.1),
            blurRadius: 28,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // ambient glow
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.07),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  children: [
                    Icon(Icons.monetization_on_outlined,
                        size: 14, color: accentColor.withValues(alpha: 0.8)),
                    const SizedBox(width: 6),
                    Text(
                      'FUNDING RESULTS',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                        color: accentColor.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(),
                    // Funded / Partial badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFunded
                            ? accentColor.withValues(alpha: 0.12)
                            : AppTheme.textSecondaryOf(context).withValues(alpha: 0.08),
                        border: Border.all(
                          color: isFunded
                              ? accentColor.withValues(alpha: 0.28)
                              : AppTheme.textSecondaryOf(context).withValues(alpha: 0.15),
                        ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (isFunded ? accentColor : AppTheme.textSecondaryOf(context))
                                  .withValues(alpha: 0.18),
                            ),
                            child: Icon(
                              isFunded ? Icons.check_rounded : Icons.remove_rounded,
                              size: 9,
                              color: isFunded
                                  ? const Color(0xFF34D399)
                                  : AppTheme.textSecondaryOf(context),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isFunded ? 'Funded' : 'Partial',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isFunded
                                  ? const Color(0xFF34D399)
                                  : AppTheme.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Amount ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: accentColor.withValues(alpha: 0.6),
                        height: 1.8,
                      ),
                    ),
                    Text(
                      (_totalPledgedCents / 100).toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                        height: 1,
                        color: isDark ? const Color(0xFFF0FDF4) : const Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'of \$${(_goalCents != null ? _goalCents! / 100 : 0).toStringAsFixed(0)} goal',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Frozen progress bar ──
                FundingShimmerBar(
                  progress: progress,
                  active: false, // frozen — no shimmer
                  fillColors: const [Color(0xFF065F46), Color(0xFF10B981), Color(0xFF34D399)],
                  trackColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                  glowColor: const Color(0xFF10B981),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${progressPct.toStringAsFixed(0)}% funded',
                      style: TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w700, color: accentColor),
                    ),
                    if (event.fundingEndAt != null)
                      Text(
                        'Closed $_closedDate',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.65),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Stats strip ──
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05)),
                      bottom: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05)),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                          child: FundingStatCell(
                        value: '$_backersCount',
                        label: 'Backers',
                        valueColor:
                            isDark ? const Color(0xFFE4E4F0) : const Color(0xFF1C1C1E),
                      )),
                      Container(
                          width: 0.5,
                          height: 32,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.08)),
                      Expanded(
                          child: FundingStatCell(
                        value: _avgPledge,
                        label: 'Avg pledge',
                        valueColor:
                            isDark ? const Color(0xFFE4E4F0) : const Color(0xFF1C1C1E),
                      )),
                      Container(
                          width: 0.5,
                          height: 32,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.08)),
                      Expanded(
                          child: FundingStatCell(
                        value: _fundingCommissionPercent > 0
                            ? '$_fundingCommissionPercent%'
                            : '—',
                        label: 'Fee',
                        valueColor:
                            isDark ? const Color(0xFFE4E4F0) : const Color(0xFF1C1C1E),
                      )),
                    ],
                  ),
                ),

                // ── Milestones ──
                if (sorted.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MILESTONES',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.09,
                          color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        '${sorted.where((m) => m.isUnlocked).length} of ${sorted.length} reached',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accentColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...sorted.map((ms) {
                    final goalAmt = _goalCents != null
                        ? '\$${(_goalCents! * ms.unlockPercent / 10000).toStringAsFixed(0)}'
                        : '${ms.unlockPercent}%';
                    final state = ms.isUnlocked ? FundingMsState.hit : FundingMsState.locked;
                    final subtitle = ms.isUnlocked
                        ? 'Reached · ${ms.unlockPercent}% goal'
                        : 'Not reached · ${ms.unlockPercent}% goal';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: FundingMilestoneRow(
                        title: ms.title,
                        subtitle: subtitle,
                        amount: goalAmt,
                        state: state,
                        isDark: isDark,
                      ),
                    );
                  }),
                ],

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
