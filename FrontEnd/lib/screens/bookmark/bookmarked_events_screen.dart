import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../utils/date_time_utils.dart';
import '../../services/api_service.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/event_lifecycle_bar.dart';

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

  final _statusOptions = <String, String>{
    'approved': 'Funding',
    'selling_tickets': 'Selling Tickets',
    'waiting_event_date': 'Awaiting Date',
    'live': 'Live',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
  };

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
      final api = context.read<ApiService>();
      final data = await api.getBookmarkedEvents(
        search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
        status: _statusFilter,
        offset: 0,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _events = data.map((j) => Event.fromJson(j)).toList();
          _hasMore = data.length >= _pageSize;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ApiService.extractError(e));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getBookmarkedEvents(
        search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
        status: _statusFilter,
        offset: _events.length,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _events.addAll(data.map((j) => Event.fromJson(j)));
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
      final api = context.read<ApiService>();
      await api.toggleBookmark(eventId);
      if (mounted) {
        setState(() => _events.removeWhere((e) => e.id == eventId));
      }
    } catch (e) {
      if (mounted) AppToast.error(context, ApiService.extractError(e));
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
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _filterChip(null, 'All'),
                ..._statusOptions.entries
                    .map((e) => _filterChip(e.key, e.value)),
              ],
            ),
          ),
          const SizedBox(height: 10),
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
                            return _BookmarkCard(
                              event: event,
                              onTap: () =>
                                  context.push('/events/${event.id}'),
                              onRemove: () => _removeBookmark(event.id),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String? value, String label) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _statusFilter = value);
          _load();
        },
        selectedColor: AppTheme.accentColor,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppTheme.textPrimaryOf(context),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(
          color: selected
              ? AppTheme.accentColor
              : AppTheme.dividerOf(context),
        ),
      ),
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _BookmarkCard(
      {required this.event, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                gradient: _gradient(context, event.status),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EventLifecycleBar(event: event, compact: true),
                        const SizedBox(height: 6),
                        Text(
                          event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onRemove,
                    child: const Icon(Icons.bookmark_remove_rounded,
                        color: Colors.white70, size: 22),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (event.startTime != null)
                    _row(
                        context,
                        Icons.schedule_rounded,
                        AppDateFormat.eventCard(event.startTime!)),
                  if (event.venue != null) ...[
                    const SizedBox(height: 4),
                    _row(context, Icons.location_on_rounded,
                        '${event.venue!.name}, ${event.venue!.city}'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondaryOf(context)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondaryOf(context))),
        ),
      ],
    );
  }

  LinearGradient _gradient(BuildContext context, EventStatus s) {
    return switch (s) {
      EventStatus.live => LinearGradient(
          colors: [AppTheme.successColor, const Color(0xFF0A7544)]),
      EventStatus.selling_tickets => LinearGradient(
          colors: [context.statusSelling, const Color(0xFF00695C)]),
      EventStatus.completed => LinearGradient(
          colors: [context.statusCompleted, const Color(0xFF212121)]),
      EventStatus.cancelled => LinearGradient(
          colors: [context.statusCancelled, const Color(0xFF5D0000)]),
      _ => LinearGradient(
          colors: [AppTheme.darkSurface, const Color(0xFF2C2C2C)]),
    };
  }
}
