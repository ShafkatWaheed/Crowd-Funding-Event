import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/post.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/event_provider.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/empty_state.dart';

class EventFeedSection extends StatefulWidget {
  final int eventId;
  final bool postsEnabled;
  final bool isRegistered;

  const EventFeedSection({super.key, required this.eventId, required this.postsEnabled, required this.isRegistered});

  @override
  State<EventFeedSection> createState() => _EventFeedSectionState();
}

class _EventFeedSectionState extends State<EventFeedSection> {
  List<EventPost> _posts = [];
  bool _loading = true;
  bool _posting = false;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final repo = context.read<EventProvider>();
      final data = await repo.getEventPosts(widget.eventId);
      if (mounted) {
        setState(() {
          _posts = data;
        });
      }
    } catch (e) { debugPrint(e.toString()); }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submitPost() async {
    if (_ctrl.text.trim().isEmpty) return;
    if (!widget.isRegistered) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Registration Required'),
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: AppTheme.warningColor),
              AppSpacing.hMd,
              const Expanded(
                child: Text(
                  'Please register for this event before posting in the feed.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _posting = true);
    try {
      final repo = context.read<EventProvider>();
      await repo.createEventPost(widget.eventId, _ctrl.text.trim());
      _ctrl.clear();
      await _loadPosts();
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        if (msg.contains('403') || msg.toLowerCase().contains('forbidden') || msg.toLowerCase().contains('registered')) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Registration Required'),
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.warningColor),
                  AppSpacing.hMd,
                  const Expanded(
                    child: Text(
                      'Please register for this event before posting in the feed.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          AppToast.fromError(context, e, fallback: 'Failed to post');
        }
      }
    }
    if (mounted) setState(() => _posting = false);
  }

  Future<void> _deletePost(int postId) async {
    try {
      final repo = context.read<EventProvider>();
      await repo.deleteEventPost(widget.eventId, postId);
      await _loadPosts();
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to delete post');
      }
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'now';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with title + refresh button
        Row(
          children: [
            Icon(Icons.forum_rounded,
                size: AppIconSize.sm, color: AppTheme.textPrimaryOf(context)),
            AppSpacing.hSm,
            const Text(
              'Event Feed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            AppSpacing.hSm,
            if (!widget.postsEnabled)
              Chip(
                label:
                    const Text('Disabled', style: TextStyle(fontSize: 11)),
                backgroundColor: AppTheme.dividerOf(context),
                side: BorderSide.none,
              ),
            const Spacer(),
            // Refresh button
            Material(
              color: Colors.transparent,
              borderRadius: AppRadius.xl,
              child: InkWell(
                borderRadius: AppRadius.xl,
                onTap: _loading ? null : _loadPosts,
                child: Padding(
                  padding: AppSpacing.paddingSm,
                  child: _loading
                      ? SizedBox(
                          width: AppIconSize.sm,
                          height: AppIconSize.sm,
                          child:
                              const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.refresh_rounded,
                          size: AppIconSize.md, color: AppTheme.textSecondaryOf(context)),
                ),
              ),
            ),
          ],
        ),
        AppSpacing.vMd,

        // Post input
        if (widget.postsEnabled && user != null) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: InputDecoration(
                    hintText: 'Write something...',
                    border: OutlineInputBorder(
                        borderRadius: AppRadius.md),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
              ),
              AppSpacing.hSm,
              IconButton.filled(
                onPressed: _posting ? null : _submitPost,
                icon: _posting
                    ? SizedBox(
                        width: AppIconSize.sm,
                        height: AppIconSize.sm,
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                ),
              ),
            ],
          ),
          AppSpacing.vLg,
        ],

        // Content
        if (!widget.postsEnabled)
          EmptyState(
            icon: Icons.forum_outlined,
            title: 'Posts are disabled',
            subtitle: 'Posts are disabled for this event.',
          )
        else if (_loading && _posts.isEmpty)
          Center(
              child: Padding(
            padding: AppSpacing.paddingXxl,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ))
        else if (_posts.isEmpty)
          EmptyState(
            icon: Icons.chat_bubble_outline,
            title: 'No posts yet',
            subtitle: 'Be the first to share!',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _posts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final post = _posts[i];
              final isAuthor = user != null && user.id == post.userId;
              final isAdmin = user != null && user.isAdmin;
              final isOrg = user != null && user.isOrganizer;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      AppTheme.accentColor.withValues(alpha: 0.15),
                  child: Text(
                    (post.authorName ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentColor),
                  ),
                ),
                title: Text(
                  post.authorName ?? 'User',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(post.content),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _timeAgo(post.createdAt),
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                    ),
                    if (isAuthor || isAdmin || isOrg) ...[
                      AppSpacing.hXs,
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: AppIconSize.sm),
                        onPressed: () => _deletePost(post.id),
                        tooltip: 'Delete post',
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
