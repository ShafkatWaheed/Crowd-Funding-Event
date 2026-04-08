import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../models/chat.dart';
import '../../providers/chat_firebase_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/portal/event_portal_card.dart';

/// Full view Portal tab — every row navigates to a full screen.
class MyEventsTab extends StatefulWidget {
  const MyEventsTab({super.key});

  @override
  State<MyEventsTab> createState() => _MyEventsTabState();
}

class _MyEventsTabState extends State<MyEventsTab> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEvents();
    });
  }

  void _loadEvents() {
    final user = context.read<AuthProvider>().user;
    final isOrg = user != null && (user.isOrganizer || user.isAdmin);
    final orgEvents = isOrg ? context.read<EventProvider>().events : null;
    context.read<ChatFirebaseProvider>().loadMyEvents(organizedEvents: orgEvents);
  }

  Future<void> _refresh() async {
    final user = context.read<AuthProvider>().user;
    final isOrg = user != null && (user.isOrganizer || user.isAdmin);
    final orgEvents = isOrg ? context.read<EventProvider>().events : null;
    await context.read<ChatFirebaseProvider>().loadMyEvents(organizedEvents: orgEvents);
  }

  List<MyEventCard> get _filtered {
    final cards = context.read<ChatFirebaseProvider>().myEventCards;
    if (_search.isEmpty) return cards;
    final q = _search.toLowerCase();
    return cards.where((c) {
      return c.eventTitle.toLowerCase().contains(q) ||
          (c.venueName?.toLowerCase().contains(q) ?? false) ||
          c.tickets.any((t) =>
              (t.tierName?.toLowerCase().contains(q) ?? false) ||
              t.ticketCode.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatFirebaseProvider>();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Search events, tickets...',
              hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
              prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.textSecondaryOf(context)),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: AppRadius.sm,
                borderSide: BorderSide(color: AppTheme.dividerOf(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.sm,
                borderSide: BorderSide(color: AppTheme.dividerOf(context)),
              ),
            ),
          ),
        ),

        // Cards
        Expanded(
          child: provider.loadingMyEvents && provider.myEventCards.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? _emptyState(context)
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          return EventPortalCard(
                            card: _filtered[index],
                            inlineMode: false, // full view: rows navigate away
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_outlined, size: 56, color: AppTheme.textSecondaryOf(context)),
            const SizedBox(height: AppSpacing.md),
            Text(
              _search.isEmpty ? 'No Events Yet' : 'No matching events',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _search.isEmpty
                  ? 'Your events will appear here once you purchase tickets or make pledges.'
                  : 'Try a different search term.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
            ),
          ],
        ),
      ),
    );
  }
}
