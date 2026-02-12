import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/event_lifecycle_bar.dart';

String _statusDisplayName(EventStatus s) {
  switch (s) {
    case EventStatus.draft:
      return 'Draft';
    case EventStatus.pending_approval:
      return 'Unpublished';
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

  final List<String> _genres = [
    'community', 'music', 'tech', 'sports', 'arts',
    'food', 'charity', 'education', 'business', 'other',
  ];

  // Featured sections
  List<Event> _trending = [];
  List<Event> _popular = [];
  List<Event> _comingSoon = [];
  bool _featuredLoading = true;

  // My registered events
  List<Event> _myEvents = [];
  // ignore: unused_field
  bool _myEventsLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFilters();
      _loadFeatured();
      _loadMyEvents();
    });
  }

  Future<void> _loadMyEvents() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    setState(() => _myEventsLoading = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getMyEvents();
      setState(() {
        _myEvents = data.map((e) => Event.fromJson(e)).toList();
      });
    } catch (_) {}
    setState(() => _myEventsLoading = false);
  }

  Future<void> _loadFeatured() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getFeaturedEvents();
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
        _featuredLoading = false;
      });
    } catch (_) {
      setState(() => _featuredLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                  onPressed: () => context.go('/events/create'),
                  backgroundColor: AppTheme.primaryColor,
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                )
              : null,
    );
  }

  Widget _navItem(int index, IconData activeIcon, IconData icon, String label) {
    final isActive = _navIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _navIndex = index),
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
                  // Quick search bar
                  GestureDetector(
                    onTap: () => setState(() => _navIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search,
                              color: AppTheme.textSecondary, size: 22),
                          const SizedBox(width: 12),
                          Text(
                            'Search events, venues, genres...',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Genre chips
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _genres.map((g) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(g[0].toUpperCase() + g.substring(1)),
                            onPressed: () {
                              setState(() {
                                _selectedGenre = g;
                                _navIndex = 1;
                              });
                              _applyFilters();
                            },
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppTheme.dividerColor),
                            labelStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── My Events ──
          if (_myEvents.isNotEmpty)
            _buildFeaturedSection('My Events', Icons.bookmark_rounded, _myEvents),

          // ── Featured ──
          if (!_featuredLoading) ...[
            if (_trending.isNotEmpty)
              _buildFeaturedSection('Trending Now', Icons.local_fire_department_rounded, _trending),
            if (_comingSoon.isNotEmpty)
              _buildFeaturedSection('Coming Soon', Icons.upcoming_rounded, _comingSoon),
            if (_popular.isNotEmpty)
              _buildFeaturedSection('Most Popular', Icons.star_rounded, _popular),
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

        // ── Results header ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'All Events',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(letterSpacing: -0.3),
            ),
          ),
        ),

        // ── Event Grid ──
        if (events.isLoading)
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
                    onTap: () => context.go('/events/${event.id}'),
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
                      onTap: () => context.go('/events/create'),
                    ),
                    const SizedBox(width: 12),
                    _quickActionCard(
                      icon: Icons.location_city_rounded,
                      label: 'Venues',
                      onTap: () => context.go('/venues'),
                    ),
                    const SizedBox(width: 12),
                    _quickActionCard(
                      icon: Icons.confirmation_number_rounded,
                      label: 'Tickets',
                      onTap: () => context.go('/ticket-strategies'),
                    ),
                    if (user != null && user.isAdmin) ...[
                      const SizedBox(width: 12),
                      _quickActionCard(
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Admin',
                        onTap: () => context.go('/admin'),
                      ),
                    ],
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
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
            child: const Text('My Events',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
          ),
        ),
        if (_myEvents.isEmpty)
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
                    child: const Icon(Icons.bookmark_outline_rounded,
                        size: 40, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  const Text('No events yet',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Events you register for will appear here',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final event = _myEvents[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _UberEventCard(
                      event: event,
                      onTap: () => context.go('/events/${event.id}'),
                    ),
                  );
                },
                childCount: _myEvents.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
              onTap: () => context.go('/events/${event.id}'),
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
    return Center(
      child: ElevatedButton(
        onPressed: () => context.go('/profile'),
        child: const Text('Go to Profile'),
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
                    onTap: () => context.go('/events/${event.id}'),
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date
                    _iconRow(
                      Icons.schedule_rounded,
                      event.startTime != null
                          ? DateFormat('EEE, MMM d \u2022 h:mm a')
                              .format(event.startTime!)
                          : 'Date TBD',
                    ),
                    const SizedBox(height: 5),
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
                    const Spacer(),
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
