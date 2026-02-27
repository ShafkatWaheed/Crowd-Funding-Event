import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/chat_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class BidChatScreen extends StatefulWidget {
  final int bidId;
  final String? participantName;
  final bool isWritable;

  const BidChatScreen({
    super.key,
    required this.bidId,
    this.participantName,
    this.isWritable = true,
  });

  @override
  State<BidChatScreen> createState() => _BidChatScreenState();
}

class _BidChatScreenState extends State<BidChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoadingHistory = false;
  Timer? _typingTimer;
  bool _isSendingTyping = false;

  @override
  void initState() {
    super.initState();
    final chat = context.read<ChatProvider>();
    chat.joinBid(widget.bidId);
    _loadInitialHistory();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadInitialHistory() async {
    setState(() => _isLoadingHistory = true);
    await context.read<ChatProvider>().loadHistory(widget.bidId);
    _markLatestRead();
    setState(() => _isLoadingHistory = false);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 50 &&
        !_isLoadingHistory) {
      final messages = context.read<ChatProvider>().messagesFor(widget.bidId);
      if (messages.isNotEmpty) {
        setState(() => _isLoadingHistory = true);
        context
            .read<ChatProvider>()
            .loadHistory(widget.bidId, before: messages.last.id)
            .then((_) {
          if (mounted) setState(() => _isLoadingHistory = false);
        });
      }
    }
  }

  void _markLatestRead() {
    final messages = context.read<ChatProvider>().messagesFor(widget.bidId);
    if (messages.isNotEmpty) {
      context.read<ChatProvider>().markRead(widget.bidId, messages.first.id);
    }
  }

  void _sendMessage() {
    final body = _inputController.text.trim();
    if (body.isEmpty) return;
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    context.read<ChatProvider>().sendMessage(widget.bidId, body, userId);
    _inputController.clear();
    _typingTimer?.cancel();
    if (_isSendingTyping) {
      context.read<ChatProvider>().sendTypingIndicator(widget.bidId, false);
      _isSendingTyping = false;
    }
  }

  void _onTextChanged(String text) {
    if (!_isSendingTyping && text.isNotEmpty) {
      _isSendingTyping = true;
      context.read<ChatProvider>().sendTypingIndicator(widget.bidId, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isSendingTyping) {
        _isSendingTyping = false;
        context.read<ChatProvider>().sendTypingIndicator(widget.bidId, false);
      }
    });
  }

  @override
  void dispose() {
    context.read<ChatProvider>().leaveBid(widget.bidId);
    context.read<ChatProvider>().clearBid(widget.bidId);
    _inputController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().user?.id ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.participantName ?? 'Chat',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          if (!widget.isWritable)
            Container(
              width: double.infinity,
              color: AppTheme.warningColor.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: AppTheme.warningColor),
                  const SizedBox(width: 8),
                  Text(
                    'This conversation is closed',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chat, _) {
                final messages = chat.messagesFor(widget.bidId);
                if (_isLoadingHistory && messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Start the conversation',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Discuss sponsorship details here',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length + (_isLoadingHistory ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isLoadingHistory && index == messages.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    final msg = messages[index];
                    final showDate = index == messages.length - 1 ||
                        !_sameDay(msg.createdAt, messages[index + 1].createdAt);

                    return Column(
                      children: [
                        if (showDate) _DateSeparator(date: msg.createdAt),
                        if (msg.isSystem)
                          _SystemMessage(text: msg.body)
                        else
                          _MessageBubble(
                            message: msg,
                            isMe: msg.senderId == currentUserId,
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Consumer<ChatProvider>(
            builder: (context, chat, _) {
              if (chat.isTyping(widget.bidId)) {
                return Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'typing...',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          if (widget.isWritable) _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                onChanged: _onTextChanged,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: AppTheme.surfaceOf(context),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Material(
              color: AppTheme.accentColor,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sendMessage,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}


class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (_sameDay(date, now)) {
      label = 'Today';
    } else if (_sameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMM d, yyyy').format(date);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
          ),
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}


class _SystemMessage extends StatelessWidget {
  final String text;
  const _SystemMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ),
      ),
    );
  }
}


class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isMe
              ? AppTheme.accentColor
              : AppTheme.surfaceOf(context),
          borderRadius: radius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.body,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? Colors.white : AppTheme.textPrimaryOf(context),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(message.createdAt.toLocal()),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppTheme.textSecondaryOf(context),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _tickIcon(message.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tickIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(Icons.access_time, size: 14, color: Colors.white.withValues(alpha: 0.5));
      case MessageStatus.sent:
        return Icon(Icons.done, size: 14, color: Colors.white.withValues(alpha: 0.7));
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: Colors.white.withValues(alpha: 0.7));
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 14, color: Colors.lightBlueAccent);
    }
  }
}
