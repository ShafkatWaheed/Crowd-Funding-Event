import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_icons.dart';
import '../../config/theme.dart';
import '../../models/event.dart';
import '../../repositories/base_repository.dart';
import '../../providers/bookmark_provider.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/event/event_card.dart';

class BookmarkedEventsScreen extends StatefulWidget {
  const BookmarkedEventsScreen({super.key});

  @override
  State<BookmarkedEventsScreen> createState() => _BookmarkedEventsScreenState();
}

class _BookmarkedEventsScreenState extends State<BookmarkedEventsScreen> {
  static const _pageSize = 20;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _statusFilter;
  List<Event> _events = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  // (label, icon, EventStatus for color lookup)
  static const _statusOptions = <(String, String, IconData)>[
    ('approved',            'Funding',         Icons.volunteer_activism_rounded),
    ('selling_tickets',     'Selling Tickets', Icons.confirmation_number_rounded),
    ('waiting_event_date',  'Awaiting Date',   Icons.hourglass_top_rounded),
    ('live',                'Live',            Icons.circle),
    ('completed',           'Completed',       Icons.check_circle_rounded),
    ('cancelled',           'Cancelled',       Icons.cancel_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent * 0.8 &&
        !_loadingMore &&
        _hasMore &&
        !_loading) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasMore = true;
    });
    try {
      final repo = context.read<BookmarkProvider>();
      final data = await repo.getBookmarkedEvents(
        search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
        status: _statusFilter,
        offset: 0,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _events = data;
          _hasMore = data.length >= _pageSize;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ApiError.extractMessage(e));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final repo = context.read<BookmarkProvider>();
      final data = await repo.getBookmarkedEvents(
        search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
        status: _statusFilter,
        offset: _events.length,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _events.addAll(data);
          _hasMore = data.length >= _pageSize;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _removeBookmark(int eventId) async {
    try {
      final repo = context.read<BookmarkProvider>();
      await repo.toggleBookmark(eventId);
      if (mounted) {
        setState(() => _events.removeWhere((e) => e.id == eventId));
      }
    } catch (e) {
      if (mounted) AppToast.error(context, ApiError.extractMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search bookmarked events...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _load();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surfaceOf(context),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _filterChip(null, 'All', Icons.bookmarks_rounded, AppTheme.accentColor),
                ..._statusOptions.map((o) => _filterChip(
                      o.$1, o.$2, o.$3,
                      AppIcons.forEventStatus(_statusFromKey(o.$1)).color(false),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children:
                          List.generate(3, (_) => const ShimmerListTile()),
                    ),
                  )
                : _events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceOf(context),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Icon(Icons.bookmark_border_rounded,
                                  size: 40,
                                  color: AppTheme.textSecondaryOf(context)),
                            ),
                            const SizedBox(height: 16),
                            Text('No bookmarked events',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimaryOf(context))),
                            const SizedBox(height: 4),
                            Text(
                              'Bookmark events from cards or event details.',
                              style: TextStyle(
                                  color: AppTheme.textSecondaryOf(context)),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          controller: _scrollCtrl,
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: _events.length + (_loadingMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            if (index >= _events.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              );
                            }
                            final event = _events[index];
                            return EventCard(
                              event: event,
                              imageUrl: event.firstImageUrl,
                              onTap: () => context.push('/events/${event.id}'),
                              isBookmarked: true,
                              onBookmarkToggle: () => _removeBookmark(event.id),
                              isOrganizerOrAdmin: false,
                              myPledgeAmountCents: event.viewerPledgeAmountCents,
                              myTicketCount: event.viewerTicketCount,
                              showSponsorBadge: event.viewerIsSponsor,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  EventStatus _statusFromKey(String key) => switch (key) {
    'approved'           => EventStatus.approved,
    'selling_tickets'    => EventStatus.selling_tickets,
    'waiting_event_date' => EventStatus.waiting_event_date,
    'live'               => EventStatus.live,
    'completed'          => EventStatus.completed,
    'cancelled'          => EventStatus.cancelled,
    _                    => EventStatus.approved,
  };

  Widget _filterChip(String? value, String label, IconData icon, Color color) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AppChip(
        label: label,
        selected: selected,
        avatarIcon: icon,
        onSelected: (_) {
          setState(() => _statusFilter = value);
          _load();
        },
        chipColor: color,
        fontSize: 12,
        compact: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
