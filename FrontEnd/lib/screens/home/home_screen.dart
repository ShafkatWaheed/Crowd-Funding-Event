import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/event_lifecycle_bar.dart';
import '../../widgets/event_map_widget.dart';
import '../../services/location_helper.dart';

String _statusDisplayName(EventStatus s) {
  switch (s) {
    case EventStatus.draft:
      return 'Draft';
    case EventStatus.pending_approval:
      return 'Under Review';
    case EventStatus.approved:
      return 'Published';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
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
  bool _nearMeLoading = false;
  bool _nearMeAttempted = false;

  final List<String> _genres = [
    'community', 'music', 'tech', 'sports', 'arts',
    'food', 'charity', 'education', 'business', 'other',
  ];

  // Home tab search
  final _homeSearchCtrl = TextEditingController();
  String? _homeGenre;
  List<Event> _homeSearchResults = [];
  bool _homeSearching = false;
  bool get _isHomeFiltered =>
      _homeSearchCtrl.text.isNotEmpty || _homeGenre != null;

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
  String _myEventsSearch = '';
  String? _myEventsGenre;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFilters();
      _loadFeatured();
      _loadMyEvents();
      _loadNearMe();
    });
  }

  Future<void> _loadMyEvents() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    setState(() => _myEventsLoading = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getMyEvents();
      if (mounted) {
        setState(() {
          _myEvents = data.map((e) => Event.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('_loadMyEvents error: $e');
    }
    if (mounted) setState(() => _myEventsLoading = false);
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
      });
    } catch (_) {
      setState(() => _featuredLoading = false);
    }
  }

  Future<void> _loadNearMe() async {
    if (_nearMeAttempted) return;
    setState(() {
      _nearMeLoading = true;
      _nearMeAttempted = true;
    });
    try {
      final pos = await LocationHelper.getCurrentPosition();
      if (pos == null || !mounted) {
        if (mounted) setState(() => _nearMeLoading = false);
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
        final ids = (data as List)
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
    if (mounted) setState(() => _nearMeLoading = false);
  }

  @override
  void dispose() {
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
      final data = await api.getEvents(params: params);
      setState(() {
        _homeSearchResults = data.map((e) => Event.fromJson(e)).toList();
      });
    } catch (_) {}
    setState(() => _homeSearching = false);
  }

  void _clearHomeSearch() {
    setState(() {
      _homeSearchCtrl.clear();
      _homeGenre = null;
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
      backgroundColor: AppTheme.surfaceColor,
      body: IndexedStack(
        index: _navIndex,
        children: [
          _buildHomeTab(),
          _buildExploreTab(),
          if (user != null && (user.isOrganizer || user.isAdmin))
            _buildManageTab()
          else
            _buildMyEventsTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
                  _navItem(2, Icons.bookmark_rounded, Icons.bookmark_outline, 'My Events'),
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
                      _loadMyEvents();
                    }
                  },
                  backgroundColor: AppTheme.primaryColor,
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                )
              : null,
    );
  }

  Widget _navItem(int index, IconData activeIcon, IconData icon, String label) {
    final isActive = _navIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _navIndex = index);
        // Reload My Events when switching to that tab (index 2 for customers)
        if (index == 2) {
          final user = context.read<AuthProvider>().user;
          if (user != null && user.isCustomer) {
            _loadMyEvents();
          }
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isActive
            ? BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 24,
              color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
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
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
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
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500),
                            ),
                            Text(
                              user?.displayLabel ?? 'Guest',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Notification bell (placeholder)
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.notifications_outlined,
                            color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Search bar
                  TextField(
                    controller: _homeSearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search events, venues, genres...',
                      prefixIcon: const Icon(Icons.search,
                          color: AppTheme.textSecondary, size: 22),
                      suffixIcon: _homeSearchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: _clearHomeSearch,
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
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
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: isActive
                                  ? AppTheme.primaryColor
                                  : AppTheme.dividerColor,
                            ),
                            labelStyle: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isActive ? Colors.white : AppTheme.textPrimary,
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
                        size: 18, color: AppTheme.textSecondary),
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
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
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No events found',
                            style: TextStyle(
                                color: Colors.grey[500],
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

    return CustomScrollView(
      slivers: [
        // ── Search Header ──
        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Explore',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search events...',
                    prefixIcon:
                        const Icon(Icons.search, color: AppTheme.textSecondary),
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
                    fillColor: AppTheme.surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  onSubmitted: (_) => _applyFilters(),
                ),
                const SizedBox(height: 12),
                // Filters row
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            filled: true,
                            fillColor: AppTheme.surfaceColor,
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
                            ...EventStatus.values
                                .where((s) =>
                                    (user != null &&
                                        (user.isOrganizer || user.isAdmin)) ||
                                    (s != EventStatus.draft &&
                                        s != EventStatus.pending_approval &&
                                        s != EventStatus.cancelled &&
                                        s != EventStatus.waiting_event_date))
                                .map((s) => DropdownMenuItem(
                                    value: s.name,
                                    child: Text(_statusDisplayName(s),
                                        style: const TextStyle(fontSize: 13)))),
                          ],
                          onChanged: (v) {
                            setState(() => _selectedStatus = v);
                            _applyFilters();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: _showAdvanced
                            ? AppTheme.primaryColor
                            : AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.tune_rounded,
                          color: _showAdvanced
                              ? Colors.white
                              : AppTheme.textSecondary,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _showAdvanced = !_showAdvanced),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _applyFilters,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Go', style: TextStyle(fontSize: 14)),
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
                            fillColor: AppTheme.surfaceColor,
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
                            fillColor: AppTheme.surfaceColor,
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _showMapView ? 'Map View' : 'All Events',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(letterSpacing: -0.3),
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
              child: const EventMapWidget(),
            ),
          )
        else if (events.isLoading)
          const SliverFillRemaining(
            child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor)),
          )
        else if (events.error != null)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(events.error!,
                      style: TextStyle(color: AppTheme.textSecondary)),
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
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.event_busy_rounded,
                        size: 40, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  const Text('No events found',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Try adjusting your filters',
                      style: TextStyle(color: AppTheme.textSecondary)),
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
                  );
                },
                childCount: events.events.length,
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
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
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
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
        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Manage',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _quickActionCard(
                      icon: Icons.add_circle_rounded,
                      label: 'Create Event',
                      onTap: () async {
                        final created = await context.push<bool>('/events/create');
                        if (created == true && mounted) {
                          _applyFilters();
                          _loadFeatured();
                          _loadMyEvents();
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    _quickActionCard(
                      icon: Icons.location_city_rounded,
                      label: 'Venues',
                      onTap: () => context.push('/venues'),
                    ),
                    const SizedBox(width: 12),
                    _quickActionCard(
                      icon: Icons.confirmation_number_rounded,
                      label: 'Tickets',
                      onTap: () => context.push('/ticket-strategies'),
                    ),
                    if (user != null && user.isAdmin) ...[
                      const SizedBox(width: 12),
                      _quickActionCard(
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Admin',
                        onTap: () => context.push('/admin'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _quickActionCard(
                      icon: Icons.receipt_long_rounded,
                      label: 'All Sales',
                      onTap: () => context.push('/manage/ticket-sales'),
                    ),
                    const SizedBox(width: 12),
                    _quickActionCard(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scanned',
                      onTap: () => context.push('/manage/scanned-tickets'),
                    ),
                    const SizedBox(width: 12),
                    _quickActionCard(
                      icon: Icons.hourglass_top_rounded,
                      label: 'Waitlist',
                      onTap: () => context.push('/manage/waitlist'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _quickActionCard(
                      icon: Icons.discount_rounded,
                      label: 'Discounts',
                      onTap: () => context.push('/manage/discounts'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Show organizer's events
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text('Your Events',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(letterSpacing: -0.3)),
          ),
        ),
        _buildMyEventsGrid(),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: AppTheme.primaryColor),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyEventsTab() {
    final filtered = _myEvents.where((e) {
      // Genre filter
      if (_myEventsGenre != null && e.genre != _myEventsGenre) return false;
      // Text search
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
        // Header + Search + Genre chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('My Events',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              const SizedBox(height: 14),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search my events…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _myEventsSearch = v),
              ),
              const SizedBox(height: 12),
              // Genre chips
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
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isActive
                              ? AppTheme.primaryColor
                              : AppTheme.dividerColor,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : AppTheme.textPrimary,
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
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.bookmark_outline_rounded,
                            size: 40, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _myEvents.isEmpty ? 'No events yet' : 'No matches',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _myEvents.isEmpty
                            ? 'Events you register for will appear here'
                            : 'Try a different search term',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMyEvents,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final event = filtered[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _UberEventCard(
                          event: event,
                          onTap: () => context.push('/events/${event.id}'),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  SliverPadding _buildMyEventsGrid() {
    final events = context.watch<EventProvider>();
    if (events.isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.all(40),
        sliver: const SliverToBoxAdapter(
          child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor)),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
            );
          },
          childCount: events.events.length,
        ),
      ),
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
                const Text('Account',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                      _profileTile(
                        icon: Icons.person_outline_rounded,
                        label: 'Edit Profile',
                        onTap: () => context.push('/profile'),
                      ),
                      const Divider(height: 1, indent: 56),
                      if (user.isCustomer) ...[
_profileTile(
                        icon: Icons.volunteer_activism_rounded,
                        label: 'My Pledges',
                        onTap: () => AppToast.info(context, 'Coming soon'),
                      ),
                        const Divider(height: 1, indent: 56),
_profileTile(
                        icon: Icons.confirmation_number_rounded,
                        label: 'My Tickets',
                        onTap: () => context.push('/my-tickets'),
                      ),
                        const Divider(height: 1, indent: 56),
                      ],
                    ],
                  ),
                ),

                if (user.isOrganizer || user.isAdmin) ...[
                  const SizedBox(height: 24),
                  const Text('Management',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                          const Divider(height: 1, indent: 56),
                          _profileTile(
                            icon: Icons.confirmation_number_rounded,
                            label: 'Ticket Strategies',
                            onTap: () => context.push('/ticket-strategies'),
                          ),
                          const Divider(height: 1, indent: 56),
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
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 22, color: AppTheme.textSecondary),
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
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _navIndex = 1),
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

  const _UberEventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
                  // Lifecycle bar
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
                  // Date
                  if (event.startTime != null) ...[
                    _iconRow(
                      Icons.schedule_rounded,
                      DateFormat('EEE, MMM d \u2022 h:mm a')
                          .format(event.startTime!),
                    ),
                    const SizedBox(height: 5),
                  ],
                  // Venue
                  if (event.venue != null)
                    _iconRow(
                      Icons.location_on_rounded,
                      '${event.venue!.name}, ${event.venue!.city}',
                    ),
                  if (event.genre != null && event.genre!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    _iconRow(
                      Icons.label_rounded,
                      event.genre![0].toUpperCase() +
                          event.genre!.substring(1),
                      color: AppTheme.accentColor,
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Bottom stats row
                  Row(
                    children: [
                      if (event.registrationCount > 0)
                        _statChip(Icons.group_rounded,
                            '${event.registrationCount}'),
                      if (event.likeCount > 0)
                        _statChip(
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
                  // Funding bar
                  if (event.fundingGoalCents != null &&
                      event.fundingGoalCents! > 0) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: event.fundingProgress.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: AppTheme.dividerColor,
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

  Widget _iconRow(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color ?? AppTheme.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: 12.5,
                color: color ?? AppTheme.textSecondary,
                fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _statChip(IconData icon, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
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
      EventStatus.pending_approval => 'Pending',
      EventStatus.approved => 'Open',
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
