import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../models/chat.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_firebase_provider.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/portal/event_portal_card.dart';

/// Full view Portal tab — every row navigates to a full screen.
class MyEventsTab extends StatefulWidget {
  const MyEventsTab({super.key});

  @override
  State<MyEventsTab> createState() => _MyEventsTabState();
}

class _MyEventsTabState extends State<MyEventsTab> {
  String _search = '';
  String? _statusFilter; // null = all
  String _sortBy = 'soonest'; // soonest, newest, name_az

  static const _statusOptions = [
    ('live', 'Live', Colors.red),
    ('selling_tickets', 'Selling', Colors.green),
    ('approved', 'Approved', Colors.blue),
    ('completed', 'Completed', Colors.grey),
  ];

  static const _sortOptions = {
    'soonest': 'Soonest',
    'newest': 'Newest',
    'name_az': 'Name A-Z',
  };

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
    context.read<ChatFirebaseProvider>().loadMyEvents(userId: user?.id, isOrganizer: isOrg);
  }

  Future<void> _refresh() async {
    final user = context.read<AuthProvider>().user;
    final isOrg = user != null && (user.isOrganizer || user.isAdmin);
    await context.read<ChatFirebaseProvider>().loadMyEvents(userId: user?.id, isOrganizer: isOrg);
  }

  List<MyEventCard> get _filtered {
    var cards = context.read<ChatFirebaseProvider>().myEventCards;

    // Status filter
    if (_statusFilter != null) {
      cards = cards.where((c) => c.eventStatus == _statusFilter).toList();
    }

    // Search
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      cards = cards.where((c) {
        return c.eventTitle.toLowerCase().contains(q) ||
            (c.venueName?.toLowerCase().contains(q) ?? false) ||
            c.tickets.any((t) =>
                (t.tierName?.toLowerCase().contains(q) ?? false) ||
                t.ticketCode.toLowerCase().contains(q));
      }).toList();
    }

    // Sort
    if (_sortBy == 'name_az') {
      cards = List.of(cards)..sort((a, b) => a.eventTitle.compareTo(b.eventTitle));
    } else if (_sortBy == 'newest') {
      cards = List.of(cards)..sort((a, b) {
        final aTime = b.startTime?.millisecondsSinceEpoch ?? 0;
        final bTime = a.startTime?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
    }
    // 'soonest' is the default sort from loadMyEvents

    return cards;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatFirebaseProvider>();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
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

        // Sort chips
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, 0, 0),
          child: SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Icon(Icons.sort_rounded, size: 14, color: AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 6),
                ..._sortOptions.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: AppChip(
                        label: e.value,
                        selected: _sortBy == e.key,
                        onSelected: (_) => setState(() => _sortBy = e.key),
                        chipColor: AppTheme.accentColor,
                        fontSize: 11,
                      ),
                    )),
              ],
            ),
          ),
        ),

        // Status filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 4, 0, AppSpacing.sm),
          child: SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: AppChip(
                    label: 'All',
                    selected: _statusFilter == null,
                    onSelected: (_) => setState(() => _statusFilter = null),
                    chipColor: AppTheme.accentColor,
                    fontSize: 11,
                  ),
                ),
                ..._statusOptions.map((opt) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: AppChip(
                        label: opt.$2,
                        selected: _statusFilter == opt.$1,
                        onSelected: (sel) => setState(() => _statusFilter = sel ? opt.$1 : null),
                        chipColor: opt.$3,
                        fontSize: 11,
                      ),
                    )),
              ],
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
                            inlineMode: false,
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
              _search.isEmpty && _statusFilter == null ? 'No Events Yet' : 'No matching events',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _search.isEmpty && _statusFilter == null
                  ? 'Your events will appear here once you purchase tickets or make pledges.'
                  : 'Try a different search or filter.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
            ),
            if (context.read<ChatFirebaseProvider>().myEventsError != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                context.read<ChatFirebaseProvider>().myEventsError!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: AppTheme.errorColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
