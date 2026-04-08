import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../models/chat.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import '../../providers/chat_firebase_provider.dart';
import '../../repositories/chat_firebase_repository.dart';

class AnnouncementChannelScreen extends StatefulWidget {
  final String channelId;
  final bool isOrganizer;

  const AnnouncementChannelScreen({
    super.key,
    required this.channelId,
    this.isOrganizer = false,
  });

  @override
  State<AnnouncementChannelScreen> createState() =>
      _AnnouncementChannelScreenState();
}

class _AnnouncementChannelScreenState extends State<AnnouncementChannelScreen> {
  final _composeController = TextEditingController();
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    context.read<ChatFirebaseProvider>().openChannel(widget.channelId);
  }

  @override
  void dispose() {
    _composeController.dispose();
    context.read<ChatFirebaseProvider>().closeChannel();
    super.dispose();
  }

  Future<void> _submitPost() async {
    final body = _composeController.text.trim();
    if (body.isEmpty) return;

    setState(() => _posting = true);
    try {
      await context.read<ChatFirebaseProvider>().createPost(widget.channelId, body);
      _composeController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to post: $e')));
      }
    }
    if (mounted) setState(() => _posting = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatFirebaseProvider>();
    final isReadOnly = provider.activeChannel?.status != 'open';

    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: AppTheme.cardOf(context),
      ),
      body: Column(
        children: [
          if (isReadOnly)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              child: Text(
                'This channel is read-only',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.warningColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Expanded(
            child: provider.activePosts.isEmpty
                ? Center(
                    child: Text(
                      'No announcements yet',
                      style: TextStyle(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: provider.activePosts.length,
                    itemBuilder: (context, index) {
                      return _PostCard(
                        post: provider.activePosts[index],
                        channelId: widget.channelId,
                      );
                    },
                  ),
          ),
          if (widget.isOrganizer && !isReadOnly) _composeBar(context),
        ],
      ),
    );
  }

  Widget _composeBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        border: Border(top: BorderSide(color: AppTheme.dividerOf(context))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _composeController,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Write an announcement...',
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.md,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: _posting ? null : _submitPost,
              icon: _posting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.send_rounded, color: AppTheme.accentColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final ChatPost post;
  final String channelId;

  const _PostCard({required this.post, required this.channelId});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat.yMMMd()
        .add_jm()
        .format(post.createdAtDateTime.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: AppRadius.md,
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_rounded,
                  size: 16, color: AppTheme.accentColor),
              const SizedBox(width: 6),
              Text('Organizer',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textPrimaryOf(context),
                  )),
              const Spacer(),
              Text(dateStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryOf(context),
                  )),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(post.body,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimaryOf(context),
                height: 1.4,
              )),
          if (post.isImage && post.imageUrl != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: AppRadius.sm,
              child: Image.network(post.imageUrl!, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _ReactionBar(post: post, channelId: channelId),
        ],
      ),
    );
  }
}

class _ReactionBar extends StatefulWidget {
  final ChatPost post;
  final String channelId;

  const _ReactionBar({required this.post, required this.channelId});

  @override
  State<_ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<_ReactionBar> {
  UserReaction? _myReaction;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _sub = context
          .read<ChatFirebaseRepository>()
          .watchUserReaction(widget.channelId, widget.post.postId, uid)
          .listen((r) {
        if (mounted) setState(() => _myReaction = r);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _react(UserReaction reaction) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final newReaction = _myReaction == reaction ? null : reaction;
    await context.read<ChatFirebaseProvider>().reactToPost(
          widget.channelId,
          widget.post.postId,
          uid,
          newReaction,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _reactionButton(
          context,
          icon: Icons.thumb_up_outlined,
          activeIcon: Icons.thumb_up_rounded,
          count: widget.post.likeCount,
          isActive: _myReaction == UserReaction.like,
          onTap: () => _react(UserReaction.like),
        ),
        const SizedBox(width: AppSpacing.md),
        _reactionButton(
          context,
          icon: Icons.thumb_down_outlined,
          activeIcon: Icons.thumb_down_rounded,
          count: widget.post.dislikeCount,
          isActive: _myReaction == UserReaction.dislike,
          onTap: () => _react(UserReaction.dislike),
        ),
      ],
    );
  }

  Widget _reactionButton(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final color = isActive ? AppTheme.accentColor : AppTheme.textSecondaryOf(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.sm,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text('$count',
                style: TextStyle(
                    fontSize: 13, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
