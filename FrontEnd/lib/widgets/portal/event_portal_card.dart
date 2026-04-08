import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../models/chat.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_firebase_provider.dart';
import '../../repositories/chat_firebase_repository.dart';

/// A single event card used in both Portal sheet (inline expand) and full view (navigate away).
class EventPortalCard extends StatefulWidget {
  final MyEventCard card;

  /// If true, tapping rows expands inline (sheet mode). If false, rows navigate to full screens.
  final bool inlineMode;

  /// Currently expanded section key (only used in inlineMode). Format: "{eventId}_{section}"
  final String? expandedKey;

  /// Called when a section is tapped in inline mode.
  final ValueChanged<String>? onToggleExpand;

  const EventPortalCard({
    super.key,
    required this.card,
    this.inlineMode = true,
    this.expandedKey,
    this.onToggleExpand,
  });

  @override
  State<EventPortalCard> createState() => _EventPortalCardState();
}

class _EventPortalCardState extends State<EventPortalCard> {
  MyEventCard get card => widget.card;
  bool get inlineMode => widget.inlineMode;
  String? get expandedKey => widget.expandedKey;
  ValueChanged<String>? get onToggleExpand => widget.onToggleExpand;

  String _key(String section) => '${card.eventId}_$section';
  bool _isExpanded(String section) => expandedKey == _key(section);

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: card.isCompleted ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: AppRadius.md,
          border: Border.all(
            color: card.isLive
                ? AppTheme.errorColor.withValues(alpha: 0.25)
                : AppTheme.dividerOf(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(context),
            if (card.channel != null || card.isOrganizer) _announcementSection(context),
            if (!card.isOrganizer) _chatSection(context),
            if (card.isOrganizer) _organizerConversationsRow(context),
            if (card.isOrganizer) _scannerRow(context),
            if (card.bidInfo != null) _bidRow(context),
            ...card.tickets.map((t) => _ticketSection(context, t)),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────

  Widget _header(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/events/${card.eventId}'),
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.mdValue)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: card.isLive ? AppTheme.errorColor.withValues(alpha: 0.04) : null,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.mdValue)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.eventTitle,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.textPrimaryOf(context))),
                  if (card.venueName != null)
                    Text(card.venueName!, style: TextStyle(fontSize: 9, color: AppTheme.textSecondaryOf(context))),
                ],
              ),
            ),
            _statusBadge(context),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context) {
    if (card.isLive) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(),
          const SizedBox(width: 3),
          const Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.errorColor, letterSpacing: 0.5)),
        ],
      );
    }
    if (card.isCompleted) {
      return Text('Completed', style: TextStyle(fontSize: 9, color: AppTheme.textSecondaryOf(context)));
    }
    if (card.startTime != null) {
      final days = card.startTime!.difference(DateTime.now()).inDays;
      if (days > 0) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('In ${days}d',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.warningColor)),
        );
      }
    }
    return const SizedBox.shrink();
  }

  // ── Announcements ─────────────────────────────────────

  Widget _announcementSection(BuildContext context) {
    final channelId = card.channel?.channelId ?? 'event_${card.eventId}_customer';
    final isOrgView = card.isOrganizer;
    final expanded = inlineMode && _isExpanded('announcements') && card.channel != null;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: expanded
          ? _expandedSection(
              context,
              key: 'announcements',
              icon: Icons.campaign_rounded,
              label: 'Announcements',
              color: AppTheme.accentColor,
              unread: card.channelUnreadCount,
              child: _AnnouncementExpanded(
                channelId: channelId,
                isOrganizer: isOrgView,
                onViewAll: () => context.push('/chat/channel/$channelId?organizer=$isOrgView'),
              ),
            )
          : _collapsedRow(
              context,
              icon: Icons.campaign_rounded,
              label: 'Announcements',
              unread: card.channelUnreadCount,
              onTap: inlineMode
                  ? (card.channel != null ? () => onToggleExpand?.call(_key('announcements')) : null)
                  : () => context.push('/chat/channel/$channelId?organizer=$isOrgView'),
              showNavArrow: !inlineMode,
            ),
    );
  }

  // ── Chat ──────────────────────────────────────────────

  Widget _chatSection(BuildContext context) {
    final conv = card.conversation;
    final hasConv = conv != null;
    final expanded = inlineMode && _isExpanded('chat') && hasConv;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: expanded
          ? _expandedSection(
              context,
              key: 'chat',
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Chat with Organizer',
              color: AppTheme.textSecondaryOf(context),
              unread: conv.unreadCount,
              child: _ChatExpanded(
                conversationId: conv.conversationId,
                onViewAll: () => context.push('/chat/dm/${conv.conversationId}?name=Organizer&writable=${conv.isOpen}'),
              ),
            )
          : _collapsedRow(
              context,
              icon: Icons.chat_bubble_outline_rounded,
              label: hasConv ? 'Chat with Organizer' : 'Message Organizer',
              unread: conv?.unreadCount ?? 0,
              trailing: !hasConv
                  ? Text('New', style: TextStyle(fontSize: 9, color: AppTheme.accentColor, fontWeight: FontWeight.w600))
                  : null,
              meta: hasConv ? conv.lastMessageText : null,
              onTap: inlineMode
                  ? () {
                      if (hasConv) {
                        onToggleExpand?.call(_key('chat'));
                      } else {
                        _initConversation(context);
                      }
                    }
                  : () {
                      if (hasConv) {
                        context.push('/chat/dm/${conv.conversationId}?name=Organizer&writable=${conv.isOpen}');
                      } else {
                        _initConversation(context);
                      }
                    },
              showNavArrow: !inlineMode && hasConv,
            ),
    );
  }

  Future<void> _initConversation(BuildContext context) async {
    try {
      final provider = context.read<ChatFirebaseProvider>();
      final conv = await provider.initConversation(card.eventId);
      if (context.mounted) {
        context.push('/chat/dm/${conv.conversationId}?name=Organizer&writable=true');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  // ── Organizer: Customer Conversations ──────────────────

  Widget _organizerConversationsRow(BuildContext context) {
    if (inlineMode && _isExpanded('org_messages')) {
      return AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: _expandedSection(
          context,
          key: 'org_messages',
          icon: Icons.forum_rounded,
          label: 'Customer Messages',
          color: AppTheme.accentColor,
          child: _OrganizerDmList(
            eventId: card.eventId,
            onViewAll: () => context.push('/chat/organizer-hub/${card.eventId}'),
          ),
        ),
      );
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: _collapsedRow(
        context,
        icon: Icons.forum_rounded,
        label: 'Customer Messages',
        onTap: inlineMode
            ? () => onToggleExpand?.call(_key('org_messages'))
            : () => context.push('/chat/organizer-hub/${card.eventId}'),
        showNavArrow: !inlineMode,
      ),
    );
  }

  // ── Organizer: Scanner ────────────────────────────────

  Widget _scannerRow(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/events/${card.eventId}/scan?title=${Uri.encodeComponent(card.eventTitle)}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.dividerOf(context), width: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.08),
                border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.15)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner_rounded, size: 14, color: AppTheme.successColor),
                  const SizedBox(width: 5),
                  Text('Scan Tickets',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.successColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bid Status ────────────────────────────────────────

  Widget _bidRow(BuildContext context) {
    final bid = card.bidInfo!;
    final isAccepted = bid.bidStatus == 'accepted' || bid.bidStatus == 'paid';
    return _collapsedRow(
      context,
      icon: Icons.sell_rounded,
      label: bid.categoryName,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: isAccepted
              ? AppTheme.successColor.withValues(alpha: 0.1)
              : AppTheme.warningColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isAccepted ? 'Accepted ✓' : bid.bidStatus,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: isAccepted ? AppTheme.successColor : AppTheme.warningColor,
          ),
        ),
      ),
      onTap: null,
    );
  }

  // ── Ticket ────────────────────────────────────────────

  Widget _ticketSection(BuildContext context, dynamic ticket) {
    final isScanned = ticket.scannedAt != null;
    final code = ticket.ticketCode;
    final tierName = ticket.tierName ?? 'Ticket';
    final expanded = inlineMode && _isExpanded('ticket_${ticket.id}');

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: expanded
          ? _expandedSection(
              context,
              key: 'ticket_${ticket.id}',
              icon: Icons.confirmation_number_rounded,
              label: '$tierName — #$code',
              color: AppTheme.successColor,
              child: _TicketExpanded(
                ticket: ticket,
                onFullDetails: () => context.push('/tickets/${ticket.id}'),
              ),
            )
          : Opacity(
              opacity: isScanned ? 0.45 : 1.0,
              child: _collapsedRow(
                context,
                icon: Icons.confirmation_number_rounded,
                label: '$tierName — #$code${isScanned ? ' ✓' : ''}',
                meta: isScanned ? 'Scanned' : null,
                onTap: inlineMode
                    ? () => onToggleExpand?.call(_key('ticket_${ticket.id}'))
                    : () => context.push('/tickets/${ticket.id}'),
                showNavArrow: !inlineMode && !isScanned,
              ),
            ),
    );
  }

  // ── Shared row builders ───────────────────────────────

  Widget _collapsedRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    int unread = 0,
    String? meta,
    Widget? trailing,
    VoidCallback? onTap,
    bool showNavArrow = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.sm - 1),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.dividerOf(context), width: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppTheme.textSecondaryOf(context)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 10, color: AppTheme.textPrimaryOf(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            if (meta != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(meta, style: TextStyle(fontSize: 9, color: AppTheme.textSecondaryOf(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            if (unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: AppTheme.accentColor, borderRadius: BorderRadius.circular(6)),
                child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600)),
              ),
            if (trailing != null) trailing,
            if (showNavArrow)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('Open →', style: TextStyle(fontSize: 9, color: AppTheme.accentColor, fontWeight: FontWeight.w600)),
              ),
            if (onTap != null && !showNavArrow && inlineMode)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.chevron_right, size: 12, color: AppTheme.textSecondaryOf(context)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _expandedSection(
    BuildContext context, {
    required String key,
    required IconData icon,
    required String label,
    Color? color,
    int unread = 0,
    required Widget child,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => onToggleExpand?.call(_key(key)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.sm - 1),
            decoration: BoxDecoration(
              color: (color ?? AppTheme.accentColor).withValues(alpha: 0.04),
              border: Border(top: BorderSide(color: AppTheme.dividerOf(context), width: 0.3)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 14, color: color ?? AppTheme.accentColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color ?? AppTheme.accentColor)),
                ),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: AppTheme.accentColor, borderRadius: BorderRadius.circular(6)),
                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600)),
                  ),
                Icon(Icons.expand_less, size: 14, color: AppTheme.textSecondaryOf(context)),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          color: AppTheme.surfaceOf(context).withValues(alpha: 0.5),
          child: child,
        ),
      ],
    );
  }
}

// ── Inline expanded content widgets ─────────────────────

class _AnnouncementExpanded extends StatefulWidget {
  final String channelId;
  final bool isOrganizer;
  final VoidCallback onViewAll;

  const _AnnouncementExpanded({required this.channelId, this.isOrganizer = false, required this.onViewAll});

  @override
  State<_AnnouncementExpanded> createState() => _AnnouncementExpandedState();
}

class _AnnouncementExpandedState extends State<_AnnouncementExpanded> {
  final _composeCtrl = TextEditingController();
  bool _posting = false;
  StreamSubscription? _sub;
  List<ChatPost> _posts = [];

  @override
  void initState() {
    super.initState();
    _sub = context.read<ChatFirebaseRepository>().watchPosts(widget.channelId).listen((posts) {
      if (mounted) setState(() => _posts = posts.reversed.take(3).toList());
    });
  }

  @override
  void dispose() {
    _composeCtrl.dispose();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _postAnnouncement() async {
    final body = _composeCtrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _posting = true);
    try {
      await context.read<ChatFirebaseProvider>().createPost(widget.channelId, body);
      _composeCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => _posting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isOrganizer) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _composeCtrl,
                  onSubmitted: (_) => _postAnnouncement(),
                  style: const TextStyle(fontSize: 10),
                  decoration: InputDecoration(
                    hintText: 'Write an announcement...',
                    hintStyle: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(borderRadius: AppRadius.sm, borderSide: BorderSide(color: AppTheme.dividerOf(context))),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: _posting ? null : _postAnnouncement,
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(color: AppTheme.accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: _posting
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))
                      : Icon(Icons.arrow_upward, size: 14, color: AppTheme.accentColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        if (_posts.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text('No announcements yet', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context))),
          )
        else
          ..._posts.map((post) => _InlinePost(post: post, channelId: widget.channelId)),
        InkWell(
          onTap: widget.onViewAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('View All Announcements →',
                style: TextStyle(fontSize: 9, color: AppTheme.accentColor, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _InlinePost extends StatefulWidget {
  final ChatPost post;
  final String channelId;

  const _InlinePost({required this.post, required this.channelId});

  @override
  State<_InlinePost> createState() => _InlinePostState();
}

class _InlinePostState extends State<_InlinePost> {
  UserReaction? _myReaction;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _sub = context.read<ChatFirebaseRepository>().watchUserReaction(widget.channelId, widget.post.postId, uid).listen((r) {
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
    await context.read<ChatFirebaseProvider>().reactToPost(widget.channelId, widget.post.postId, uid, newReaction);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: AppRadius.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Organizer', style: TextStyle(fontSize: 9, color: AppTheme.accentColor, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(_timeAgo(widget.post.createdAt), style: TextStyle(fontSize: 8, color: AppTheme.textSecondaryOf(context))),
            ],
          ),
          const SizedBox(height: 2),
          Text(widget.post.body, style: TextStyle(fontSize: 10, color: AppTheme.textPrimaryOf(context), height: 1.3)),
          const SizedBox(height: 4),
          Row(
            children: [
              _rxButton(Icons.thumb_up_outlined, Icons.thumb_up, widget.post.likeCount, _myReaction == UserReaction.like, () => _react(UserReaction.like)),
              const SizedBox(width: 10),
              _rxButton(Icons.thumb_down_outlined, Icons.thumb_down, widget.post.dislikeCount, _myReaction == UserReaction.dislike, () => _react(UserReaction.dislike)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rxButton(IconData icon, IconData activeIcon, int count, bool active, VoidCallback onTap) {
    final color = active ? AppTheme.accentColor : AppTheme.textSecondaryOf(context);
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? activeIcon : icon, size: 13, color: color),
          const SizedBox(width: 2),
          Text('$count', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _timeAgo(int ms) {
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _ChatExpanded extends StatefulWidget {
  final String conversationId;
  final VoidCallback onViewAll;

  const _ChatExpanded({required this.conversationId, required this.onViewAll});

  @override
  State<_ChatExpanded> createState() => _ChatExpandedState();
}

class _ChatExpandedState extends State<_ChatExpanded> {
  final _inputController = TextEditingController();
  StreamSubscription? _sub;
  List<DmMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _sub = context.read<ChatFirebaseRepository>().watchMessages(widget.conversationId).listen((msgs) {
      if (mounted) setState(() => _messages = msgs.reversed.take(3).toList().reversed.toList());
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _inputController.text.trim();
    if (body.isEmpty) return;
    _inputController.clear();
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    await context.read<ChatFirebaseProvider>().sendMessage(
      widget.conversationId,
      body,
      clientId: 'c_${DateTime.now().millisecondsSinceEpoch}',
      senderId: user.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<AuthProvider>().user?.id;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_messages.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text('No messages yet', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context))),
          )
        else
          ..._messages.map((msg) {
            final isMine = msg.senderId == myId;
            return Align(
              alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 3),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
                decoration: BoxDecoration(
                  color: isMine ? AppTheme.accentColor.withValues(alpha: 0.1) : AppTheme.cardOf(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(msg.body, style: TextStyle(fontSize: 10, color: AppTheme.textPrimaryOf(context))),
                    Text(_timeAgo(msg.createdAt), style: TextStyle(fontSize: 7, color: AppTheme.textSecondaryOf(context))),
                  ],
                ),
              ),
            );
          }),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                onSubmitted: (_) => _send(),
                style: const TextStyle(fontSize: 10),
                decoration: InputDecoration(
                  hintText: 'Reply...',
                  hintStyle: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(borderRadius: AppRadius.sm, borderSide: BorderSide(color: AppTheme.dividerOf(context))),
                ),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: _send,
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(color: AppTheme.accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Icon(Icons.arrow_upward, size: 14, color: AppTheme.accentColor),
              ),
            ),
          ],
        ),
        InkWell(
          onTap: widget.onViewAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('View Full Chat →',
                style: TextStyle(fontSize: 9, color: AppTheme.accentColor, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  String _timeAgo(int ms) {
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _TicketExpanded extends StatelessWidget {
  final dynamic ticket;
  final VoidCallback onFullDetails;

  const _TicketExpanded({required this.ticket, required this.onFullDetails});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // QR placeholder
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.sm),
          child: const Center(child: Icon(Icons.qr_code_2, size: 70, color: Colors.black87)),
        ),
        const SizedBox(height: 4),
        Text(ticket.ticketCode, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context), letterSpacing: 0.5)),
        Text('${ticket.tierName ?? "Ticket"}', style: TextStyle(fontSize: 9, color: AppTheme.textSecondaryOf(context))),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _actionBtn(context, 'Share', Icons.share, null),
            const SizedBox(width: 8),
            _actionBtn(context, 'Full Details →', Icons.open_in_new, onFullDetails),
          ],
        ),
      ],
    );
  }

  Widget _actionBtn(BuildContext context, String label, IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(fontSize: 9, color: AppTheme.accentColor, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 5, height: 5,
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.3 + _ctrl.value * 0.7),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Organizer: inline DM list (top 5) ───────────────────

class _OrganizerDmList extends StatefulWidget {
  final int eventId;
  final VoidCallback onViewAll;

  const _OrganizerDmList({required this.eventId, required this.onViewAll});

  @override
  State<_OrganizerDmList> createState() => _OrganizerDmListState();
}

class _OrganizerDmListState extends State<_OrganizerDmList> {
  List<DmConversation> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final convs = await context
          .read<ChatFirebaseProvider>()
          .getEventConversations(widget.eventId, typeFilter: 'customer');
      if (mounted) {
        setState(() {
          _conversations = convs.take(5).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_conversations.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text('No customer messages yet',
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context))),
          )
        else
          ..._conversations.map((conv) => _dmItem(context, conv)),
        InkWell(
          onTap: widget.onViewAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('View All Conversations →',
                style: TextStyle(fontSize: 9, color: AppTheme.accentColor, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _dmItem(BuildContext context, DmConversation conv) {
    final initial = (conv.participantName ?? '?')[0].toUpperCase();
    return InkWell(
      onTap: () {
        final name = conv.participantName ?? 'Customer';
        context.push('/chat/dm/${conv.conversationId}?name=${Uri.encodeComponent(name)}&writable=${conv.isOpen}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: AppTheme.textSecondaryOf(context).withValues(alpha: 0.1),
              child: Text(initial,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context))),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conv.participantName ?? 'Customer',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context))),
                  if (conv.lastMessageText != null)
                    Text(conv.lastMessageText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9, color: AppTheme.textSecondaryOf(context))),
                ],
              ),
            ),
            if (conv.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: AppTheme.accentColor, borderRadius: BorderRadius.circular(6)),
                child: Text('${conv.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600)),
              ),
            if (conv.lastMessageAt != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(_timeAgo(conv.lastMessageAt!),
                    style: TextStyle(fontSize: 8, color: AppTheme.textSecondaryOf(context))),
              ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(int ms) {
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
