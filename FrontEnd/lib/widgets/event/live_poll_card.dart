import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../models/poll.dart';
import '../../providers/poll_provider.dart';
import '../app_toast.dart';

/// Inline card shown on the event detail screen when a live poll is active.
/// Handles all three states: not voted, voted (results), and closed.
class LivePollCard extends StatelessWidget {
  final EventPoll poll;
  final int eventId;

  const LivePollCard({super.key, required this.poll, required this.eventId});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(AppRadius.lgValue),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.25),
        ),
        boxShadow: AppShadow.soft(AppTheme.isDark(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(poll: poll),
            const SizedBox(height: AppSpacing.md),
            Text(
              poll.question,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (poll.viewerVoteIndex != null || poll.isClosed)
              _ResultsView(poll: poll)
            else
              _VoteView(poll: poll, eventId: eventId),
            if (!poll.isClosed && poll.viewerVoteIndex != null &&
                !poll.showResultsWhileOpen) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Results will be revealed when the poll closes.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final EventPoll poll;
  const _Header({required this.poll});

  @override
  Widget build(BuildContext context) {
    final label = poll.isClosed ? 'Poll Closed' : 'Live Poll';
    final color =
        poll.isClosed ? AppTheme.textSecondaryOf(context) : AppTheme.accentColor;

    return Row(
      children: [
        Icon(
          poll.isClosed ? Icons.poll_rounded : Icons.how_to_vote_rounded,
          size: 18,
          color: color,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
        if (!poll.isClosed) ...[
          const SizedBox(width: AppSpacing.xs),
          _LiveDot(),
        ],
        const Spacer(),
        Text(
          '${poll.totalVotes} vote${poll.totalVotes == 1 ? '' : 's'}',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryOf(context),
          ),
        ),
      ],
    );
  }
}

/// Animated live indicator dot.
class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
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
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Tappable option list — shown when user hasn't voted yet.
class _VoteView extends StatefulWidget {
  final EventPoll poll;
  final int eventId;
  const _VoteView({required this.poll, required this.eventId});

  @override
  State<_VoteView> createState() => _VoteViewState();
}

class _VoteViewState extends State<_VoteView> {
  bool _submitting = false;

  Future<void> _vote(int optionIndex) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await context
          .read<PollProvider>()
          .vote(widget.eventId, widget.poll.id, optionIndex);
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(widget.poll.options.length, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: InkWell(
            onTap: _submitting ? null : () => _vote(i),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.dividerOf(context)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.poll.options[i],
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  if (_submitting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Progress bar results view — shown after voting or when poll is closed.
class _ResultsView extends StatelessWidget {
  final EventPoll poll;
  const _ResultsView({required this.poll});

  @override
  Widget build(BuildContext context) {
    final results = poll.results;
    if (results == null) {
      // Voted but results hidden until close
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          'Your vote has been recorded.',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondaryOf(context),
          ),
        ),
      );
    }

    return Column(
      children: results.map((r) {
        final isSelected = poll.viewerVoteIndex == r.index;
        final isWinner = poll.isClosed &&
            poll.totalVotes > 0 &&
            results.every((other) => r.voteCount >= other.voteCount);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _OptionBar(
            result: r,
            isSelected: isSelected,
            isWinner: isWinner,
          ),
        );
      }).toList(),
    );
  }
}

class _OptionBar extends StatelessWidget {
  final PollOptionResult result;
  final bool isSelected;
  final bool isWinner;

  const _OptionBar({
    required this.result,
    this.isSelected = false,
    this.isWinner = false,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = isWinner
        ? AppTheme.secondaryColor
        : isSelected
            ? AppTheme.accentColor
            : AppTheme.accentColor.withValues(alpha: 0.45);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected || isWinner
              ? barColor.withValues(alpha: 0.5)
              : AppTheme.dividerOf(context),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isSelected)
                Icon(Icons.check_circle_rounded,
                    size: 14, color: AppTheme.accentColor),
              if (isWinner && !isSelected)
                Icon(Icons.emoji_events_rounded,
                    size: 14, color: AppTheme.secondaryColor),
              if (isSelected || isWinner) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  result.text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected || isWinner
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
              Text(
                '${result.percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: result.percentage / 100,
              backgroundColor: AppTheme.dividerOf(context),
              color: barColor,
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}
