import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../config/app_icons.dart';
import '../../../config/app_typography.dart';
import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../db/app_database.dart';
import '../../../models/event.dart';
import '../../../models/venue.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/event_provider.dart';
import '../../../services/location_helper.dart';
import '../../../services/sync_service.dart';
import '../../../widgets/animated_list_item.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/kyc_required_banner.dart';
import '../../../widgets/event/event_card.dart';
import '../../../widgets/app_chip.dart';
import '../../../widgets/section_header.dart';
import '../home_shared.dart';

class HomeTab extends StatefulWidget {
  final Set<int> bookmarkedIds;
  final void Function(int) onToggleBookmark;
  final List<String> cities;
  final List<String> genres;
  final VoidCallback onRefresh;
  final Widget? headerIcons;

  const HomeTab({
    super.key,
    required this.bookmarkedIds,
    required this.onToggleBookmark,
    required this.cities,
    required this.genres,
    required this.onRefresh,
    this.headerIcons,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _homeSearchCtrl = TextEditingController();
  String? _homeGenre;
  String? _homeStatus;
  String? _homeCityFilter;
  bool _showFilters = false;
  List<Event> _homeSearchResults = [];
  bool get _isHomeFiltered =>
      _homeSearchCtrl.text.isNotEmpty ||
      _homeGenre != null ||
      _homeStatus != null ||
      _homeCityFilter != null;

  List<Event> _trending = [];
  List<Event> _popular = [];
  List<Event> _comingSoon = [];
  List<Event> _communityEvents = [];
  bool _featuredLoading = true;
  List<Event> _nearMeEvents = [];
  bool _nearMeAttempted = false;
  bool _isOffline = false;
  int _lastViewerDataVersion = -1;

  static const List<EventStatus> _visibleStatuses = [
    EventStatus.approved,
    EventStatus.waiting_event_date,
    EventStatus.selling_tickets,
    EventStatus.live,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectivity();
      _loadFeatured();
      _loadNearMe();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final version = Provider.of<EventProvider>(context).viewerDataVersion;
    if (_lastViewerDataVersion != -1 && version != _lastViewerDataVersion) {
      _loadFeatured();
    }
    _lastViewerDataVersion = version;
  }

  Future<void> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final offline = !results.any((r) => r != ConnectivityResult.none);
      if (mounted && offline != _isOffline) {
        setState(() => _isOffline = offline);
      }
    } catch (_) {
      // connectivity_plus not available on web — assume online
    }
  }

  @override
  void dispose() {
    _homeSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFeatured() async {
    try {
      final repo = context.read<EventProvider>();
      final auth = context.read<AuthProvider>();
      final isSponsor = auth.user != null &&
          auth.user!.isSponsor &&
          !(auth.user!.isOrganizer || auth.user!.isAdmin);
      final results = await Future.wait([
        repo.getFeaturedEvents(sponsorshipOnly: isSponsor),
        repo.getEvents(filters: EventFilters(
              communityRules: 'true',
              sponsorshipOnly: isSponsor ? true : null,
            )).then((r) {
          return r.items;
        }),
      ]);
      final data = results[0] as FeaturedEvents;
      final communityList = results[1] as List<Event>;
      if (mounted) {
        setState(() {
          _trending = data.trending;
          _popular = data.popular;
          _comingSoon = data.comingSoon;
          _communityEvents = communityList;
          _featuredLoading = false;
          _isOffline = false;
        });
        // Background: cache fetched events into local SQLite
        _cacheEventsLocally();
      }
    } catch (_) {
      if (mounted) {
        // API failed — try loading from local SQLite cache
        await _loadFromLocalCache();
        setState(() => _featuredLoading = false);
      }
    }
  }

  Future<void> _loadFromLocalCache() async {
    try {
      final db = context.read<AppDatabase>();
      final cached = await db.getAllCachedEvents();
      if (cached.isEmpty || !mounted) return;
      final events = cached.map(_cachedRowToEvent).toList();
      setState(() {
        _trending = events.take(10).toList();
        _isOffline = true;
      });
    } catch (e) {
      debugPrint('HomeTab._loadFromLocalCache failed: $e');
    }
  }

  Event _cachedRowToEvent(CachedEvent row) {
    return Event(
      id: row.id,
      organizerId: 0,
      venueId: 0,
      title: row.title,
      description: row.description,
      genre: row.genre,
      status: _parseEventStatus(row.status),
      startTime: row.startTime,
      endTime: row.endTime,
      firstImageUrl: row.firstImageUrl,
      minPledgeCents: 0,
      registrationType: RegistrationType.open,
      maxCapacity: 0,
      commonDiscountPercent: 0,
      pledgeDiscountPercent: 0,
      createdAt: row.syncedAt,
      venue: row.venueName != null
          ? Venue(
              id: 0,
              name: row.venueName!,
              address: '',
              city: row.city ?? '',
              lat: row.lat,
              lng: row.lng,
              maxCapacity: 0,
            )
          : null,
      fundingGoalCents: row.fundingGoalCents,
      totalPledgedCents: row.totalPledgedCents,
      ticketsSoldCount: row.ticketsSoldCount ?? 0,
    );
  }

  EventStatus _parseEventStatus(String status) {
    return EventStatus.values.firstWhere(
      (s) => s.name == status,
      orElse: () => EventStatus.approved,
    );
  }

  /// Cache displayed events into SQLite for offline access.
  Future<void> _cacheEventsLocally() async {
    try {
      final syncService = context.read<SyncService>();
      await syncService.pullEvents();
    } catch (e) {
      debugPrint('HomeTab._cacheEventsLocally failed: $e');
    }
  }

  Future<void> _loadNearMe() async {
    if (_nearMeAttempted) return;
    setState(() => _nearMeAttempted = true);
    try {
      final pos = await LocationHelper.getCurrentPosition();
      if (pos == null || !mounted) return;
      final repo = context.read<EventProvider>();
      final auth = context.read<AuthProvider>();
      final isSponsor = auth.user != null &&
          auth.user!.isSponsor &&
          !(auth.user!.isOrganizer || auth.user!.isAdmin);
      final data = await repo.getMapEvents(
        lat: pos.latitude,
        lng: pos.longitude,
        radiusKm: 25,
      );
      if (mounted) {
        final ids =
            data.map((e) => e.id).take(10).toList();
        if (ids.isNotEmpty) {
          final fullEvents = <Event>[];
          final result = await repo.getEvents(filters: EventFilters(
            sponsorshipOnly: isSponsor ? true : null,
          ));
          final allEvents = result.items;
          for (final ev in allEvents) {
            if (ids.contains(ev.id)) fullEvents.add(ev);
          }
          setState(() => _nearMeEvents = fullEvents);
        }
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  void _homeSearch() {
    if (!_isHomeFiltered) {
      setState(() => _homeSearchResults = []);
      return;
    }
    if (_isOffline && _homeSearchCtrl.text.trim().isNotEmpty) {
      _offlineSearch(_homeSearchCtrl.text.trim());
      return;
    }
    final seen = <int>{};
    final allEvents = <Event>[];
    for (final list in [
      _nearMeEvents,
      _trending,
      _comingSoon,
      _popular,
      _communityEvents,
    ]) {
      for (final e in list) {
        if (seen.add(e.id)) allEvents.add(e);
      }
    }
    final query = _homeSearchCtrl.text.trim().toLowerCase();
    final results = allEvents.where((e) {
      if (query.isNotEmpty) {
        final match = e.title.toLowerCase().contains(query) ||
            (e.description?.toLowerCase().contains(query) ?? false) ||
            (e.genre?.toLowerCase().contains(query) ?? false);
        if (!match) return false;
      }
      if (_homeGenre != null && e.genre != _homeGenre) return false;
      if (_homeStatus != null && e.status.name != _homeStatus) return false;
      if (_homeCityFilter != null && e.venue?.city != _homeCityFilter) {
        return false;
      }
      return true;
    }).toList();
    setState(() => _homeSearchResults = results);
  }

  Future<void> _offlineSearch(String query) async {
    try {
      final db = context.read<AppDatabase>();
      final cached = await db.searchEvents(query);
      if (!mounted) return;
      final events = cached.map(_cachedRowToEvent).toList();
      setState(() => _homeSearchResults = events);
    } catch (e) {
      debugPrint('HomeTab._offlineSearch failed: $e');
    }
  }

  void _clearHomeSearch() {
    setState(() {
      _homeSearchCtrl.clear();
      _homeGenre = null;
      _homeStatus = null;
      _homeCityFilter = null;
      _homeSearchResults = [];
    });
  }

  Widget _buildFeaturedSection(
    String title,
    IconData icon,
    List<Event> items,
    int sectionIndex,
  ) {
    return SliverToBoxAdapter(
      child: AnimatedListItem(
        index: sectionIndex,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xxl,
                bottom: AppSpacing.md,
              ),
              child: SectionHeader(
                title: title,
                icon: icon,
                actionLabel: 'See all',
                onAction: () => context.go('/?tab=explore'),
              ),
            ),
            SizedBox(
              height: 330,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final event = items[index];
                  return Container(
                    width: 280,
                    margin: const EdgeInsets.only(right: AppSpacing.md),
                    child: EventCard(
                      event: event,
                      imageUrl: event.firstImageUrl,
                      onTap: () => context.push('/events/${event.id}'),
                      isBookmarked: widget.bookmarkedIds.contains(event.id),
                      onBookmarkToggle: () =>
                          widget.onToggleBookmark(event.id),
                      isOrganizerOrAdmin: false,
                      myPledgeAmountCents: event.viewerPledgeAmountCents,
                      myTicketCount: event.viewerTicketCount,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final isDark = AppTheme.isDark(context);

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        await _loadFeatured();
        widget.onRefresh();
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
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
                AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: AppRadius.md,
                        ),
                        child: Center(
                          child: Text(
                            user != null
                                ? user.displayLabel[0].toUpperCase()
                                : 'C',
                            style: AppTypography.headlineLarge.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      AppSpacing.hLg,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back',
                              style: AppTypography.caption.copyWith(
                                color: AppTheme.textSecondaryOf(context),
                              ),
                            ),
                            Text(
                              user?.displayLabel ?? 'Guest',
                              style: AppTypography.headlineLarge.copyWith(
                                letterSpacing: -0.5,
                                color: AppTheme.textPrimaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.headerIcons != null) widget.headerIcons!,
                    ],
                  )
                      .animate()
                      .fadeIn(
                        duration: AppDuration.normal,
                        curve: AppCurve.enter,
                      )
                      .slideX(
                        begin: -0.05,
                        end: 0,
                        duration: AppDuration.normal,
                        curve: AppCurve.enter,
                      ),
                  AppSpacing.vXxl,
                  TextField(
                    controller: _homeSearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search events, venues, genres...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppTheme.textSecondaryOf(context),
                        size: AppIconSize.md,
                      ),
                      suffixIcon: _homeSearchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                size: AppIconSize.md,
                              ),
                              onPressed: _clearHomeSearch,
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.inputFillOf(context),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.md,
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.lg,
                      ),
                    ),
                    onChanged: (_) => _homeSearch(),
                    onSubmitted: (_) => _homeSearch(),
                  ),
                  AppSpacing.vXl,
                  SizedBox(
                    height: AppSpacing.chipRowHeight,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ..._visibleStatuses.map((s) {
                          final isActive = _homeStatus == s.name;
                          return Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.sm),
                            child: AppChip(
                              label: statusDisplayName(s),
                              selected: isActive,
                              onSelected: (selected) {
                                setState(
                                    () => _homeStatus = selected ? s.name : null);
                                _homeSearch();
                              },
                              chipColor: statusChipColor(context, s),
                              avatarIcon: statusChipIcon(s),
                            ),
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ActionChip(
                            avatar: Icon(
                              _showFilters
                                  ? Icons.filter_list_off_rounded
                                  : Icons.filter_list_rounded,
                              size: AppIconSize.sm,
                            ),
                            label: Text('Filters', style: AppTypography.chip),
                            side: BorderSide(
                              color: _showFilters
                                  ? AppTheme.accentColor
                                  : AppTheme.dividerOf(context),
                            ),
                            backgroundColor: _showFilters
                                ? AppTheme.accentColor.withValues(alpha: 0.12)
                                : AppTheme.cardOf(context),
                            onPressed: () =>
                                setState(() => _showFilters = !_showFilters),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Column(
                      children: [
                        AppSpacing.vSm,
                        SizedBox(
                          height: AppSpacing.chipRowHeight,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: widget.genres.map((g) {
                              final isActive = _homeGenre == g;
                              final isDark =
                                  Theme.of(context).brightness == Brightness.dark;
                              final genreColor =
                                  AppIcons.genreColor(g, isDark: isDark);
                              return Padding(
                                padding:
                                    const EdgeInsets.only(right: AppSpacing.sm),
                                child: AppChip(
                                  label: g[0].toUpperCase() + g.substring(1),
                                  selected: isActive,
                                  onSelected: (selected) {
                                    setState(
                                        () => _homeGenre = selected ? g : null);
                                    _homeSearch();
                                  },
                                  chipColor: genreColor,
                                  avatarIcon: AppIcons.genreIcon(g),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        if (widget.cities.isNotEmpty) ...[
                          AppSpacing.vSm,
                          SizedBox(
                            height: AppSpacing.chipRowHeight,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.only(right: AppSpacing.sm),
                                  child: ChoiceChip(
                                    label: const Text('All Cities'),
                                    selected: _homeCityFilter == null,
                                    onSelected: (_) {
                                      setState(() => _homeCityFilter = null);
                                      _homeSearch();
                                    },
                                    selectedColor: AppTheme.accentColor,
                                    backgroundColor: AppTheme.cardOf(context),
                                    side: BorderSide(
                                      color: _homeCityFilter == null
                                          ? AppTheme.accentColor
                                          : AppTheme.dividerOf(context),
                                    ),
                                    labelStyle: AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _homeCityFilter == null
                                          ? Colors.white
                                          : AppTheme.textPrimaryOf(context),
                                    ),
                                  ),
                                ),
                                ...widget.cities.map((c) {
                                  final isActive = _homeCityFilter == c;
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        right: AppSpacing.sm),
                                    child: ChoiceChip(
                                      label: Text(c),
                                      selected: isActive,
                                      onSelected: (selected) {
                                        setState(() => _homeCityFilter =
                                            selected ? c : null);
                                        _homeSearch();
                                      },
                                      selectedColor: AppTheme.accentColor,
                                      backgroundColor: AppTheme.cardOf(context),
                                      side: BorderSide(
                                        color: isActive
                                            ? AppTheme.accentColor
                                            : AppTheme.dividerOf(context),
                                      ),
                                      labelStyle: AppTypography.caption.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isActive
                                            ? Colors.white
                                            : AppTheme.textPrimaryOf(context),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    crossFadeState: _showFilters
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: AppDuration.normal,
                  ),
                ],
              ),
            ),
          ),

          if (_isOffline)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.warningSurfaceOf(context),
                  borderRadius: AppRadius.md,
                  border: Border.all(
                      color: AppTheme.warningColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        size: AppIconSize.md, color: AppTheme.warningColor),
                    AppSpacing.hMd,
                    Expanded(
                      child: Text(
                        'You\'re offline — showing cached events',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (user != null && user.kycStatus != 'verified' && !user.isAdmin)
            const SliverToBoxAdapter(
              child: KycRequiredBanner(action: 'purchase tickets and register for events'),
            ),

          if (_isHomeFiltered) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list_rounded,
                      size: AppIconSize.sm,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                    AppSpacing.hSm,
                    Expanded(
                      child: Text(
                        [
                          if (_homeSearchCtrl.text.isNotEmpty)
                            '"${_homeSearchCtrl.text}"',
                          if (_homeGenre != null)
                            _homeGenre![0].toUpperCase() +
                                _homeGenre!.substring(1),
                          if (_homeCityFilter != null) _homeCityFilter!,
                        ].join(' in '),
                        style: AppTypography.titleSmall.copyWith(
                          letterSpacing: -0.2,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _clearHomeSearch,
                      child: Text(
                        'Clear',
                        style: AppTypography.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_homeSearchResults.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No events found',
                  subtitle: 'Try a different search or filter',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 330,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final event = _homeSearchResults[i];
                      return AnimatedListItem(
                        index: i,
                        child: EventCard(
                          event: event,
                          imageUrl: event.firstImageUrl,
                          onTap: () => context.push('/events/${event.id}'),
                          isBookmarked: widget.bookmarkedIds.contains(event.id),
                          onBookmarkToggle: () =>
                              widget.onToggleBookmark(event.id),
                          isOrganizerOrAdmin: false,
                          myPledgeAmountCents: event.viewerPledgeAmountCents,
                          myTicketCount: event.viewerTicketCount,
                        ),
                      );
                    },
                    childCount: _homeSearchResults.length,
                  ),
                ),
              ),
          ] else ...[
            if (_nearMeEvents.isNotEmpty)
              _buildFeaturedSection(
                  'Near Me', Icons.near_me_rounded, _nearMeEvents, 0),
            if (!_featuredLoading) ...[
              if (_trending.isEmpty &&
                  _popular.isEmpty &&
                  _comingSoon.isEmpty &&
                  _communityEvents.isEmpty &&
                  _nearMeEvents.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xxl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_busy_rounded,
                            size: 48,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No events to show right now',
                            style: TextStyle(
                              color: AppTheme.textSecondaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _loadFeatured,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                if (_trending.isNotEmpty)
                  _buildFeaturedSection(
                    'Trending Now',
                    Icons.local_fire_department_rounded,
                    _trending,
                    1,
                  ),
                if (_comingSoon.isNotEmpty)
                  _buildFeaturedSection(
                    'Coming Soon',
                    Icons.upcoming_rounded,
                    _comingSoon,
                    2,
                  ),
                if (_popular.isNotEmpty)
                  _buildFeaturedSection(
                    'Most Popular',
                    Icons.star_rounded,
                    _popular,
                    3,
                  ),
                if (_communityEvents.isNotEmpty)
                  _buildFeaturedSection(
                    'Community Events',
                    Icons.groups_rounded,
                    _communityEvents,
                    4,
                  ),
              ],
            ],
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
