import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';
import '../notification/notification_screen.dart';
import '../../services/api_service.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/event_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/event_map_widget.dart';
import '../../widgets/press_feedback.dart';
import '../../services/location_helper.dart';
import '../legal/terms_screen.dart';

String _statusDisplayName(EventStatus s) {
  switch (s) {
    case EventStatus.draft:
      return 'Draft';
    case EventStatus.pending_approval:
      return 'Under Review';
    case EventStatus.approved:
      return 'Funding';
    case EventStatus.selling_tickets:
      return 'Selling Tickets';
    case EventStatus.waiting_event_date:
      return 'Awaiting Date';
    case EventStatus.live:
      return 'Live';
    case EventStatus.completed:
      return 'Completed';
    case EventStatus.cancelled:
      return 'Cancelled';
  }
}

Color _statusChipColor(EventStatus s) {
  switch (s) {
    case EventStatus.approved:
      return const Color(0xFF276EF1);
    case EventStatus.selling_tickets:
      return const Color(0xFF05944F);
    case EventStatus.live:
      return const Color(0xFFE11900);
    case EventStatus.completed:
      return const Color(0xFF7356BF);
    case EventStatus.cancelled:
      return const Color(0xFF8B0000);
    case EventStatus.draft:
      return const Color(0xFF757575);
    case EventStatus.pending_approval:
      return const Color(0xFFE65100);
    case EventStatus.waiting_event_date:
      return const Color(0xFF00838F);
  }
}

class HomeScreen extends StatefulWidget {
  final int initialTab;
  const HomeScreen({super.key, this.initialTab = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _navIndex;
  final _searchController = TextEditingController();
  String? _selectedStatus;
  String? _selectedRegType;
  String? _selectedGenre;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool? _hasFunding;
  bool _showAdvanced = false;
  bool _showMapView = false;

  // Near Me
  List<Event> _nearMeEvents = [];
  bool _nearMeAttempted = false;

  // Bookmarks — batch-checked once per event list load
  final Set<int> _bookmarkedIds = {};

  Future<void> _batchCheckBookmarks(List<int> eventIds) async {
    if (eventIds.isEmpty) return;
    try {
      final api = context.read<ApiService>();
      final res = await api.checkBookmarks(eventIds);
      final ids = (res['bookmarked_ids'] as List?)?.cast<int>() ?? [];
      if (mounted) setState(() {
        _bookmarkedIds.addAll(ids);
      });
    } catch (_) {}
  }

  Future<void> _toggleBookmark(int eventId) async {
    try {
      final api = context.read<ApiService>();
      final res = await api.toggleBookmark(eventId);
      if (mounted) {
        setState(() {
          if (res['bookmarked'] == true) {
            _bookmarkedIds.add(eventId);
          } else {
            _bookmarkedIds.remove(eventId);
          }
        });
      }
    } catch (_) {}
  }

  final List<String> _genres = [
    'community', 'music', 'tech', 'sports', 'arts',
    'food', 'charity', 'education', 'business', 'other',
  ];

  List<EventStatus> get _visibleStatuses {
    final user = context.read<AuthProvider>().user;
    if (user != null && (user.isOrganizer || user.isAdmin)) {
      return EventStatus.values.toList();
    }
    return [
      EventStatus.approved,
      EventStatus.waiting_event_date,
      EventStatus.selling_tickets,
      EventStatus.live,
    ];
  }

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

  // Home tab search
  final _homeSearchCtrl = TextEditingController();
  String? _homeGenre;
  String? _homeStatus;
  List<Event> _homeSearchResults = [];
  bool _homeSearching = false;
  bool get _isHomeFiltered =>
      _homeSearchCtrl.text.isNotEmpty || _homeGenre != null || _homeStatus != null;

  // Featured sections
  List<Event> _trending = [];
  List<Event> _popular = [];
  List<Event> _comingSoon = [];
  List<Event> _communityEvents = [];
  bool _featuredLoading = true;

  // My registered events
  List<Event> _myEvents = [];
  // ignore: unused_field
  bool _myEventsLoading = false;
  bool _myEventsLoadingMore = false;
  bool _myEventsHasMore = true;
  String _myEventsSearch = '';
  String? _myEventsGenre;
  String? _myEventsStatus;
  static const int _myEventsPageSize = 20;

  // Sponsor bid events
  List<_SponsorBidEvent> _sponsorBidEvents = [];
  bool _sponsorBidEventsLoading = false;
  String _sponsorBidSearch = '';
  String? _sponsorBidStatus;

  // Cache timestamps for tab data staleness checks
  DateTime? _myEventsLoadedAt;
  DateTime? _sponsorBidLoadedAt;
  DateTime? _featuredLoadedAt;
  static const Duration _tabCacheTtl = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    _navIndex = widget.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFilters();
      _loadFeatured();
      _loadMyEvents();
      _loadSponsorBidEvents();
      _loadNearMe();
      final ep = context.read<EventProvider>();
      ep.addListener(_onEventsChanged);
    });
  }

  void _onEventsChanged() {
    final ep = context.read<EventProvider>();
    final ids = ep.events.map((e) => e.id).toList();
    _batchCheckBookmarks(ids);
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() => _navIndex = widget.initialTab);
    }
  }

  Future<void> _loadMyEvents() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    setState(() { _myEventsLoading = true; _myEventsHasMore = true; });
    try {
      final api = context.read<ApiService>();
      final data = await api.getMyEvents(offset: 0, limit: _myEventsPageSize);
      if (mounted) {
        final list = data.map((e) => Event.fromJson(e)).toList();
        setState(() {
          _myEvents = list;
          _myEventsHasMore = data.length >= _myEventsPageSize;
        });
        _batchCheckBookmarks(list.map((e) => e.id).toList());
      }
    } catch (e) {
      debugPrint('_loadMyEvents error: $e');
    }
    if (mounted) {
      _myEventsLoadedAt = DateTime.now();
      setState(() => _myEventsLoading = false);
    }
  }

  Future<void> _loadMoreMyEvents() async {
    if (_myEventsLoadingMore || !_myEventsHasMore) return;
    setState(() => _myEventsLoadingMore = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getMyEvents(offset: _myEvents.length, limit: _myEventsPageSize);
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

  Future<void> _loadSponsorBidEvents() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null || !auth.user!.isSponsor) return;
    setState(() => _sponsorBidEventsLoading = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getSponsorBidEvents();
      if (mounted) {
        setState(() {
          _sponsorBidEvents = data.map((e) {
            final summary = (e['bid_summary'] as Map<String, dynamic>?) ?? {};
            return _SponsorBidEvent(
              event: Event.fromJson(e),
              pending: summary['pending'] ?? 0,
              accepted: summary['accepted'] ?? 0,
              rejected: summary['rejected'] ?? 0,
              paid: summary['paid'] ?? 0,
            );
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('_loadSponsorBidEvents error: $e');
    }
    if (mounted) {
      _sponsorBidLoadedAt = DateTime.now();
      setState(() => _sponsorBidEventsLoading = false);
    }
  }

  Future<void> _loadFeatured() async {
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.getFeaturedEvents(),
        api.dio.get('/events', queryParameters: {'community_rules': 'true'}).then((r) => r.data as List),
      ]);
      final data = results[0] as Map<String, dynamic>;
      final communityList = results[1] as List;
      setState(() {
        _trending = (data['trending'] as List? ?? [])
            .map((e) => Event.fromJson(e))
            .toList();
        _popular = (data['popular'] as List? ?? [])
            .map((e) => Event.fromJson(e))
            .toList();
        _comingSoon = (data['coming_soon'] as List? ?? [])
            .map((e) => Event.fromJson(e))
            .toList();
        _communityEvents = communityList
            .map((e) => Event.fromJson(e))
            .toList();
        _featuredLoading = false;
        _featuredLoadedAt = DateTime.now();
      });
    } catch (_) {
      setState(() => _featuredLoading = false);
    }
  }

  bool _isStale(DateTime? loadedAt) {
    return loadedAt == null || DateTime.now().difference(loadedAt) > _tabCacheTtl;
  }

  void _refreshStaleTabData(int tabIndex) {
    final user = context.read<AuthProvider>().user;
    if (tabIndex == 0 && _isStale(_featuredLoadedAt)) {
      _loadFeatured();
    }
    if (tabIndex == 2) {
      if (user != null && user.isCustomer && _isStale(_myEventsLoadedAt)) {
        _loadMyEvents();
      }
      if (user != null && user.isSponsor && _isStale(_sponsorBidLoadedAt)) {
        _loadSponsorBidEvents();
      }
    }
  }

  Future<void> _loadNearMe() async {
    if (_nearMeAttempted) return;
    setState(() {
      _nearMeAttempted = true;
    });
    try {
      final pos = await LocationHelper.getCurrentPosition();
      if (pos == null || !mounted) {
        return;
      }
      final api = context.read<ApiService>();
      final data = await api.getMapEvents(
        lat: pos.latitude,
        lng: pos.longitude,
        radiusKm: 25,
      );
      if (mounted) {
        // Convert map markers to full events by fetching them
        // For now we'll use the limited data and fetch full events
        final ids = data
            .map((e) => e['id'] as int)
            .take(10)
            .toList();
        if (ids.isNotEmpty) {
          final fullEvents = <Event>[];
          final allEvents = await api.getEvents();
          for (final e in allEvents) {
            final ev = Event.fromJson(e);
            if (ids.contains(ev.id)) fullEvents.add(ev);
          }
          setState(() => _nearMeEvents = fullEvents);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    context.read<EventProvider>().removeListener(_onEventsChanged);
    _searchController.dispose();
    _homeSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _homeSearch() async {
    if (!_isHomeFiltered) {
      setState(() => _homeSearchResults = []);
      return;
    }
    setState(() => _homeSearching = true);
    try {
      final api = context.read<ApiService>();
      final params = <String, dynamic>{};
      if (_homeSearchCtrl.text.isNotEmpty) {
        params['search'] = _homeSearchCtrl.text;
      }
      if (_homeGenre != null) {
        params['genre'] = _homeGenre;
      }
      if (_homeStatus != null) {
        params['status'] = _homeStatus;
      }
      final data = await api.getEvents(params: params);
      final results = data.map((e) => Event.fromJson(e)).toList();
      setState(() => _homeSearchResults = results);
      _batchCheckBookmarks(results.map((e) => e.id).toList());
    } catch (_) {}
    setState(() => _homeSearching = false);
  }

  void _clearHomeSearch() {
    setState(() {
      _homeSearchCtrl.clear();
      _homeGenre = null;
      _homeStatus = null;
      _homeSearchResults = [];
    });
  }

  void _applyFilters() {
    final filters = <String, dynamic>{};
    if (_searchController.text.isNotEmpty) {
      filters['search'] = _searchController.text;
    }
    if (_selectedStatus != null) filters['status'] = _selectedStatus;
    if (_selectedRegType != null) {
      filters['registration_type'] = _selectedRegType;
    }
    if (_dateFrom != null) {
      filters['date_from'] = _dateFrom!.toIso8601String();
    }
    if (_dateTo != null) {
      filters['date_to'] = _dateTo!.toIso8601String();
    }
    if (_hasFunding != null) {
      filters['has_funding'] = _hasFunding;
    }
    if (_selectedGenre != null) {
      filters['genre'] = _selectedGenre;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user != null && (user.isOrganizer || user.isAdmin)) {
      filters['include_all_statuses'] = true;
    }
    // Organizers see only their own events on Explore
    if (user != null && user.isOrganizer) {
      filters['organizer_id'] = user.id;
    }

    context.read<EventProvider>().loadEvents(filters: filters);
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedStatus = null;
      _selectedRegType = null;
      _selectedGenre = null;
      _dateFrom = null;
      _dateTo = null;
      _hasFunding = null;
    });
    _applyFilters();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      body: IndexedStack(
        index: _navIndex,
        children: [
          _buildHomeTab(),
          _buildExploreTab(),
          if (user != null && (user.isOrganizer || user.isAdmin))
            _buildManageTab()
          else if (user != null && user.isSponsor)
            _buildSponsorManageTab()
          else
            _buildMyEventsTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          boxShadow: AppShadow.bottomBar(isDark),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                _navItem(1, Icons.explore_rounded, Icons.explore_outlined, 'Explore'),
                if (user != null && (user.isOrganizer || user.isAdmin))
                  _navItem(2, Icons.dashboard_rounded, Icons.dashboard_outlined, 'Manage')
                else
                  _navItem(2, Icons.dashboard_rounded, Icons.dashboard_outlined, 'Manage'),
                _navItem(3, Icons.person_rounded, Icons.person_outline, 'Profile'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton:
          user != null && (user.isOrganizer || user.isAdmin) && _navIndex != 3
              ? PressFeedback(
                  child: FloatingActionButton(
                    onPressed: () async {
                      final created = await context.push<bool>('/events/create');
                      if (created == true && mounted) {
                        _applyFilters();
                        _loadFeatured();
                      }
                    },
                    backgroundColor: AppTheme.accentColor,
                    child: const Icon(Icons.add, color: Colors.white, size: AppIconSize.xl),
                  ),
                )
              : null,
    );
  }

  Widget _navItem(int index, IconData activeIcon, IconData icon, String label) {
    final isActive = _navIndex == index;
    return GestureDetector(
      onTap: () {
        if (_navIndex == index) return;
        setState(() => _navIndex = index);
        const tabNames = ['home', 'explore', 'manage', 'profile'];
        final tab = tabNames[index];
        context.go(tab == 'home' ? '/' : '/?tab=$tab');
        _refreshStaleTabData(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppDuration.normal,
        curve: AppCurve.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: isActive
            ? BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.12),
                borderRadius: AppRadius.md,
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: AppIconSize.lg,
              color: isActive ? AppTheme.accentColor : AppTheme.textSecondaryOf(context),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppTheme.accentColor : AppTheme.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // TAB 0: HOME — greeting + featured sections
  // ════════════════════════════════════════════

  Widget _buildHomeTab() {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isDark = AppTheme.isDark(context);

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        await Future.wait([_loadFeatured(), _loadMyEvents()]);
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
                AppSpacing.xxl, 56, AppSpacing.xxl, AppSpacing.xxl,
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
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
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondaryOf(context),
                                  fontWeight: FontWeight.w500),
                            ),
                            Text(
                              user?.displayLabel ?? 'Guest',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: AppTheme.textPrimaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Consumer<NotificationProvider>(
                        builder: (ctx, notifProv, _) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const NotificationScreen(),
                              ));
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceOf(context),
                                borderRadius: AppRadius.md,
                              ),
                              child: Badge(
                                isLabelVisible: notifProv.unreadCount > 0,
                                label: Text(
                                  notifProv.unreadCount > 99 ? '99+' : '${notifProv.unreadCount}',
                                  style: const TextStyle(fontSize: 10, color: Colors.white),
                                ),
                                backgroundColor: AppTheme.errorColor,
                                child: Icon(Icons.notifications_outlined,
                                    color: AppTheme.textPrimaryOf(context)),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(duration: AppDuration.normal, curve: AppCurve.enter)
                      .slideX(begin: -0.05, end: 0, duration: AppDuration.normal, curve: AppCurve.enter),
                  AppSpacing.vXxl,
                  TextField(
                    controller: _homeSearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search events, venues, genres...',
                      prefixIcon: Icon(Icons.search,
                          color: AppTheme.textSecondaryOf(context), size: AppIconSize.md),
                      suffixIcon: _homeSearchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: AppIconSize.md),
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
                          horizontal: AppSpacing.lg, vertical: 14),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _homeSearch(),
                  ),
                  AppSpacing.vXl,
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _genres.map((g) {
                        final isActive = _homeGenre == g;
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(g[0].toUpperCase() + g.substring(1)),
                            selected: isActive,
                            onSelected: (selected) {
                              setState(() {
                                _homeGenre = selected ? g : null;
                              });
                              _homeSearch();
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
                              color: isActive ? Colors.white : AppTheme.textPrimaryOf(context),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  AppSpacing.vSm,
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _visibleStatuses.map((s) {
                        final isActive = _homeStatus == s.name;
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(_statusDisplayName(s)),
                            selected: isActive,
                            onSelected: (selected) {
                              setState(() {
                                _homeStatus = selected ? s.name : null;
                              });
                              _homeSearch();
                            },
                            selectedColor: _statusChipColor(s),
                            backgroundColor: AppTheme.cardOf(context),
                            side: BorderSide(
                              color: isActive
                                  ? _statusChipColor(s)
                                  : AppTheme.dividerOf(context),
                            ),
                            labelStyle: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isActive ? Colors.white : AppTheme.textPrimaryOf(context),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isHomeFiltered) ...[
            SliverToBoxAdapter(
                child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl, AppSpacing.xl, AppSpacing.xxl, AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.filter_list_rounded,
                        size: AppIconSize.sm, color: AppTheme.textSecondaryOf(context)),
                    AppSpacing.hSm,
                    Expanded(
                      child: Text(
                        [
                          if (_homeSearchCtrl.text.isNotEmpty)
                            '"${_homeSearchCtrl.text}"',
                          if (_homeGenre != null)
                            _homeGenre![0].toUpperCase() +
                                _homeGenre!.substring(1),
                        ].join(' in '),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _clearHomeSearch,
                      child: const Text('Clear',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
            if (_homeSearching)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.huge),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_homeSearchResults.isEmpty)
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
                    mainAxisExtent: 320,
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
                          isBookmarked: _bookmarkedIds.contains(event.id),
                          onBookmarkToggle: () => _toggleBookmark(event.id),
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
              if (_trending.isNotEmpty)
                _buildFeaturedSection('Trending Now',
                    Icons.local_fire_department_rounded, _trending, 1),
              if (_comingSoon.isNotEmpty)
                _buildFeaturedSection(
                    'Coming Soon', Icons.upcoming_rounded, _comingSoon, 2),
              if (_popular.isNotEmpty)
                _buildFeaturedSection(
                    'Most Popular', Icons.star_rounded, _popular, 3),
              if (_communityEvents.isNotEmpty)
                _buildFeaturedSection(
                    'Community Events', Icons.groups_rounded, _communityEvents, 4),
            ],
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // TAB 1: EXPLORE — search + grid
  // ════════════════════════════════════════════

  Widget _buildExploreTab() {
    final auth = context.watch<AuthProvider>();
    final events = context.watch<EventProvider>();
    final user = auth.user;
    final isDark = AppTheme.isDark(context);
    final dateFmt = DateFormat('MMM d');

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >= notification.metrics.maxScrollExtent * 0.8 &&
            !events.isLoadingMore && events.hasMore && !events.isLoading) {
          events.loadMoreEvents();
        }
        return false;
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
              AppSpacing.xl, 56, AppSpacing.xl, AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user != null && user.isOrganizer
                            ? 'My Events'
                            : 'Explore',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppTheme.textPrimaryOf(context)),
                      ),
                    ),
                    if (user != null && user.isOrganizer)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.1),
                          borderRadius: AppRadius.pill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_rounded,
                                size: AppIconSize.sm, color: AppTheme.accentColor),
                            AppSpacing.hXs,
                            Text('Organizer View',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.accentColor)),
                          ],
                        ),
                      ),
                  ],
                ),
                AppSpacing.vMd,
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search events...',
                    prefixIcon:
                        Icon(Icons.search, color: AppTheme.textSecondaryOf(context)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: AppIconSize.md),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.inputFillOf(context),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.md,
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: 14),
                  ),
                  onSubmitted: (_) => _applyFilters(),
                ),
                AppSpacing.vSm,
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _visibleStatuses.map((s) {
                            final isActive = _selectedStatus == s.name;
                            return Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
                              child: ChoiceChip(
                                label: Text(_statusDisplayName(s)),
                                selected: isActive,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedStatus = selected ? s.name : null;
                                  });
                                  _applyFilters();
                                },
                                selectedColor: _statusChipColor(s),
                                backgroundColor: AppTheme.cardOf(context),
                                side: BorderSide(
                                  color: isActive
                                      ? _statusChipColor(s)
                                      : AppTheme.dividerOf(context),
                                ),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isActive ? Colors.white : AppTheme.textPrimaryOf(context),
                                ),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    AppSpacing.hSm,
                    Container(
                      height: 34,
                      width: 34,
                      decoration: BoxDecoration(
                        color: _showAdvanced
                            ? AppTheme.primaryColor
                            : AppTheme.surfaceOf(context),
                        borderRadius: AppRadius.sm,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.tune_rounded,
                          color: _showAdvanced
                              ? Colors.white
                              : AppTheme.textSecondaryOf(context),
                          size: AppIconSize.sm,
                        ),
                        onPressed: () =>
                            setState(() => _showAdvanced = !_showAdvanced),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 34,
                      child: ElevatedButton(
                        onPressed: _applyFilters,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.sm,
                          ),
                        ),
                        child: const Text('Go', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                if (_showAdvanced) ...[
                  AppSpacing.vMd,
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedRegType,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'Registration',
                            filled: true,
                            fillColor: AppTheme.inputFillOf(context),
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.sm,
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Any')),
                            DropdownMenuItem(
                                value: 'open', child: Text('Open')),
                            DropdownMenuItem(
                                value: 'closed', child: Text('Closed')),
                          ],
                          onChanged: (v) {
                            setState(() => _selectedRegType = v);
                            _applyFilters();
                          },
                        ),
                      ),
                      AppSpacing.hSm,
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedGenre,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'Genre',
                            filled: true,
                            fillColor: AppTheme.inputFillOf(context),
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.sm,
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('All')),
                            ..._genres.map((g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(g[0].toUpperCase() +
                                      g.substring(1)),
                                )),
                          ],
                          onChanged: (v) {
                            setState(() => _selectedGenre = v);
                            _applyFilters();
                          },
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vSm,
                  Row(
                    children: [
                      Expanded(
                        child: _dateChip(
                          label: _dateFrom != null
                              ? 'From: ${dateFmt.format(_dateFrom!)}'
                              : 'Start date',
                          onTap: () => _pickDate(true),
                        ),
                      ),
                      AppSpacing.hSm,
                      Expanded(
                        child: _dateChip(
                          label: _dateTo != null
                              ? 'To: ${dateFmt.format(_dateTo!)}'
                              : 'End date',
                          onTap: () => _pickDate(false),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vSm,
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear all filters'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 6,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _showMapView
                        ? 'Map View'
                        : (user != null && user.isOrganizer
                            ? 'Your Events'
                            : 'All Events'),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          letterSpacing: -0.3,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: AppRadius.pill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _toggleButton(
                        icon: Icons.view_list_rounded,
                        label: 'List',
                        isActive: !_showMapView,
                        onTap: () => setState(() => _showMapView = false),
                      ),
                      _toggleButton(
                        icon: Icons.map_rounded,
                        label: 'Map',
                        isActive: _showMapView,
                        onTap: () => setState(() => _showMapView = true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_showMapView)
          SliverFillRemaining(
            child: ClipRRect(
              borderRadius: AppRadius.topLg,
              child: EventMapWidget(
                organizerId: user != null && user.isOrganizer ? user.id : null,
                search: _searchController.text.isNotEmpty ? _searchController.text : null,
                genre: _selectedGenre,
                status: _selectedStatus,
              ),
            ),
          )
        else if (events.isLoading)
          SliverFillRemaining(
            child: SingleChildScrollView(
              child: ShimmerEventList(count: 4),
            ),
          )
        else if (events.error != null)
          SliverFillRemaining(
            child: ErrorState(
              message: events.error!,
              onRetry: () => events.loadEvents(),
            ),
          )
        else if (events.events.isEmpty)
          const SliverFillRemaining(
            child: EmptyState(
              icon: Icons.event_busy_rounded,
              title: 'No events found',
              subtitle: 'Try adjusting your filters',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.xs,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 340,
                mainAxisExtent: 320,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final event = events.events[index];
                  return AnimatedListItem(
                    index: index,
                    child: EventCard(
                      event: event,
                      imageUrl: event.firstImageUrl,
                      onTap: () => context.push('/events/${event.id}'),
                      isBookmarked: _bookmarkedIds.contains(event.id),
                      onBookmarkToggle: () => _toggleBookmark(event.id),
                    ),
                  );
                },
                childCount: events.events.length,
              ),
            ),
          ),

        if (events.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    ),
    );
  }

  Widget _toggleButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.normal,
        curve: AppCurve.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white
              : Colors.transparent,
          borderRadius: AppRadius.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppIconSize.sm,
              color: isActive ? AppTheme.primaryColor : Colors.white60,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? AppTheme.primaryColor : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateChip({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
          borderRadius: AppRadius.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: AppIconSize.sm, color: AppTheme.textSecondaryOf(context)),
            AppSpacing.hSm,
            Text(label,
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textSecondaryOf(context))),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // TAB 2: MANAGE (organizer) / MY EVENTS (customer)
  // ════════════════════════════════════════════

  Widget _buildManageTab() {
    final user = context.watch<AuthProvider>().user;
    final isDark = AppTheme.isDark(context);
    return CustomScrollView(
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
              AppSpacing.xxl, 56, AppSpacing.xxl, AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manage',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppTheme.textPrimaryOf(context))),
                AppSpacing.vSm,
                Text(
                  'Tools & shortcuts for your events',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryOf(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Actions',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryOf(context),
                        letterSpacing: 0.5)),
                AppSpacing.vLg,
                AnimatedListItem(
                  index: 0,
                  child: Row(
                    children: [
                      _quickActionCard(
                        icon: Icons.add_circle_rounded,
                        label: 'Create Event',
                        color: AppTheme.accentColor,
                        onTap: () async {
                          final created =
                              await context.push<bool>('/events/create');
                          if (created == true && mounted) {
                            _applyFilters();
                            _loadFeatured();
                          }
                        },
                      ),
                      AppSpacing.hMd,
                      _quickActionCard(
                        icon: Icons.location_city_rounded,
                        label: 'Venues',
                        color: const Color(0xFF276EF1),
                        onTap: () => context.push('/venues'),
                      ),
                      AppSpacing.hMd,
                      _quickActionCard(
                        icon: Icons.confirmation_number_rounded,
                        label: 'Ticket Tiers',
                        color: const Color(0xFF00838F),
                        onTap: () => context.push('/ticket-strategies'),
                      ),
                    ],
                  ),
                ),
                AppSpacing.vMd,
                AnimatedListItem(
                  index: 1,
                  child: Row(
                    children: [
                      _quickActionCard(
                        icon: Icons.receipt_long_rounded,
                        label: 'All Sales',
                        color: const Color(0xFF05944F),
                        onTap: () => context.push('/manage/ticket-sales'),
                      ),
                      AppSpacing.hMd,
                      _quickActionCard(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Scanned',
                        color: const Color(0xFF7356BF),
                        onTap: () => context.push('/manage/scanned-tickets'),
                      ),
                      AppSpacing.hMd,
                      _quickActionCard(
                        icon: Icons.hourglass_top_rounded,
                        label: 'Waitlist',
                        color: const Color(0xFFE65100),
                        onTap: () => context.push('/manage/waitlist'),
                      ),
                    ],
                  ),
                ),
                AppSpacing.vMd,
                AnimatedListItem(
                  index: 2,
                  child: Row(
                    children: [
                      _quickActionCard(
                        icon: Icons.discount_rounded,
                        label: 'Discounts',
                        color: const Color(0xFFE11900),
                        onTap: () => context.push('/manage/discounts'),
                      ),
                      AppSpacing.hMd,
                      _quickActionCard(
                        icon: Icons.handshake_rounded,
                        label: 'Sponsors',
                        color: const Color(0xFF0D3B66),
                        onTap: () => context.push('/manage/sponsors'),
                      ),
                      AppSpacing.hMd,
                      _quickActionCard(
                        icon: Icons.category_rounded,
                        label: 'Sponsorships',
                        color: const Color(0xFF6A1B9A),
                        onTap: () => context.push('/sponsor-category-templates'),
                      ),
                    ],
                  ),
                ),
                AppSpacing.vMd,
                AnimatedListItem(
                  index: 3,
                  child: Row(
                    children: [
                      _quickActionCard(
                        icon: Icons.bookmark_rounded,
                        label: 'Bookmarks',
                        color: const Color(0xFFFFC043),
                        onTap: () => context.push('/bookmarks'),
                      ),
                    ],
                  ),
                ),
                if (user != null && user.isAdmin) ...[
                  AppSpacing.vMd,
                  AnimatedListItem(
                    index: 4,
                    child: Row(
                      children: [
                        _quickActionCard(
                          icon: Icons.admin_panel_settings_rounded,
                          label: 'Admin',
                          color: const Color(0xFF141414),
                          onTap: () => context.push('/admin'),
                        ),
                        AppSpacing.hMd,
                        const Expanded(child: SizedBox()),
                        AppSpacing.hMd,
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ),
                ],

              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppTheme.primaryColor,
  }) {
    final isDark = AppTheme.isDark(context);
    return Expanded(
      child: PressFeedback(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppTheme.cardOf(context),
              borderRadius: AppRadius.lg,
              boxShadow: AppShadow.card(isDark),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: AppRadius.md,
                  ),
                  child: Icon(icon, size: AppIconSize.lg, color: color),
                ),
                AppSpacing.vSm,
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context)),
                    textAlign: TextAlign.center),
              ],
            ),
        ),
        ),
      ),
    );
  }

  Widget _customerQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: AppRadius.md,
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: AppIconSize.md, color: color),
              AppSpacing.hSm,
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyEventsTab() {
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
            AppSpacing.xxl, 56, AppSpacing.xxl, AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Manage',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppTheme.textPrimaryOf(context))),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 6,
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
                  _customerQuickAction(
                    icon: Icons.confirmation_number_rounded,
                    label: 'My Tickets',
                    color: const Color(0xFF276EF1),
                    onTap: () => context.push('/my-tickets'),
                  ),
                  AppSpacing.hSm,
                  _customerQuickAction(
                    icon: Icons.volunteer_activism_rounded,
                    label: 'My Pledges',
                    color: Colors.deepPurple,
                    onTap: () => context.push('/my-pledges'),
                  ),
                ],
              ),
              AppSpacing.vLg,
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search my events\u2026',
                  prefixIcon: Icon(Icons.search,
                      color: AppTheme.textSecondaryOf(context), size: AppIconSize.md),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: 14),
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
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _genres.map((g) {
                    final isActive = _myEventsGenre == g;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(g[0].toUpperCase() + g.substring(1)),
                        selected: isActive,
                        onSelected: (selected) {
                          setState(() {
                            _myEventsGenre = selected ? g : null;
                          });
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
                          color:
                              isActive ? Colors.white : AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              AppSpacing.vSm,
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _manageVisibleStatuses.map((s) {
                    final isActive = _myEventsStatus == s.name;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(_statusDisplayName(s)),
                        selected: isActive,
                        onSelected: (selected) {
                          setState(() {
                            _myEventsStatus = selected ? s.name : null;
                          });
                        },
                        selectedColor: _statusChipColor(s),
                        backgroundColor: AppTheme.cardOf(context),
                        side: BorderSide(
                          color: isActive
                              ? _statusChipColor(s)
                              : AppTheme.dividerOf(context),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : AppTheme.textPrimaryOf(context),
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
          child: filtered.isEmpty
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
                        notification.metrics.pixels >= notification.metrics.maxScrollExtent * 0.8 &&
                        !_myEventsLoadingMore && _myEventsHasMore) {
                      _loadMoreMyEvents();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    color: AppTheme.primaryColor,
                    onRefresh: _loadMyEvents,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 100,
                      ),
                      itemCount: filtered.length + (_myEventsLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= filtered.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
                              isBookmarked: _bookmarkedIds.contains(event.id),
                              onBookmarkToggle: () => _toggleBookmark(event.id),
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

  // ════════════════════════════════════════════
  // TAB 2b: SPONSOR MANAGE
  // ════════════════════════════════════════════

  Widget _buildSponsorManageTab() {
    final isDark = AppTheme.isDark(context);
    final filtered = _sponsorBidEvents.where((item) {
      if (_sponsorBidStatus != null && item.event.status.name != _sponsorBidStatus) return false;
      if (_sponsorBidSearch.isNotEmpty) {
        final q = _sponsorBidSearch.toLowerCase();
        return item.event.title.toLowerCase().contains(q) ||
            (item.event.genre?.toLowerCase().contains(q) ?? false) ||
            item.event.status.name.toLowerCase().contains(q);
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
            AppSpacing.xxl, 56, AppSpacing.xxl, AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Manage',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppTheme.textPrimaryOf(context))),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceOf(context),
                      borderRadius: AppRadius.pill,
                    ),
                    child: Text(
                      '${_sponsorBidEvents.length} event${_sponsorBidEvents.length != 1 ? "s" : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.vSm,
              Text(
                'Events you have placed bids on',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryOf(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              AppSpacing.vLg,
              Row(
                children: [
                  _customerQuickAction(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Sponsor Tickets',
                    color: const Color(0xFF0D3B66),
                    onTap: () => context.push('/sponsor/tickets'),
                  ),
                  AppSpacing.hSm,
                  _customerQuickAction(
                    icon: Icons.volunteer_activism_rounded,
                    label: 'My Pledges',
                    color: Colors.deepPurple,
                    onTap: () => context.push('/my-pledges'),
                  ),
                ],
              ),
              AppSpacing.vLg,
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search bid events\u2026',
                  prefixIcon: Icon(Icons.search,
                      color: AppTheme.textSecondaryOf(context), size: AppIconSize.md),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: 14,
                  ),
                  filled: true,
                  fillColor: AppTheme.inputFillOf(context),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.md,
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _sponsorBidSearch = v),
              ),
              AppSpacing.vSm,
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _manageVisibleStatuses.map((s) {
                    final isActive = _sponsorBidStatus == s.name;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(_statusDisplayName(s)),
                        selected: isActive,
                        onSelected: (selected) {
                          setState(() {
                            _sponsorBidStatus = selected ? s.name : null;
                          });
                        },
                        selectedColor: _statusChipColor(s),
                        backgroundColor: AppTheme.cardOf(context),
                        side: BorderSide(
                          color: isActive
                              ? _statusChipColor(s)
                              : AppTheme.dividerOf(context),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : AppTheme.textPrimaryOf(context),
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
          child: _sponsorBidEventsLoading
              ? SingleChildScrollView(
                  child: ShimmerEventList(count: 3),
                )
              : filtered.isEmpty
                  ? EmptyState(
                      icon: Icons.gavel_rounded,
                      title: _sponsorBidEvents.isEmpty
                          ? 'No bids yet'
                          : 'No matches',
                      subtitle: _sponsorBidEvents.isEmpty
                          ? 'Events you bid on will appear here'
                          : 'Try a different search term',
                    )
                  : RefreshIndicator(
                      color: AppTheme.primaryColor,
                      onRefresh: _loadSponsorBidEvents,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 100,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: AnimatedListItem(
                              index: index,
                              child: _SponsorBidEventCard(
                                item: item,
                                onTap: () =>
                                    context.push('/events/${item.event.id}'),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════
  // TAB 3: PROFILE
  // ════════════════════════════════════════════

  Widget _buildProfileTab() {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isDark = AppTheme.isDark(context);

    if (user == null) {
      return const Center(child: Text('Not signed in'));
    }

    Widget sectionCard(Widget child) => Container(
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: AppRadius.lg,
        boxShadow: AppShadow.card(isDark),
      ),
      child: child,
    );

    int animIdx = 0;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppRadius.xxlValue + 8),
                bottomRight: Radius.circular(AppRadius.xxlValue + 8),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl, 60, AppSpacing.xxl, AppSpacing.xxxl,
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.xl,
                  ),
                  child: Center(
                    child: Text(
                      user.initial,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
                AppSpacing.vLg,
                Text(
                  user.displayLabel,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                if (user.phone != null && user.phone!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 15, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(user.phone!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ],
                AppSpacing.vMd,
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: AppRadius.pill,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    user.role.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedListItem(
                  index: animIdx++,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Account',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondaryOf(context),
                              letterSpacing: 0.5)),
                      AppSpacing.vMd,
                      sectionCard(
                        _profileTile(
                          icon: Icons.person_outline_rounded,
                          label: 'Edit Profile',
                          onTap: () => context.push('/profile'),
                        ),
                      ),
                    ],
                  ),
                ),

                if (user.isOrganizer) ...[
                  AppSpacing.vXxl,
                  AnimatedListItem(
                    index: animIdx++,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Public Profile',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondaryOf(context),
                                letterSpacing: 0.5)),
                        AppSpacing.vMd,
                        sectionCard(
                          _profileTile(
                            icon: Icons.visibility_rounded,
                            label: 'View Organizer Profile',
                            onTap: () => context.push('/users/${user.id}/profile'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (user.isSponsor) ...[
                  AppSpacing.vXxl,
                  AnimatedListItem(
                    index: animIdx++,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Public Profile',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondaryOf(context),
                                letterSpacing: 0.5)),
                        AppSpacing.vMd,
                        sectionCard(
                          _profileTile(
                            icon: Icons.visibility_rounded,
                            label: 'View Sponsor Profile',
                            onTap: () => context.push('/users/${user.id}/sponsor-profile'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (user.isAdmin) ...[
                  AppSpacing.vXxl,
                  AnimatedListItem(
                    index: animIdx++,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Administration',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondaryOf(context),
                                letterSpacing: 0.5)),
                        AppSpacing.vMd,
                        sectionCard(
                          _profileTile(
                            icon: Icons.admin_panel_settings_rounded,
                            label: 'Admin Dashboard',
                            onTap: () => context.push('/admin'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (user.isCustomer) ...[
                  AppSpacing.vXxl,
                  AnimatedListItem(
                    index: animIdx++,
                    child: sectionCard(
                      _profileTile(
                        icon: Icons.storefront_rounded,
                        label: 'Become a Sponsor',
                        onTap: () => context.push('/sponsor/onboarding'),
                      ),
                    ),
                  ),
                ],

                AppSpacing.vXxl,
                AnimatedListItem(
                  index: animIdx++,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Preferences',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondaryOf(context),
                              letterSpacing: 0.5)),
                      AppSpacing.vMd,
                      sectionCard(
                        Column(
                          children: [
                            Builder(builder: (ctx) {
                              final themeProv = ctx.watch<ThemeProvider>();
                              return InkWell(
                                onTap: () => themeProv.toggle(),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(AppRadius.lgValue),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.lg, vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceOf(ctx),
                                          borderRadius: AppRadius.sm,
                                        ),
                                        child: Icon(
                                          themeProv.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                          size: AppIconSize.md,
                                          color: AppTheme.textPrimaryOf(ctx),
                                        ),
                                      ),
                                      AppSpacing.hLg,
                                      Expanded(
                                        child: Text('Dark Mode',
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                                color: AppTheme.textPrimaryOf(ctx))),
                                      ),
                                      Switch.adaptive(
                                        value: themeProv.isDark,
                                        activeColor: AppTheme.accentColor,
                                        onChanged: (_) => themeProv.toggle(),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            Divider(height: 1, indent: 56, color: AppTheme.dividerOf(context)),
                            _profileTile(
                              icon: Icons.description_outlined,
                              label: 'Terms & Conditions',
                              onTap: () {
                                final role = user.isOrganizer ? 'organizer' : 'customer';
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TermsScreen(role: role),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                AppSpacing.vXxxl,

                AnimatedListItem(
                  index: animIdx++,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await auth.signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                      icon:
                          const Icon(Icons.logout_rounded, color: AppTheme.errorColor),
                      label: const Text('Sign Out',
                          style: TextStyle(
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppTheme.errorColor.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.md),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.md,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(context),
                borderRadius: AppRadius.sm,
              ),
              child: Icon(icon, size: AppIconSize.md, color: AppTheme.textPrimaryOf(context)),
            ),
            AppSpacing.hLg,
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimaryOf(context))),
            ),
            Icon(Icons.chevron_right_rounded,
                size: AppIconSize.md, color: AppTheme.textSecondaryOf(context)),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildFeaturedSection(
      String title, IconData icon, List<Event> items, int sectionIndex) {
    return SliverToBoxAdapter(
      child: AnimatedListItem(
        index: sectionIndex,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxl, bottom: AppSpacing.md),
              child: SectionHeader(
                title: title,
                icon: icon,
                actionLabel: 'See all',
                onAction: () {
                  setState(() => _navIndex = 1);
                  context.go('/?tab=explore');
                },
              ),
            ),
            SizedBox(
              height: 320,
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
                      isBookmarked: _bookmarkedIds.contains(event.id),
                      onBookmarkToggle: () => _toggleBookmark(event.id),
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
}

class _SponsorBidEvent {
  final Event event;
  final int pending;
  final int accepted;
  final int rejected;
  final int paid;

  _SponsorBidEvent({
    required this.event,
    this.pending = 0,
    this.accepted = 0,
    this.rejected = 0,
    this.paid = 0,
  });

  int get totalBids => pending + accepted + rejected + paid;
}

class _SponsorBidEventCard extends StatelessWidget {
  final _SponsorBidEvent item;
  final VoidCallback onTap;

  const _SponsorBidEventCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final e = item.event;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: AppRadius.lg,
          boxShadow: AppShadow.card(isDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 14, AppSpacing.lg, AppSpacing.md,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B1B2F), Color(0xFF162447)],
                ),
                borderRadius: AppRadius.topLg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  AppSpacing.hSm,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: AppRadius.pill,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _statusDisplayName(e.status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (e.startTime != null)
                    _infoRow(context, Icons.schedule_rounded,
                        DateFormat('EEE, MMM d \u2022 h:mm a').format(e.startTime!)),
                  if (e.venue != null) ...[
                    const SizedBox(height: 5),
                    _infoRow(context, Icons.location_on_rounded,
                        '${e.venue!.name}, ${e.venue!.city}'),
                  ],
                  AppSpacing.vLg,
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (item.accepted > 0)
                        _bidChip('${item.accepted} Accepted',
                            Colors.green.shade600, Icons.check_circle_rounded),
                      if (item.paid > 0)
                        _bidChip('${item.paid} Paid',
                            Colors.blue.shade600, Icons.payment_rounded),
                      if (item.pending > 0)
                        _bidChip('${item.pending} Under Review',
                            Colors.orange.shade700, Icons.hourglass_top_rounded),
                      if (item.rejected > 0)
                        _bidChip('${item.rejected} Rejected',
                            Colors.red.shade600, Icons.cancel_rounded),
                      _bidChip('${item.totalBids} Total',
                          AppTheme.textSecondaryOf(context), Icons.gavel_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.textSecondaryOf(context)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bidChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm, vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pill,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.sm - 3, color: color),
          AppSpacing.hXs,
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
