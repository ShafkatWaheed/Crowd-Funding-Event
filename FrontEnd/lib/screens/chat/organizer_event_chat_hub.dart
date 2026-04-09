import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../models/chat.dart';
import '../../providers/chat_firebase_provider.dart';

/// Event chat hub for organizers — shows both Customer and Sponsor sections.
class OrganizerEventChatHub extends StatefulWidget {
  final int eventId;

  const OrganizerEventChatHub({super.key, required this.eventId});

  @override
  State<OrganizerEventChatHub> createState() => _OrganizerEventChatHubState();
}

class _OrganizerEventChatHubState extends State<OrganizerEventChatHub> {
  List<DmConversation> _customerConvs = [];
  List<DmConversation> _sponsorConvs = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final provider = context.read<ChatFirebaseProvider>();
      final customers = await provider.getEventConversations(widget.eventId, typeFilter: 'customer');
      final sponsors = await provider.getEventConversations(widget.eventId, typeFilter: 'sponsor');
      if (mounted) {
        setState(() {
          _customerConvs = customers;
          _sponsorConvs = sponsors;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerChannelId = 'event_${widget.eventId}_customer';
    final sponsorChannelId = 'event_${widget.eventId}_sponsor';

    final q = _search.toLowerCase();
    final filteredCustomers = _search.isEmpty
        ? _customerConvs
        : _customerConvs.where((c) =>
            (c.participantName?.toLowerCase().contains(q) ?? false) ||
            (c.lastMessageText?.toLowerCase().contains(q) ?? false)).toList();
    final filteredSponsors = _search.isEmpty
        ? _sponsorConvs
        : _sponsorConvs.where((c) =>
            (c.participantName?.toLowerCase().contains(q) ?? false) ||
            (c.lastMessageText?.toLowerCase().contains(q) ?? false)).toList();

    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(
        title: const Text('Event Chat'),
        backgroundColor: AppTheme.cardOf(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: TextStyle(fontSize: 12, color: AppTheme.textPrimaryOf(context)),
                    decoration: InputDecoration(
                      hintText: 'Search conversations...',
                      hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.6)),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: Icon(Icons.search_rounded, size: 18, color: AppTheme.accentColor.withValues(alpha: 0.6)),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0),
                      isDense: true,
                      filled: true,
                      fillColor: AppTheme.inputFillOf(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: AppRadius.md, borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: AppRadius.md, borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.md,
                        borderSide: BorderSide(color: AppTheme.accentColor.withValues(alpha: 0.3), width: 1),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadAll,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      children: [
                  // ── CUSTOMERS ──────────────────────────────
                  _sectionHeader('CUSTOMERS', AppTheme.accentColor),

                  _SectionTile(
                    icon: Icons.campaign_rounded,
                    iconColor: AppTheme.accentColor,
                    title: 'Customer Announcements',
                    subtitle: 'Post announcements to customers',
                    onTap: () => context.push('/chat/channel/$customerChannelId?organizer=true'),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  if (filteredCustomers.isEmpty)
                    _emptyConvs(_search.isEmpty ? 'No customer messages yet' : 'No matching customers')
                  else
                    ...filteredCustomers.map((conv) => _ConversationTile(conversation: conv)),

                  const SizedBox(height: AppSpacing.xl),

                  // ── SPONSORS ───────────────────────────────
                  _sectionHeader('SPONSORS', AppTheme.warningColor),

                  _SectionTile(
                    icon: Icons.campaign_rounded,
                    iconColor: AppTheme.warningColor,
                    title: 'Sponsor Announcements',
                    subtitle: 'Post announcements to sponsors',
                    onTap: () => context.push('/chat/channel/$sponsorChannelId?organizer=true'),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  if (filteredSponsors.isEmpty)
                    _emptyConvs(_search.isEmpty ? 'No sponsor messages yet' : 'No matching sponsors')
                  else
                    ...filteredSponsors.map((conv) => _ConversationTile(conversation: conv)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionHeader(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(width: 3, height: 14, decoration: BoxDecoration(color: color, borderRadius: AppRadius.pill)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _emptyConvs(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Text(text, style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 12)),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SectionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.06),
        borderRadius: AppRadius.md,
        border: Border.all(color: iconColor.withValues(alpha: 0.12)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 17, color: iconColor),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textPrimaryOf(context))),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context))),
        trailing: Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textSecondaryOf(context)),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final DmConversation conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: AppRadius.md,
        border: Border.all(color: AppTheme.dividerOf(context), width: 0.5),
      ),
      child: ListTile(
        onTap: () {
          final name = conversation.participantName ?? 'User';
          context.push('/chat/dm/${conversation.conversationId}?name=${Uri.encodeComponent(name)}&writable=${conversation.isOpen}');
        },
        leading: CircleAvatar(
          radius: 17,
          backgroundColor: hasUnread
              ? AppTheme.accentColor.withValues(alpha: 0.12)
              : AppTheme.textSecondaryOf(context).withValues(alpha: 0.08),
          child: Text(
            (conversation.participantName ?? '?')[0].toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13,
              color: hasUnread ? AppTheme.accentColor : AppTheme.textPrimaryOf(context),
            ),
          ),
        ),
        title: Text(
          conversation.participantName ?? 'User',
          style: TextStyle(
            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        subtitle: conversation.lastMessageText != null
            ? Text(
                conversation.lastMessageText!,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                  color: hasUnread ? AppTheme.textPrimaryOf(context) : AppTheme.textSecondaryOf(context),
                ),
              )
            : null,
        trailing: hasUnread
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.accentColor, borderRadius: BorderRadius.circular(10)),
                child: Text('${conversation.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
              )
            : null,
      ),
    );
  }
}
