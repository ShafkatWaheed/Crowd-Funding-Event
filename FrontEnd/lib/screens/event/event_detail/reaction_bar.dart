import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/event_provider.dart';
import '../../../widgets/app_toast.dart';

class ReactionBar extends StatefulWidget {
  final int eventId;
  final int initialLikeCount;
  final int initialDislikeCount;
  final bool isAdmin;

  /// When true, renders compact heart/broken-heart icon buttons (no counts).
  final bool compact;

  const ReactionBar({
    super.key,
    required this.eventId,
    required this.initialLikeCount,
    required this.initialDislikeCount,
    required this.isAdmin,
    this.compact = false,
  });

  @override
  State<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<ReactionBar> {
  String? _myReaction;
  bool _reacting = false;
  late int _likeCount;
  late int _dislikeCount;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.initialLikeCount;
    _dislikeCount = widget.initialDislikeCount;
    _loadMyReaction();
  }

  Future<void> _loadMyReaction() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    try {
      final api = context.read<EventProvider>();
      final data = await api.getMyReaction(widget.eventId);
      if (mounted) setState(() => _myReaction = data.reaction);
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _react(String reaction) async {
    if (_reacting) return;
    setState(() => _reacting = true);
    try {
      final api = context.read<EventProvider>();
      final resp = await api.reactToEvent(widget.eventId, reaction);
      if (mounted) {
        setState(() {
          // Update reaction state based on action
          if (resp.action == 'removed') {
            _myReaction = null;
          } else {
            _myReaction = reaction;
          }
          // Update counts from server response
          _likeCount = resp.likeCount;
          _dislikeCount = resp.dislikeCount;
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Reaction failed');
      }
    }
    if (mounted) setState(() => _reacting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isAdmin) {
      // Admin: read-only counters (both like + dislike visible)
      return Row(
        children: [
          Icon(Icons.favorite_rounded, size: AppIconSize.sm, color: AppTheme.errorColor),
          AppSpacing.hSm,
          Text(
            '$_likeCount like${_likeCount == 1 ? '' : 's'}',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondaryOf(context)),
          ),
          AppSpacing.hXl,
          Icon(Icons.heart_broken_rounded, size: AppIconSize.sm, color: AppTheme.textSecondaryOf(context)),
          AppSpacing.hSm,
          Text(
            '$_dislikeCount dislike${_dislikeCount == 1 ? '' : 's'}',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondaryOf(context)),
          ),
        ],
      );
    }

    if (widget.compact) {
      // Compact: icon-only heart buttons for the title card corner
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconReactionButton(
            icon: _myReaction == 'like'
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            activeColor: AppTheme.errorColor,
            isActive: _myReaction == 'like',
            reacting: _reacting,
            onTap: () => _react('like'),
            context: context,
          ),
          const SizedBox(width: 2),
          _IconReactionButton(
            icon: Icons.heart_broken_rounded,
            activeColor: AppTheme.errorColor,
            isActive: _myReaction == 'dislike',
            reacting: _reacting,
            onTap: () => _react('dislike'),
            context: context,
          ),
        ],
      );
    }

    // Full mode: interactive like/dislike buttons with counts
    return Row(
      children: [
        // Like button
        Material(
          color: _myReaction == 'like'
              ? AppTheme.errorColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: AppRadius.xl,
          child: InkWell(
            borderRadius: AppRadius.xl,
            onTap: _reacting ? null : () => _react('like'),
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _myReaction == 'like' ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: AppIconSize.md,
                    color: _myReaction == 'like' ? AppTheme.errorColor : AppTheme.textSecondaryOf(context),
                  ),
                  AppSpacing.hSm,
                  Text(
                    '$_likeCount',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _myReaction == 'like' ? AppTheme.errorColor : AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Compact reaction icon button helper ──────────────────────────────────────

class _IconReactionButton extends StatelessWidget {
  final IconData icon;
  final Color activeColor;
  final bool isActive;
  final bool reacting;
  final VoidCallback onTap;
  final BuildContext context;

  const _IconReactionButton({
    required this.icon,
    required this.activeColor,
    required this.isActive,
    required this.reacting,
    required this.onTap,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    return Material(
      color: isActive
          ? activeColor.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: AppRadius.md,
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: reacting ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? activeColor : AppTheme.textSecondaryOf(ctx),
          ),
        ),
      ),
    );
  }
}
