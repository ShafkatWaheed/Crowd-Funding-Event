import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/app_toast.dart';

class ReactionBar extends StatefulWidget {
  final int eventId;
  final int initialLikeCount;
  final int initialDislikeCount;
  final bool isAdmin;

  const ReactionBar({
    required this.eventId,
    required this.initialLikeCount,
    required this.initialDislikeCount,
    required this.isAdmin,
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
      final api = context.read<ApiService>();
      final data = await api.getMyReaction(widget.eventId);
      if (mounted) setState(() => _myReaction = data['reaction']);
    } catch (_) {}
  }

  Future<void> _react(String reaction) async {
    if (_reacting) return;
    setState(() => _reacting = true);
    try {
      final api = context.read<ApiService>();
      final resp = await api.reactToEvent(widget.eventId, reaction);
      if (mounted) {
        setState(() {
          // Update reaction state based on action
          final action = resp['action'];
          if (action == 'removed') {
            _myReaction = null;
          } else {
            _myReaction = reaction;
          }
          // Update counts from server response
          _likeCount = resp['like_count'] ?? _likeCount;
          _dislikeCount = resp['dislike_count'] ?? _dislikeCount;
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
          Icon(Icons.thumb_up, size: AppIconSize.sm, color: AppTheme.accentColor),
          AppSpacing.hSm,
          Text(
            '$_likeCount like${_likeCount == 1 ? '' : 's'}',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondaryOf(context)),
          ),
          AppSpacing.hXl,
          Icon(Icons.thumb_down, size: AppIconSize.sm, color: AppTheme.textSecondaryOf(context)),
          AppSpacing.hSm,
          Text(
            '$_dislikeCount dislike${_dislikeCount == 1 ? '' : 's'}',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondaryOf(context)),
          ),
        ],
      );
    }

    // Everyone else: interactive like/dislike buttons
    return Row(
      children: [
        // Like button
        Material(
          color: _myReaction == 'like'
              ? AppTheme.accentColor.withValues(alpha: 0.1)
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
                    _myReaction == 'like' ? Icons.thumb_up : Icons.thumb_up_outlined,
                    size: AppIconSize.md,
                    color: _myReaction == 'like' ? AppTheme.accentColor : AppTheme.textSecondaryOf(context),
                  ),
                  AppSpacing.hSm,
                  Text(
                    '$_likeCount',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _myReaction == 'like' ? AppTheme.accentColor : AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AppSpacing.hSm,
        // Dislike button
        Material(
          color: _myReaction == 'dislike'
              ? AppTheme.errorColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: AppRadius.xl,
          child: InkWell(
            borderRadius: AppRadius.xl,
            onTap: _reacting ? null : () => _react('dislike'),
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _myReaction == 'dislike' ? Icons.thumb_down : Icons.thumb_down_outlined,
                    size: AppIconSize.md,
                    color: _myReaction == 'dislike' ? AppTheme.errorColor : AppTheme.textSecondaryOf(context),
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
