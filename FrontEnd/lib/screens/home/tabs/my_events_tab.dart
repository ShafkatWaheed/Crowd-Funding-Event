import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../home_shared.dart';
import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../models/event.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/animated_list_item.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/event_card.dart';
import '../../../widgets/shimmer_loaders.dart';

class MyEventsTab extends StatefulWidget {
  final Set<int> bookmarkedIds;
  final void Function(int) onToggleBookmark;
  final void Function(List<int>)? onBookmarksSynced;
  final List<String> genres;

  const MyEventsTab({
    super.key,
    required this.bookmarkedIds,
    required this.onToggleBookmark,
    this.onBookmarksSynced,
    required this.genres,
  });

  @override
  State<MyEventsTab> createState() => _MyEventsTabState();
}

class _MyEventsTabState extends State<MyEventsTab> {
  List<Event> _myEvents = [];
  bool _myEventsLoading = false;
  bool _myEventsLoadingMore = false;
  bool _myEventsHasMore = true;
  String _myEventsSearch = '';
  String? _myEventsGenre;
  String? _myEventsStatus;
  static const int _myEventsPageSize = 20;

  List<EventStatus> get _manageVisibleStatuses {
    final user = context.read<AuthProvider>().user;
    if (user != null && (user.isOrganizer || user.isAdmin)) {
      return EventStatus.values.toList();
    }
    return [
      EventStatus.approved,
      EventStatus.waiting_event_date,
      EventStatus.selling_tickets,
      EventStatus.live,
      EventStatus.completed,
      EventStatus.cancelled,
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMyEvents());
  }

  Future<void> _loadMyEvents() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    setState(() {
      _myEventsLoading = true;
      _myEventsHasMore = true;
    });
    try {
      final api = context.read<ApiService>();
      final data = await api.getMyEvents(offset: 0, limit: _myEventsPageSize);
      if (mounted) {
        final list = data.map((e) => Event.fromJson(e)).toList();
        setState(() {
          _myEvents = list;
          _myEventsHasMore = data.length >= _myEventsPageSize;
        });
        if (list.isNotEmpty) {
          _batchCheckBookmarks(list.map((e) => e.id).toList());
        }
      }
    } catch (e) {
      debugPrint('_loadMyEvents error: $e');
    }
    if (mounted) {
      setState(() => _myEventsLoading = false);
    }
  }

  Future<void> _batchCheckBookmarks(List<int> eventIds) async {
    if (eventIds.isEmpty) return;
    try {
      final api = context.read<ApiService>();
      final res = await api.checkBookmarks(eventIds);
      final ids = (res['bookmarked_ids'] as List?)?.cast<int>() ?? [];
      if (mounted) widget.onBookmarksSynced?.call(ids);
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _loadMoreMyEvents() async {
    if (_myEventsLoadingMore || !_myEventsHasMore) return;
    setState(() => _myEventsLoadingMore = true);
    try {
      final api = context.read<ApiService>();
      final data =
          await api.getMyEvents(offset: _myEvents.length, limit: _myEventsPageSize);
      if (mounted) {
        setState(() {
          _myEvents.addAll(data.map((e) => Event.fromJson(e)));
          _myEventsHasMore = data.length >= _myEventsPageSize;
        });
      }
    } catch (e) {
      debugPrint('_loadMoreMyEvents error: $e');
    }
    if (mounted) setState(() => _myEventsLoadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final filtered = _myEvents.where((e) {
      if (_myEventsGenre != null && e.genre != _myEventsGenre) return false;
      if (_myEventsStatus != null && e.status.name != _myEventsStatus) return false;
      if (_myEventsSearch.isNotEmpty) {
        final q = _myEventsSearch.toLowerCase();
        return (e.title.toLowerCase().contains(q)) ||
            (e.genre?.toLowerCase().contains(q) ?? false) ||
            (e.status.name.toLowerCase().contains(q));
      }
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardOf(context),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(AppRadius.xxlValue),
              bottomRight: Radius.circular(AppRadius.xxlValue),
            ),
            boxShadow: AppShadow.soft(isDark),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            56,
            AppSpacing.xxl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Manage',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceOf(context),
                      borderRadius: AppRadius.pill,
                    ),
                    child: Text(
                      '${_myEvents.length} event${_myEvents.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.vLg,
              Row(
                children: [
                  customerQuickAction(
                    context: context,
                    icon: Icons.confirmation_number_rounded,
                    label: 'My Tickets',
                    color: AppTheme.accentColor,
                    onTap: () => context.push('/my-tickets'),
                  ),
                  AppSpacing.hSm,
                  customerQuickAction(
                    context: context,
                    icon: Icons.volunteer_activism_rounded,
                    label: 'My Pledges',
                    color: context.sponsorAccent,
                    onTap: () => context.push('/my-pledges'),
                  ),
                ],
              ),
              AppSpacing.vLg,
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search my events\u2026',
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppTheme.textSecondaryOf(context),
                    size: AppIconSize.md,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: 14,
                  ),
                  filled: true,
                  fillColor: AppTheme.inputFillOf(context),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.md,
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _myEventsSearch = v),
              ),
              AppSpacing.vLg,
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.genres.map((g) {
                    final isActive = _myEventsGenre == g;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(g[0].toUpperCase() + g.substring(1)),
                        selected: isActive,
                        onSelected: (selected) {
                          setState(() => _myEventsGenre = selected ? g : null);
                        },
                        selectedColor: AppTheme.primaryColor,
                        backgroundColor: AppTheme.cardOf(context),
                        side: BorderSide(
                          color: isActive
                              ? AppTheme.primaryColor
                              : AppTheme.dividerOf(context),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.white
                              : AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              AppSpacing.vSm,
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _manageVisibleStatuses.map((s) {
                    final isActive = _myEventsStatus == s.name;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(statusDisplayName(s)),
                        selected: isActive,
                        onSelected: (selected) {
                          setState(() => _myEventsStatus = selected ? s.name : null);
                        },
                        selectedColor: statusChipColor(context, s),
                        backgroundColor: AppTheme.cardOf(context),
                        side: BorderSide(
                          color: isActive
                              ? statusChipColor(context, s)
                              : AppTheme.dividerOf(context),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              isActive ? Colors.white : AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _myEventsLoading && _myEvents.isEmpty
              ? SingleChildScrollView(child: ShimmerEventList(count: 3))
              : filtered.isEmpty
              ? EmptyState(
                  icon: Icons.event_busy_rounded,
                  title: _myEvents.isEmpty ? 'No events yet' : 'No matches',
                  subtitle: _myEvents.isEmpty
                      ? 'Events you register for will appear here'
                      : 'Try a different search term',
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollEndNotification &&
                        notification.metrics.pixels >=
                            notification.metrics.maxScrollExtent * 0.8 &&
                        !_myEventsLoadingMore &&
                        _myEventsHasMore) {
                      _loadMoreMyEvents();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    color: AppTheme.primaryColor,
                    onRefresh: _loadMyEvents,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        100,
                      ),
                      itemCount: filtered.length + (_myEventsLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= filtered.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final event = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: AnimatedListItem(
                            index: index,
                            child: EventCard(
                              event: event,
                              imageUrl: event.firstImageUrl,
                              onTap: () => context.push('/events/${event.id}'),
                              isBookmarked: widget.bookmarkedIds.contains(event.id),
                              onBookmarkToggle: () => widget.onToggleBookmark(event.id),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
