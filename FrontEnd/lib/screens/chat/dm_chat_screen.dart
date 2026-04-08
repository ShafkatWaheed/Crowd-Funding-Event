import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../models/chat.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import '../../providers/auth_provider.dart';
import '../../providers/chat_firebase_provider.dart';

class DmChatScreen extends StatefulWidget {
  final String conversationId;
  final String? participantName;
  final bool isWritable;

  const DmChatScreen({
    super.key,
    required this.conversationId,
    this.participantName,
    this.isWritable = true,
  });

  @override
  State<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends State<DmChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  late final ChatFirebaseProvider _chat;
  int? _myUserId;
  String? _myFirebaseUid;

  @override
  void initState() {
    super.initState();
    _chat = context.read<ChatFirebaseProvider>();
    _chat.openConversation(widget.conversationId);

    final user = context.read<AuthProvider>().user;
    _myUserId = user?.id;
    _myFirebaseUid = FirebaseAuth.instance.currentUser?.uid;

    // Mark as read
    if (_myFirebaseUid != null) {
      _chat.markRead(widget.conversationId, _myFirebaseUid!);
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    if (_myFirebaseUid != null) {
      _chat.setTyping(widget.conversationId, _myFirebaseUid!, false);
    }
    _chat.closeConversation();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final body = _inputController.text.trim();
    if (body.isEmpty || _myUserId == null) return;

    _inputController.clear();
    final clientId = 'client_${DateTime.now().millisecondsSinceEpoch}';
    await _chat.sendMessage(
      widget.conversationId,
      body,
      clientId: clientId,
      senderId: _myUserId!,
    );

    if (_myFirebaseUid != null) {
      _chat.setTyping(widget.conversationId, _myFirebaseUid!, false);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _onTyping(String text) {
    if (_myFirebaseUid == null) return;
    _chat.setTyping(widget.conversationId, _myFirebaseUid!, text.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatFirebaseProvider>();
    final messages = provider.activeMessages;

    // Auto-scroll on new messages
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(
        title: Text(widget.participantName ?? 'Chat'),
        backgroundColor: AppTheme.cardOf(context),
      ),
      body: Column(
        children: [
          if (!widget.isWritable)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              child: Text(
                'This conversation is read-only',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.warningColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMine = msg.senderId == _myUserId;
                      return _MessageBubble(message: msg, isMine: isMine);
                    },
                  ),
          ),
          _typingIndicator(provider),
          if (widget.isWritable) _inputBar(context),
        ],
      ),
    );
  }

  Widget _typingIndicator(ChatFirebaseProvider provider) {
    final typing = provider.typingUsers.entries
        .where((e) => e.value && e.key != _myFirebaseUid)
        .toList();
    if (typing.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 12,
            child: _TypingDots(),
          ),
          const SizedBox(width: 6),
          Text(
            'typing...',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryOf(context),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar(BuildContext context) {
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
                controller: _inputController,
                onChanged: _onTyping,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
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
              onPressed: _send,
              icon: Icon(Icons.send_rounded, color: AppTheme.accentColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final DmMessage message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.jm().format(message.createdAtDateTime.toLocal());

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? AppTheme.accentColor.withValues(alpha: 0.15)
              : AppTheme.cardOf(context),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadius.mdValue),
            topRight: Radius.circular(AppRadius.mdValue),
            bottomLeft: isMine
                ? Radius.circular(AppRadius.mdValue)
                : const Radius.circular(4),
            bottomRight: isMine
                ? const Radius.circular(4)
                : Radius.circular(AppRadius.mdValue),
          ),
          border: isMine
              ? null
              : Border.all(color: AppTheme.dividerOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message.isImage && message.imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ClipRRect(
                  borderRadius: AppRadius.sm,
                  child: Image.network(message.imageUrl!, fit: BoxFit.cover),
                ),
              ),
            Text(
              message.body,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity = (t < 0.5) ? t * 2 : (1 - t) * 2;
            return Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: AppTheme.textSecondaryOf(context).withValues(alpha: opacity.clamp(0.3, 1.0)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
