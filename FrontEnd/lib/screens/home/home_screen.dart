import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';
import '../notification/notification_screen.dart';
import '../../services/api_service.dart';
import '../../widgets/event_lifecycle_bar.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/event_map_widget.dart';
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
              ? FloatingActionButton(
                  onPressed: () async {
                    final created = await context.push<bool>('/events/create');
                    if (created == true && mounted) {
                      _applyFilters();
                      _loadFeatured();
                    }
                  },
                  backgroundColor: AppTheme.accentColor,
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isActive
            ? BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 24,
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

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        await Future.wait([_loadFeatured(), _loadMyEvents()]);
      },
      child: CustomScrollView(
        slivers: [
          // ── Hero Header ──
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.cardOf(context),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(14),
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
                      const SizedBox(width: 14),
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
                                borderRadius: BorderRadius.circular(12),
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
                  ),
                  const SizedBox(height: 24),
                  // Search bar
                  TextField(
                    controller: _homeSearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search events, venues, genres...',
                      prefixIcon: Icon(Icons.search,
                          color: AppTheme.textSecondaryOf(context), size: 22),
                      suffixIcon: _homeSearchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: _clearHomeSearch,
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.inputFillOf(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _homeSearch(),
                  ),
                  const SizedBox(height: 20),
                  // Genre chips
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _genres.map((g) {
                        final isActive = _homeGenre == g;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
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
                  const SizedBox(height: 10),
                  // Status chips
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _visibleStatuses.map((s) {
                        final isActive = _homeStatus == s.name;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
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

          // ── Search results OR featured sections ──
          if (_isHomeFiltered) ...[
            // Active filter banner
            SliverToBoxAdapter(
                child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    Icon(Icons.filter_list_rounded,
                        size: 18, color: AppTheme.textSecondaryOf(context)),
                    const SizedBox(width: 8),
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
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_homeSearchResults.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 48, color: AppTheme.textSecondaryOf(context)),
                        const SizedBox(height: 12),
                        Text('No events found',
                            style: TextStyle(
                                color: AppTheme.textSecondaryOf(context),
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 230,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final event = _homeSearchResults[i];
                      return _UberEventCard(
                        event: event,
                        onTap: () => context.push('/events/${event.id}'),
                        isBookmarked: _bookmarkedIds.contains(event.id),
                        onBookmarkToggle: () => _toggleBookmark(event.id),
                      );
                    },
                    childCount: _homeSearchResults.length,
                  ),
                ),
              ),
          ] else ...[
            // ── Near Me ──
            if (_nearMeEvents.isNotEmpty)
              _buildFeaturedSection(
                  'Near Me', Icons.near_me_rounded, _nearMeEvents),

            // ── Featured ──
            if (!_featuredLoading) ...[
              if (_trending.isNotEmpty)
                _buildFeaturedSection('Trending Now',
                    Icons.local_fire_department_rounded, _trending),
              if (_comingSoon.isNotEmpty)
                _buildFeaturedSection(
                    'Coming Soon', Icons.upcoming_rounded, _comingSoon),
              if (_popular.isNotEmpty)
                _buildFeaturedSection(
                    'Most Popular', Icons.star_rounded, _popular),
              if (_communityEvents.isNotEmpty)
                _buildFeaturedSection(
                    'Community Events', Icons.groups_rounded, _communityEvents),
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
        // ── Search Header ──
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardOf(context),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 10),
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
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_rounded,
                                size: 14, color: AppTheme.accentColor),
                            const SizedBox(width: 4),
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
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search events...',
                    prefixIcon:
                        Icon(Icons.search, color: AppTheme.textSecondaryOf(context)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.inputFillOf(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  onSubmitted: (_) => _applyFilters(),
                ),
                const SizedBox(height: 10),
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
                              padding: const EdgeInsets.only(right: 8),
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
                    const SizedBox(width: 8),
                    Container(
                      height: 34,
                      width: 34,
                      decoration: BoxDecoration(
                        color: _showAdvanced
                            ? AppTheme.primaryColor
                            : AppTheme.surfaceOf(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.tune_rounded,
                          color: _showAdvanced
                              ? Colors.white
                              : AppTheme.textSecondaryOf(context),
                          size: 16,
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
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Go', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                // Advanced filters
                if (_showAdvanced) ...[
                  const SizedBox(height: 12),
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
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedGenre,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'Genre',
                            filled: true,
                            fillColor: AppTheme.inputFillOf(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
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
                  const SizedBox(height: 8),
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
                      const SizedBox(width: 8),
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
                  const SizedBox(height: 8),
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

        // ── Results header with Map/List toggle ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
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
                // Map / List toggle pill
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(20),
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

        // ── Map View or Event Grid ──
        if (_showMapView)
          SliverFillRemaining(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: AppTheme.textSecondaryOf(context)),
                  const SizedBox(height: 12),
                  Text(events.error!,
                      style: TextStyle(color: AppTheme.textSecondaryOf(context))),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => events.loadEvents(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (events.events.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceOf(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.event_busy_rounded,
                        size: 40, color: AppTheme.textSecondaryOf(context)),
                  ),
                  const SizedBox(height: 16),
                  Text('No events found',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryOf(context))),
                  const SizedBox(height: 4),
                  Text('Try adjusting your filters',
                      style: TextStyle(color: AppTheme.textSecondaryOf(context))),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 340,
                mainAxisExtent: 240,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final event = events.events[index];
                  return _UberEventCard(
                    event: event,
                    onTap: () => context.push('/events/${event.id}'),
                    isBookmarked: _bookmarkedIds.contains(event.id),
                    onBookmarkToggle: () => _toggleBookmark(event.id),
                  );
                },
                childCount: events.events.length,
              ),
            ),
          ),

        if (events.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 16, color: AppTheme.textSecondaryOf(context)),
            const SizedBox(width: 8),
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
    return CustomScrollView(
      slivers: [
        // ── Header ──
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardOf(context),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manage',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppTheme.textPrimaryOf(context))),
                const SizedBox(height: 8),
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

        // ── Quick Actions Grid ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Actions',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryOf(context),
                        letterSpacing: 0.5)),
                const SizedBox(height: 14),
                // Row 1
                Row(
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
                    const SizedBox(width: 12),
                    _quickActionCard(
                      icon: Icons.location_city_rounded,
                      label: 'Venues',
                      color: const Color(0xFF276EF1),
                      onTap: () => context.push('/venues'),
                    ),
                    const SizedBox(width: 12),
                    _quickActionCard(
                      icon: Icons.confirmation_number_rounded,
                      label: 'Ticket Tiers',
                      color: const Color(0xFF00838F),
                      onTap: () => context.push('/ticket-strategies'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Row 2
                Row(
                  children: [
                    _quickActionCard(
                      icon: Icons.receipt_long_rounded,
                      label: 'All Sales',
                      color: const Color(0xFF05944F),
                      onTap: () => context.push('/manage/ticket-sales'),
                    ),
                    const SizedBox(width: 12),
                    _quickActionCard(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scanned',
                      color: const Color(0xFF7356BF),
                      onTap: () => context.push('/manage/scanned-tickets'),
                    ),
                    const SizedBox(width: 12),
                    _quickActionCard(
                      icon: Icons.hourglass_top_rounded,
                      label: 'Waitlist',
                      color: const Color(0xFFE65100),
                      onTap: () => context.push('/manage/waitlist'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Row 3
                Row(
                  children: [
                    _quickActionCard(
                      icon: Icons.discount_rounded,
                      label: 'Discounts',
                      color: const Color(0xFFE11900),
                      onTap: () => context.push('/manage/discounts'),
                    ),
                    const SizedBox(width: 12),
                    _quickActionCard(
                      icon: Icons.handshake_rounded,
                      label: 'Sponsors',
                      color: const Color(0xFF0D3B66),
                      onTap: () => context.push('/manage/sponsors'),
                    ),
                    const SizedBox(width: 12),
                    _quickActionCard(
                      icon: Icons.bookmark_rounded,
                      label: 'Bookmarks',
                      color: const Color(0xFFFFC043),
                      onTap: () => context.push('/bookmarks'),
                    ),
                  ],
                ),
                if (user != null && user.isAdmin) ...[
                  const SizedBox(height: 12),
                  // Row 4
                  Row(
                    children: [
                      _quickActionCard(
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Admin',
                        color: const Color(0xFF141414),
                        onTap: () => context.push('/admin'),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: SizedBox()),
                      const SizedBox(width: 12),
                      const Expanded(child: SizedBox()),
                    ],
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: AppTheme.cardOf(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 10),
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
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
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
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceOf(context),
                      borderRadius: BorderRadius.circular(20),
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
              const SizedBox(height: 14),
              Row(
                children: [
                  _customerQuickAction(
                    icon: Icons.confirmation_number_rounded,
                    label: 'My Tickets',
                    color: const Color(0xFF276EF1),
                    onTap: () => context.push('/my-tickets'),
                  ),
                  const SizedBox(width: 10),
                  _customerQuickAction(
                    icon: Icons.volunteer_activism_rounded,
                    label: 'My Pledges',
                    color: Colors.deepPurple,
                    onTap: () => context.push('/my-pledges'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search my events…',
                  prefixIcon: Icon(Icons.search,
                      color: AppTheme.textSecondaryOf(context), size: 22),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: AppTheme.inputFillOf(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _myEventsSearch = v),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _genres.map((g) {
                    final isActive = _myEventsGenre == g;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
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
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _manageVisibleStatuses.map((s) {
                    final isActive = _myEventsStatus == s.name;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
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
        // List or empty state
        Expanded(
          child: filtered.isEmpty
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
                        child: Icon(Icons.event_busy_rounded,
                            size: 40, color: AppTheme.textSecondaryOf(context)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _myEvents.isEmpty ? 'No events yet' : 'No matches',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimaryOf(context)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _myEvents.isEmpty
                            ? 'Events you register for will appear here'
                            : 'Try a different search term',
                        style: TextStyle(
                            color: AppTheme.textSecondaryOf(context), fontSize: 14),
                      ),
                    ],
                  ),
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: filtered.length + (_myEventsLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= filtered.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }
                        final event = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _UberEventCard(
                            event: event,
                            onTap: () => context.push('/events/${event.id}'),
                            isBookmarked: _bookmarkedIds.contains(event.id),
                            onBookmarkToggle: () => _toggleBookmark(event.id),
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
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceOf(context),
                      borderRadius: BorderRadius.circular(20),
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
              const SizedBox(height: 8),
              Text(
                'Events you have placed bids on',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryOf(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _customerQuickAction(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Sponsor Tickets',
                    color: const Color(0xFF0D3B66),
                    onTap: () => context.push('/sponsor/tickets'),
                  ),
                  const SizedBox(width: 10),
                  _customerQuickAction(
                    icon: Icons.volunteer_activism_rounded,
                    label: 'My Pledges',
                    color: Colors.deepPurple,
                    onTap: () => context.push('/my-pledges'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search bid events\u2026',
                  prefixIcon: Icon(Icons.search,
                      color: AppTheme.textSecondaryOf(context), size: 22),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: AppTheme.inputFillOf(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _sponsorBidSearch = v),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _manageVisibleStatuses.map((s) {
                    final isActive = _sponsorBidStatus == s.name;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
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
                            child: Icon(Icons.gavel_rounded,
                                size: 40,
                                color: AppTheme.textSecondaryOf(context)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _sponsorBidEvents.isEmpty
                                ? 'No bids yet'
                                : 'No matches',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimaryOf(context)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _sponsorBidEvents.isEmpty
                                ? 'Events you bid on will appear here'
                                : 'Try a different search term',
                            style: TextStyle(
                                color: AppTheme.textSecondaryOf(context),
                                fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppTheme.primaryColor,
                      onRefresh: _loadSponsorBidEvents,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SponsorBidEventCard(
                              item: item,
                              onTap: () =>
                                  context.push('/events/${item.event.id}'),
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

    if (user == null) {
      return const Center(child: Text('Not signed in'));
    }

    return CustomScrollView(
      slivers: [
        // ── Profile Header ──
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
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
                const SizedBox(height: 16),
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
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
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

        // ── Menu Items ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryOf(context),
                        letterSpacing: 0.5)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardOf(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _profileTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Edit Profile',
                    onTap: () => context.push('/profile'),
                  ),
                ),

                if (user.isOrganizer || user.isAdmin) ...[
                  const SizedBox(height: 24),
                  Text('Management',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondaryOf(context),
                          letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardOf(context),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (user.isOrganizer) ...[
                          _profileTile(
                            icon: Icons.location_city_rounded,
                            label: 'My Venues',
                            onTap: () => context.push('/venues'),
                          ),
                          Divider(height: 1, indent: 56, color: AppTheme.dividerOf(context)),
                          _profileTile(
                            icon: Icons.confirmation_number_rounded,
                            label: 'Ticket Strategies',
                            onTap: () => context.push('/ticket-strategies'),
                          ),
                          Divider(height: 1, indent: 56, color: AppTheme.dividerOf(context)),
                        ],
                        if (user.isAdmin)
                          _profileTile(
                            icon: Icons.admin_panel_settings_rounded,
                            label: 'Admin Dashboard',
                            onTap: () => context.push('/admin'),
                          ),
                      ],
                    ),
                  ),
                ],

                if (user.isCustomer) ...[
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardOf(context),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _profileTile(
                      icon: Icons.storefront_rounded,
                      label: 'Become a Sponsor',
                      onTap: () => context.push('/sponsor/onboarding'),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                Text('Preferences',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryOf(context),
                        letterSpacing: 0.5)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardOf(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Builder(builder: (ctx) {
                        final themeProv = ctx.watch<ThemeProvider>();
                        return InkWell(
                          onTap: () => themeProv.toggle(),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceOf(ctx),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    themeProv.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                    size: 20,
                                    color: AppTheme.textPrimaryOf(ctx),
                                  ),
                                ),
                                const SizedBox(width: 14),
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

                const SizedBox(height: 32),

                // Sign out button
                SizedBox(
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
                          borderRadius: BorderRadius.circular(14)),
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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppTheme.textPrimaryOf(context)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimaryOf(context))),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 22, color: AppTheme.textSecondaryOf(context)),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // Featured Section
  // ════════════════════════════════════════════

  SliverToBoxAdapter _buildFeaturedSection(
      String title, IconData icon, List<Event> items) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Row(
              children: [
                Icon(icon, size: 22, color: AppTheme.primaryColor),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() => _navIndex = 1);
                    context.go('/?tab=explore');
                  },
                  child: const Text('See all',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 230,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final event = items[index];
                return Container(
                  width: 280,
                  margin: const EdgeInsets.only(right: 12),
                  child: _UberEventCard(
                    event: event,
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
    );
  }
}

// ═══════════════════════════════════════════════════════
// Uber-inspired Event Card
// ═══════════════════════════════════════════════════════

class _UberEventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  final bool isBookmarked;
  final VoidCallback? onBookmarkToggle;

  const _UberEventCard({
    required this.event,
    required this.onTap,
    this.isBookmarked = false,
    this.onBookmarkToggle,
  });

  @override
  Widget build(BuildContext context) {
    final event = this.event;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top: gradient header with status ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                gradient: _headerGradient(event.status),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EventLifecycleBar(event: event, compact: true),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusPill(status: event.status),
                      const SizedBox(width: 6),
                      if (onBookmarkToggle != null)
                        GestureDetector(
                          onTap: onBookmarkToggle,
                          child: Icon(
                            isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 22,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Body ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (event.startTime != null) ...[
                    _iconRow(
                      context,
                      Icons.schedule_rounded,
                      DateFormat('EEE, MMM d \u2022 h:mm a')
                          .format(event.startTime!),
                    ),
                    const SizedBox(height: 5),
                  ],
                  if (event.venue != null)
                    _iconRow(
                      context,
                      Icons.location_on_rounded,
                      '${event.venue!.name}, ${event.venue!.city}',
                    ),
                  if (event.genre != null && event.genre!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    _iconRow(
                      context,
                      Icons.label_rounded,
                      event.genre![0].toUpperCase() +
                          event.genre!.substring(1),
                      color: AppTheme.accentColor,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (event.registrationCount > 0)
                        _statChip(context, Icons.group_rounded,
                            '${event.registrationCount}'),
                      if (event.likeCount > 0)
                        _statChip(context,
                            Icons.favorite_rounded, '${event.likeCount}'),
                      const Spacer(),
                      if (event.fundingGoalCents != null &&
                          event.fundingGoalCents! > 0)
                        Text(
                          event.totalPledgedFormatted,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.successColor,
                          ),
                        ),
                    ],
                  ),
                  if (event.fundingGoalCents != null &&
                      event.fundingGoalCents! > 0) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: event.fundingProgress.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: AppTheme.dividerOf(context),
                        valueColor: AlwaysStoppedAnimation(
                          event.fundingProgress >= 1.0
                              ? AppTheme.successColor
                              : AppTheme.accentColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconRow(BuildContext context, IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color ?? AppTheme.textSecondaryOf(context)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: 12.5,
                color: color ?? AppTheme.textSecondaryOf(context),
                fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _statChip(BuildContext context, IconData icon, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondaryOf(context)),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryOf(context))),
        ],
      ),
    );
  }

  LinearGradient _headerGradient(EventStatus status) {
    return switch (status) {
      EventStatus.live => const LinearGradient(
          colors: [Color(0xFF05944F), Color(0xFF0A7544)]),
      EventStatus.selling_tickets => const LinearGradient(
          colors: [Color(0xFF00838F), Color(0xFF00695C)]),
      EventStatus.waiting_event_date => const LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFBF360C)]),
      EventStatus.completed => const LinearGradient(
          colors: [Color(0xFF424242), Color(0xFF212121)]),
      EventStatus.cancelled => const LinearGradient(
          colors: [Color(0xFF8B0000), Color(0xFF5D0000)]),
      EventStatus.draft => const LinearGradient(
          colors: [Color(0xFF757575), Color(0xFF545454)]),
      EventStatus.pending_approval => const LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFBF360C)]),
      _ => const LinearGradient(
          colors: [Color(0xFF141414), Color(0xFF2C2C2C)]),
    };
  }
}

class _StatusPill extends StatelessWidget {
  final EventStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      EventStatus.draft => 'Draft',
      EventStatus.pending_approval => 'Under Review',
      EventStatus.approved => 'Funding',
      EventStatus.selling_tickets => 'Tickets',
      EventStatus.waiting_event_date => 'Awaiting',
      EventStatus.live => 'LIVE',
      EventStatus.completed => 'Done',
      EventStatus.cancelled => 'Cancelled',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
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
    final e = item.event;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B1B2F), Color(0xFF162447)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
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
                  const SizedBox(width: 8),
                  _StatusPill(status: e.status),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
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
