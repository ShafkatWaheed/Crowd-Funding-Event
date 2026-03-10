import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../home_shared.dart';
import '../../../config/app_icons.dart';
import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../models/event.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/event_provider.dart';
import '../../../widgets/animated_list_item.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/event_card.dart';
import '../../../widgets/app_chip.dart';
import '../../../widgets/shimmer_loaders.dart';

class MyEventsTab extends StatefulWidget {
  final Set<int> bookmarkedIds;
  final void Function(int) onToggleBookmark;
  final void Function(List<int>)? onBookmarksSynced;
  final List<String> genres;
  final Widget? headerIcons;

  const MyEventsTab({
    super.key,
    required this.bookmarkedIds,
    required this.onToggleBookmark,
    this.onBookmarksSynced,
    required this.genres,
    this.headerIcons,
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
  String _myEventsSortBy = 'newest';
  static const int _myEventsPageSize = 20;
  int? _loadedForUserId;
  int _lastRegistrationVersion = -1;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use Provider.of (listen: true) so this method re-fires when either
    // provider notifies — context.read() does NOT create a dependency.
    final userId = Provider.of<AuthProvider>(context).user?.id;
    final regVersion = Provider.of<EventProvider>(context).registrationVersion;

    if (userId != null && userId != _loadedForUserId) {
      // First load or user switched — load fresh.
      _loadedForUserId = userId;
      _lastRegistrationVersion = regVersion;
      _loadMyEvents();
    } else if (userId != null && regVersion != _lastRegistrationVersion) {
      // User registered or unregistered — silently refresh the list.
      _lastRegistrationVersion = regVersion;
      _loadMyEvents();
    }
  }

  Future<void> _loadMyEvents() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    _loadedForUserId = auth.user!.id;
    setState(() {
      _myEventsLoading = true;
      _myEventsHasMore = true;
    });
    try {
      final repo = context.read<EventProvider>();
      final data = await repo.getMyEvents(offset: 0, limit: _myEventsPageSize, sortBy: _myEventsSortBy);
      if (mounted) {
        setState(() {
          _myEvents = data;
          _myEventsHasMore = data.length >= _myEventsPageSize;
        });
        if (data.isNotEmpty) {
          _batchCheckBookmarks(data.map((e) => e.id).toList());
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
      final repo = context.read<EventProvider>();
      final res = await repo.checkBookmarks(eventIds);
      final ids = res.entries.where((e) => e.value).map((e) => e.key).toList();
      if (mounted) widget.onBookmarksSynced?.call(ids);
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _loadMoreMyEvents() async {
    if (_myEventsLoadingMore || !_myEventsHasMore) return;
    setState(() => _myEventsLoadingMore = true);
    try {
      final repo = context.read<EventProvider>();
      final data =
          await repo.getMyEvents(offset: _myEvents.length, limit: _myEventsPageSize, sortBy: _myEventsSortBy);
      if (mounted) {
        setState(() {
          _myEvents.addAll(data);
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
                  if (widget.headerIcons != null) ...[
                    AppSpacing.hSm,
                    widget.headerIcons!,
                  ],
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
              AppSpacing.vMd,
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Icon(Icons.sort_rounded, size: 16, color: AppTheme.textSecondaryOf(context)),
                    const SizedBox(width: 8),
                    ...{'newest': 'Newest', 'oldest': 'Oldest', 'name_az': 'Name A-Z', 'soonest': 'Soonest'}.entries.map((e) {
                      final isActive = _myEventsSortBy == e.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: AppChip(
                          label: e.value,
                          selected: isActive,
                          onSelected: (_) {
                            if (_myEventsSortBy != e.key) {
                              setState(() => _myEventsSortBy = e.key);
                              _loadMyEvents();
                            }
                          },
                          chipColor: AppTheme.accentColor,
                          fontSize: 12,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              AppSpacing.vSm,
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.genres.map((g) {
                    final isActive = _myEventsGenre == g;
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final genreColor = AppIcons.genreColor(g, isDark: isDark);
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: AppChip(
                        label: g[0].toUpperCase() + g.substring(1),
                        selected: isActive,
                        onSelected: (selected) {
                          setState(() => _myEventsGenre = selected ? g : null);
                        },
                        chipColor: genreColor,
                        avatarIcon: AppIcons.genreIcon(g),
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
                      child: AppChip(
                        label: statusDisplayName(s),
                        selected: isActive,
                        onSelected: (selected) {
                          setState(() => _myEventsStatus = selected ? s.name : null);
                        },
                        chipColor: statusChipColor(context, s),
                        avatarIcon: statusChipIcon(s),
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
