import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      return 'Waiting Approval';
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
    case EventStatus.under_review:
      return 'Under Review';
  }
}

Color _statusChipColor(BuildContext context, EventStatus s) {
  switch (s) {
    case EventStatus.approved:
      return AppTheme.accentColor;
    case EventStatus.selling_tickets:
      return context.statusApproved;
    case EventStatus.live:
      return AppTheme.errorColor;
    case EventStatus.completed:
      return context.sponsorAccent;
    case EventStatus.cancelled:
      return context.statusCancelled;
    case EventStatus.draft:
      return context.statusDraft;
    case EventStatus.pending_approval:
      return context.statusPending;
    case EventStatus.waiting_event_date:
      return context.statusSelling;
    case EventStatus.under_review:
      return AppTheme.warningColor;
  }
}

IconData _statusChipIcon(EventStatus s) {
  switch (s) {
    case EventStatus.approved:
      return Icons.check_circle_rounded;
    case EventStatus.selling_tickets:
      return Icons.confirmation_number_rounded;
    case EventStatus.live:
      return Icons.play_circle_rounded;
    case EventStatus.completed:
      return Icons.task_alt_rounded;
    case EventStatus.cancelled:
      return Icons.cancel_rounded;
    case EventStatus.draft:
      return Icons.edit_note_rounded;
    case EventStatus.pending_approval:
      return Icons.hourglass_top_rounded;
    case EventStatus.waiting_event_date:
      return Icons.event_rounded;
    case EventStatus.under_review:
      return Icons.warning_amber_rounded;
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


  // Organizer dashboard
  Map<String, dynamic>? _dashboardData;
  List<dynamic>? _statusBreakdownAll;
  bool _dashboardLoading = false;
  String? _dashboardError;
  Map<String, dynamic>? _timeSeriesData;
  bool _timeSeriesLoading = false;
  int _chartDays = 30;
  int? _activityFilterEventId;
  String? _dashboardStatusFilter;
  String? _dashboardGenreFilter;
  String? _dashboardKpiFilter; // 'tickets' or 'backers'
  int? _dashboardEventId;
  String? _dashboardEventTitle;
  List<Event> _statusFilteredEvents = [];
  List<Event> _kpiFilteredEvents = [];
  bool _statusFilterLoading = false;
  bool _kpiFilterLoading = false;

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
      _loadDashboard();
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
      setState(() {
        _navIndex = widget.initialTab;
        _dashboardStatusFilter = null;
        _dashboardGenreFilter = null;
        _dashboardKpiFilter = null;
        _dashboardEventId = null;
        _dashboardEventTitle = null;
        _statusFilteredEvents = [];
        _kpiFilteredEvents = [];
      });
      if (widget.initialTab == 0) _loadDashboard();
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

  Future<void> _refreshSponsorData() async {
    await _loadSponsorBidEvents();
  }

  Future<void> _loadDashboard({String? statusFilter, int? eventId, String? genre}) async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null || !(auth.user!.isOrganizer || auth.user!.isAdmin)) return;
    setState(() { _dashboardLoading = true; _dashboardError = null; });
    try {
      final api = context.read<ApiService>();
      final data = await api.getOrganizerDashboard(status: statusFilter, eventId: eventId, genre: genre);
      if (mounted) {
        setState(() {
          _dashboardData = data;
          if (statusFilter == null && eventId == null && genre == null) {
            _statusBreakdownAll = (data['status_breakdown'] as List?)?.toList();
          }
          _dashboardLoading = false;
        });
        _loadTimeSeries(statusFilter: statusFilter, eventId: eventId, genre: genre);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dashboardError = ApiService.extractError(e);
          _dashboardLoading = false;
        });
      }
    }
  }

  Future<void> _loadTimeSeries({String? statusFilter, int? eventId, String? genre}) async {
    setState(() => _timeSeriesLoading = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getOrganizerTimeSeries(
        days: _chartDays, status: statusFilter, eventId: eventId, genre: genre,
      );
      if (mounted) setState(() { _timeSeriesData = data; _timeSeriesLoading = false; });
    } catch (e) {
      debugPrint('_loadTimeSeries error: $e');
      if (mounted) setState(() => _timeSeriesLoading = false);
    }
  }

  Future<void> _loadStatusFilteredEvents(String status) async {
    setState(() {
      _statusFilterLoading = true;
      _dashboardEventId = null;
      _dashboardEventTitle = null;
      _dashboardGenreFilter = null;
      _dashboardKpiFilter = null;
      _kpiFilteredEvents = [];
    });
    _loadDashboard(statusFilter: status);
    try {
      final api = context.read<ApiService>();
      final user = context.read<AuthProvider>().user;
      final data = await api.getEvents(params: {
        'status': status,
        'include_all_statuses': true,
        if (user != null && user.isOrganizer) 'organizer_id': user.id,
      }, limit: 50);
      if (mounted) {
        setState(() {
          _statusFilteredEvents = data.map((e) => Event.fromJson(e)).toList();
          _statusFilterLoading = false;
        });
        _batchCheckBookmarks(_statusFilteredEvents.map((e) => e.id).toList());
      }
    } catch (e) {
      debugPrint('_loadStatusFilteredEvents error: $e');
      if (mounted) setState(() => _statusFilterLoading = false);
    }
  }

  Future<void> _loadKpiFilteredEvents(String kpi) async {
    setState(() {
      _kpiFilterLoading = true;
      _dashboardEventId = null;
      _dashboardEventTitle = null;
      _dashboardGenreFilter = null;
      _dashboardStatusFilter = null;
      _statusFilteredEvents = [];
    });
    try {
      final api = context.read<ApiService>();
      final user = context.read<AuthProvider>().user;
      final data = await api.getEvents(params: {
        'include_all_statuses': true,
        if (user != null && user.isOrganizer) 'organizer_id': user.id,
      }, limit: 100);
      if (mounted) {
        final allEvents = data.map((e) => Event.fromJson(e)).toList();
        final List<Event> filtered;
        switch (kpi) {
          case 'tickets':
            filtered = allEvents.where((e) => e.ticketsSoldCount > 0).toList();
          case 'backers':
            filtered = allEvents.where((e) => (e.totalPledgedCents ?? 0) > 0).toList();
          default:
            filtered = allEvents;
        }
        setState(() {
          _kpiFilteredEvents = filtered;
          _kpiFilterLoading = false;
        });
        _batchCheckBookmarks(filtered.map((e) => e.id).toList());
      }
    } catch (e) {
      debugPrint('_loadKpiFilteredEvents error: $e');
      if (mounted) setState(() => _kpiFilterLoading = false);
    }
  }

  Future<void> _loadFeatured() async {
    try {
      final api = context.read<ApiService>();
      final auth = context.read<AuthProvider>();
      final isSponsor = auth.user != null && auth.user!.isSponsor &&
          !(auth.user!.isOrganizer || auth.user!.isAdmin);
      final results = await Future.wait([
        api.getFeaturedEvents(sponsorshipOnly: isSponsor),
        api.dio.get('/events', queryParameters: {
          'community_rules': 'true',
          if (isSponsor) 'sponsorship_only': true,
        }).then((r) => r.data as List),
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
    if (tabIndex == 0) {
      if (user != null && (user.isOrganizer || user.isAdmin)) {
        _loadDashboard();
      }
      if (_isStale(_featuredLoadedAt)) {
        _loadFeatured();
      }
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
      final auth = context.read<AuthProvider>();
      final isSponsor = auth.user != null && auth.user!.isSponsor &&
          !(auth.user!.isOrganizer || auth.user!.isAdmin);
      final data = await api.getMapEvents(
        lat: pos.latitude,
        lng: pos.longitude,
        radiusKm: 25,
      );
      if (mounted) {
        final ids = data
            .map((e) => e['id'] as int)
            .take(10)
            .toList();
        if (ids.isNotEmpty) {
          final fullEvents = <Event>[];
          final allEvents = await api.getEvents(params: {
            if (isSponsor) 'sponsorship_only': true,
          });
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

  void _homeSearch() {
    if (!_isHomeFiltered) {
      setState(() => _homeSearchResults = []);
      return;
    }

    final seen = <int>{};
    final allEvents = <Event>[];
    for (final list in [_nearMeEvents, _trending, _comingSoon, _popular, _communityEvents, _myEvents]) {
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
      return true;
    }).toList();

    setState(() => _homeSearchResults = results);
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
    // Sponsors only see events with sponsorship categories
    if (user != null && user.isSponsor && !(user.isOrganizer || user.isAdmin)) {
      filters['sponsorship_only'] = true;
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
        setState(() {
          _navIndex = index;
          _dashboardStatusFilter = null;
          _dashboardGenreFilter = null;
          _dashboardKpiFilter = null;
          _dashboardEventId = null;
          _dashboardEventTitle = null;
          _statusFilteredEvents = [];
          _kpiFilteredEvents = [];
        });
        if (index == 0) _loadDashboard();
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

    final isOrg = user != null && (user.isOrganizer || user.isAdmin);

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        final futures = <Future>[_loadFeatured(), _loadMyEvents()];
        if (isOrg) futures.add(_loadDashboard(
          statusFilter: _dashboardStatusFilter,
          eventId: _dashboardEventId,
          genre: _dashboardGenreFilter,
        ));
        await Future.wait(futures);
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
                              isOrg ? "Here's your overview" : 'Welcome back',
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
                  if (!isOrg) ...[
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
                    onChanged: (_) {
                      _homeSearch();
                    },
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
                            selectedColor: _statusChipColor(context, s),
                            backgroundColor: AppTheme.cardOf(context),
                            side: BorderSide(
                              color: isActive
                                  ? _statusChipColor(context, s)
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
                ],
              ),
            ),
          ),

          // ── Organizer: Status Chips (top) ──────────────────────
          if (isOrg) ...[
            if (_dashboardData != null || _statusBreakdownAll != null)
              SliverToBoxAdapter(child: _buildStatusChips()),
          ],

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
            if (isOrg && _dashboardStatusFilter != null) ...[
              if (_statusFilterLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.huge),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_statusFilteredEvents.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'No events',
                    subtitle: 'No events with this status',
                  ),
                )
              else ...[
                Builder(builder: (_) {
                  final genres = _statusFilteredEvents
                      .map((e) => e.genre)
                      .where((g) => g != null && g.isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort();
                  final displayEvents = _dashboardGenreFilter != null
                      ? _statusFilteredEvents.where((e) => e.genre == _dashboardGenreFilter).toList()
                      : _statusFilteredEvents;
                  return _buildFeaturedSection(
                    '${_statusDisplayName(EventStatus.values.firstWhere(
                      (s) => s.name == _dashboardStatusFilter,
                      orElse: () => EventStatus.draft,
                    ))} Events',
                    _statusChipIcon(EventStatus.values.firstWhere(
                      (s) => s.name == _dashboardStatusFilter,
                      orElse: () => EventStatus.draft,
                    )),
                    displayEvents,
                    0,
                    onSeeAll: () {
                      setState(() {
                        _selectedStatus = _dashboardStatusFilter;
                        _navIndex = 1;
                      });
                      _applyFilters();
                      context.go('/?tab=explore');
                    },
                    trailing: GestureDetector(
                      onTap: () {
                        setState(() {
                          _dashboardStatusFilter = null;
                          _dashboardEventId = null;
                          _dashboardEventTitle = null;
                          _dashboardGenreFilter = null;
                        });
                        _loadDashboard();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceOf(context),
                          borderRadius: AppRadius.pill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close, size: 14, color: AppTheme.textSecondaryOf(context)),
                            const SizedBox(width: 4),
                            Text('Clear', style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondaryOf(context),
                            )),
                          ],
                        ),
                      ),
                    ),
                    onEventTap: (event) {
                      if (_dashboardEventId == event.id) {
                        setState(() {
                          _dashboardEventId = null;
                          _dashboardEventTitle = null;
                        });
                        _loadDashboard(statusFilter: _dashboardStatusFilter, genre: _dashboardGenreFilter);
                      } else {
                        setState(() {
                          _dashboardEventId = event.id;
                          _dashboardEventTitle = event.title;
                        });
                        _loadDashboard(eventId: event.id, genre: _dashboardGenreFilter);
                      }
                    },
                    genreChips: genres.length > 1
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: SizedBox(
                              height: 34,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                                children: [
                                  _genreChip('All', null),
                                  for (final g in genres) _genreChip(g!, g),
                                ],
                              ),
                            ),
                          )
                        : null,
                  );
                }),
                if (_dashboardEventTitle != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 0),
                      child: Row(
                        children: [
                          Icon(Icons.filter_alt_rounded, size: 16, color: AppTheme.primaryColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Showing metrics for: $_dashboardEventTitle',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _dashboardEventId = null;
                                _dashboardEventTitle = null;
                              });
                              _loadDashboard(statusFilter: _dashboardStatusFilter, genre: _dashboardGenreFilter);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.close, size: 16, color: AppTheme.textSecondaryOf(context)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ] else if (isOrg && _dashboardKpiFilter != null) ...[
              if (_kpiFilterLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.huge),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_kpiFilteredEvents.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: _kpiIcon(_dashboardKpiFilter!),
                    title: _kpiEmptyTitle(_dashboardKpiFilter!),
                    subtitle: _kpiEmptySubtitle(_dashboardKpiFilter!),
                  ),
                )
              else ...[
                Builder(builder: (_) {
                  final genres = _kpiFilteredEvents
                      .map((e) => e.genre)
                      .where((g) => g != null && g.isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort();
                  final displayEvents = _dashboardGenreFilter != null
                      ? _kpiFilteredEvents.where((e) => e.genre == _dashboardGenreFilter).toList()
                      : _kpiFilteredEvents;
                  return _buildFeaturedSection(
                    _kpiSectionTitle(_dashboardKpiFilter!),
                    _kpiIcon(_dashboardKpiFilter!),
                    displayEvents,
                    0,
                    onSeeAll: () {
                      setState(() => _navIndex = 1);
                      context.go('/?tab=explore');
                    },
                    trailing: GestureDetector(
                      onTap: () {
                        setState(() {
                          _dashboardKpiFilter = null;
                          _kpiFilteredEvents = [];
                          _dashboardEventId = null;
                          _dashboardEventTitle = null;
                          _dashboardGenreFilter = null;
                        });
                        _loadDashboard();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceOf(context),
                          borderRadius: AppRadius.pill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close, size: 14, color: AppTheme.textSecondaryOf(context)),
                            const SizedBox(width: 4),
                            Text('Clear', style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondaryOf(context),
                            )),
                          ],
                        ),
                      ),
                    ),
                    onEventTap: (event) {
                      if (_dashboardEventId == event.id) {
                        setState(() {
                          _dashboardEventId = null;
                          _dashboardEventTitle = null;
                        });
                        _loadDashboard(genre: _dashboardGenreFilter);
                      } else {
                        setState(() {
                          _dashboardEventId = event.id;
                          _dashboardEventTitle = event.title;
                        });
                        _loadDashboard(eventId: event.id, genre: _dashboardGenreFilter);
                      }
                    },
                    genreChips: genres.length > 1
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: SizedBox(
                              height: 34,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                                children: [
                                  _genreChip('All', null),
                                  for (final g in genres) _genreChip(g!, g),
                                ],
                              ),
                            ),
                          )
                        : null,
                  );
                }),
                if (_dashboardEventTitle != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 0),
                      child: Row(
                        children: [
                          Icon(Icons.filter_alt_rounded, size: 16, color: AppTheme.accentColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Showing metrics for: $_dashboardEventTitle',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _dashboardEventId = null;
                                _dashboardEventTitle = null;
                              });
                              _loadDashboard(genre: _dashboardGenreFilter);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.close, size: 16, color: AppTheme.textSecondaryOf(context)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ],

          // ── Organizer Dashboard (KPI + Charts) ──────────────────
          if (isOrg) ...[
            if (_dashboardLoading && _dashboardData == null)
              SliverToBoxAdapter(child: _buildDashboardShimmer())
            else if (_dashboardError != null && _dashboardData == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: ErrorState(
                    message: _dashboardError!,
                    onRetry: _loadDashboard,
                  ),
                ),
              )
            else if (_dashboardData != null) ...[
              SliverToBoxAdapter(child: _buildKpiSection()),
              SliverToBoxAdapter(child: _buildChartSection()),
            ],
          ],

          // ── Discover / Featured Sections ──────────────────────
          if (_dashboardStatusFilter == null && _dashboardKpiFilter == null) ...[
            if (isOrg)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: AppRadius.pill,
                        ),
                      ),
                      AppSpacing.hMd,
                      Text(
                        'Discover',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (!isOrg && _nearMeEvents.isNotEmpty)
              _buildFeaturedSection(
                  'Near Me', Icons.near_me_rounded, _nearMeEvents, 0),

            if (!_featuredLoading) ...[
              if (_trending.isNotEmpty)
                _buildFeaturedSection('Trending Now',
                    Icons.local_fire_department_rounded, _trending, 1),
              if (!isOrg && _comingSoon.isNotEmpty)
                _buildFeaturedSection(
                    'Coming Soon', Icons.upcoming_rounded, _comingSoon, 2),
              if (_popular.isNotEmpty)
                _buildFeaturedSection(
                    'Most Popular', Icons.star_rounded, _popular, 3),
              if (!isOrg && _communityEvents.isNotEmpty)
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
                                selectedColor: _statusChipColor(context, s),
                                backgroundColor: AppTheme.cardOf(context),
                                side: BorderSide(
                                  color: isActive
                                      ? _statusChipColor(context, s)
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
                    color: AppTheme.cardOf(context),
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
    final activeColor = AppTheme.textPrimaryOf(context);
    final inactiveColor = AppTheme.textSecondaryOf(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.normal,
        curve: AppCurve.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.surfaceOf(context) : Colors.transparent,
          borderRadius: AppRadius.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppIconSize.sm,
              color: isActive ? activeColor : inactiveColor,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? activeColor : inactiveColor,
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

  String _formatCents(int cents) {
    if (cents >= 100000) return '\$${(cents / 100).toStringAsFixed(0)}';
    return '\$${(cents / 100).toStringAsFixed(2)}';
  }

  String _relativeTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(dt);
  }

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
              AppSpacing.xxl, 56, AppSpacing.xxl, AppSpacing.xl,
            ),
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
        ),
        SliverToBoxAdapter(child: _buildQuickActionsSection(user)),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ── Dashboard Shimmer ────────────────────────────────────────────────

  Widget _buildDashboardShimmer() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          AppSpacing.vLg,
          Row(
            children: [
              Expanded(child: _shimmerBox(height: 110)),
              AppSpacing.hMd,
              Expanded(child: _shimmerBox(height: 110)),
            ],
          ),
          AppSpacing.vMd,
          Row(
            children: [
              Expanded(child: _shimmerBox(height: 110)),
              AppSpacing.hMd,
              Expanded(child: _shimmerBox(height: 110)),
            ],
          ),
          AppSpacing.vXl,
          _shimmerBox(height: 40),
          AppSpacing.vXl,
          _shimmerBox(height: 200),
          AppSpacing.vXl,
          _shimmerBox(height: 180),
        ],
      ),
    );
  }

  Widget _shimmerBox({required double height}) {
    final isDark = AppTheme.isDark(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
        borderRadius: AppRadius.lg,
      ),
    ).animate(onPlay: (c) => c.repeat())
      .shimmer(duration: 1200.ms, color: isDark ? Colors.white12 : Colors.white60);
  }

  // ── B. KPI Cards ─────────────────────────────────────────────────────

  Widget _buildKpiSection() {
    final d = _dashboardData!;
    final revenue = d['total_revenue'] as Map<String, dynamic>;
    final tickets = d['tickets_sold'] as Map<String, dynamic>;
    final backers = d['total_backers'] as Map<String, dynamic>;
    final refundRate = d['refund_rate'] as Map<String, dynamic>?;
    final events = d['total_events'] as Map<String, dynamic>;
    final sponsors = d['total_sponsors'] as Map<String, dynamic>?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
      child: Column(
        children: [
          AnimatedListItem(
            index: 0,
            child: Row(
              children: [
                Expanded(
                  child: _DashboardKpiCard(
                    icon: Icons.attach_money_rounded,
                    label: 'Total Revenue',
                    value: _formatCents(revenue['value'] as int? ?? 0),
                    deltaPercent: (revenue['delta_percent'] as num?)?.toDouble(),
                    accentColor: AppTheme.successColor,
                  ),
                ),
                AppSpacing.hMd,
                Expanded(
                  child: _DashboardKpiCard(
                    icon: Icons.confirmation_number_rounded,
                    label: 'Tickets Sold',
                    value: '${tickets['value'] ?? 0}',
                    deltaPercent: (tickets['delta_percent'] as num?)?.toDouble(),
                    accentColor: context.ticketAccent,
                    onTap: () {
                      final statusQ = _dashboardStatusFilter;
                      final path = statusQ != null
                          ? '/manage/ticket-sales?event_status=$statusQ'
                          : '/manage/ticket-sales';
                      context.push(path);
                    },
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.vMd,
          AnimatedListItem(
            index: 1,
            child: Row(
              children: [
                Expanded(
                  child: _DashboardKpiCard(
                    icon: Icons.volunteer_activism_rounded,
                    label: 'Total Backers',
                    value: '${backers['value'] ?? 0}',
                    deltaPercent: (backers['delta_percent'] as num?)?.toDouble(),
                    accentColor: context.fundingAccent,
                    onTap: () {
                      final statusQ = _dashboardStatusFilter;
                      final path = statusQ != null
                          ? '/manage/pledges?event_status=$statusQ'
                          : '/manage/pledges';
                      context.push(path);
                    },
                  ),
                ),
                AppSpacing.hMd,
                Expanded(
                  child: _DashboardKpiCard(
                    icon: Icons.handshake_rounded,
                    label: 'Total Sponsors',
                    value: '${sponsors?['value'] ?? 0}',
                    deltaPercent: (sponsors?['delta_percent'] as num?)?.toDouble(),
                    accentColor: context.sponsorAccent,
                    onTap: () {
                      final statusQ = _dashboardStatusFilter;
                      final path = statusQ != null
                          ? '/manage/sponsors?event_status=$statusQ'
                          : '/manage/sponsors';
                      context.push(path);
                    },
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.vMd,
          AnimatedListItem(
            index: 2,
            child: Row(
              children: [
                Expanded(
                  child: _DashboardKpiCard(
                    icon: Icons.event_rounded,
                    label: 'Total Events',
                    value: '${events['value'] ?? 0}',
                    deltaPercent: (events['delta_percent'] as num?)?.toDouble(),
                    accentColor: context.managementAccent,
                    isActive: false,
                    onTap: () {
                      setState(() {
                        _selectedStatus = _dashboardStatusFilter;
                        _navIndex = 1;
                      });
                      _applyFilters();
                      context.go('/?tab=explore');
                    },
                  ),
                ),
                AppSpacing.hMd,
                Expanded(
                  child: _DashboardKpiCard(
                    icon: Icons.undo_rounded,
                    label: 'Refund Rate',
                    value: '${(refundRate?['value'] as num?)?.toStringAsFixed(1) ?? '0.0'}%',
                    deltaPercent: (refundRate?['delta_percent'] as num?)?.toDouble(),
                    accentColor: AppTheme.errorColor,
                    invertDelta: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _kpiIcon(String kpi) => switch (kpi) {
    'tickets' => Icons.confirmation_number_rounded,
    'backers' => Icons.volunteer_activism_rounded,
    'sponsors' => Icons.handshake_rounded,
    'events' => Icons.event_rounded,
    _ => Icons.bar_chart_rounded,
  };

  String _kpiSectionTitle(String kpi) => switch (kpi) {
    'tickets' => 'Events with Ticket Sales',
    'backers' => 'Events with Backers',
    'sponsors' => 'Sponsored Events',
    'events' => 'All Events',
    _ => 'Events',
  };

  String _kpiEmptyTitle(String kpi) => switch (kpi) {
    'tickets' => 'No ticket sales',
    'backers' => 'No backers yet',
    'sponsors' => 'No sponsors yet',
    'events' => 'No events',
    _ => 'No events',
  };

  String _kpiEmptySubtitle(String kpi) => switch (kpi) {
    'tickets' => 'None of your events have sold tickets',
    'backers' => 'None of your events have received pledges',
    'sponsors' => 'None of your events have sponsors',
    'events' => 'You have not created any events yet',
    _ => 'No matching events found',
  };

  Widget _genreChip(String label, String? value) {
    final isActive = _dashboardGenreFilter == value;
    final isDark = AppTheme.isDark(context);
    const color = AppTheme.accentColor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _dashboardGenreFilter = value);
          _loadDashboard(
            statusFilter: _dashboardStatusFilter,
            eventId: _dashboardEventId,
            genre: value,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? color : color.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: AppRadius.pill,
            border: Border.all(
              color: isActive ? color : color.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? Theme.of(context).colorScheme.onSecondary
                  : color,
            ),
          ),
        ),
      ),
    );
  }

  // ── C. Status Breakdown ──────────────────────────────────────────────

  Widget _buildStatusChips() {
    final breakdown = ((_statusBreakdownAll ?? _dashboardData!['status_breakdown'] as List?) ?? [])
        .where((item) => (item as Map<String, dynamic>)['status'] != 'draft')
        .toList();
    if (breakdown.isEmpty) return const SizedBox.shrink();
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
      child: AnimatedListItem(
        index: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event Status',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryOf(context), letterSpacing: 0.5,
              ),
            ),
            AppSpacing.vMd,
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < breakdown.length; i++) ...[
                    if (i > 0) AppSpacing.hSm,
                    Builder(builder: (ctx) {
                      final item = breakdown[i] as Map<String, dynamic>;
                      final status = item['status'] as String;
                      final count = item['count'] as int? ?? 0;
                      final statusEnum = EventStatus.values.firstWhere(
                        (s) => s.name == status, orElse: () => EventStatus.draft,
                      );
                      final color = _statusChipColor(context, statusEnum);
                      final isActive = _dashboardStatusFilter == status;
                      return GestureDetector(
                        onTap: () {
                          if (isActive) {
                            setState(() {
                              _dashboardStatusFilter = null;
                              _dashboardGenreFilter = null;
                              _dashboardKpiFilter = null;
                              _dashboardEventId = null;
                              _dashboardEventTitle = null;
                              _statusFilteredEvents = [];
                              _kpiFilteredEvents = [];
                            });
                            _loadDashboard();
                          } else {
                            setState(() {
                              _dashboardStatusFilter = status;
                              _statusFilterLoading = true;
                            });
                            _loadStatusFilteredEvents(status);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive ? color : color.withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: AppRadius.pill,
                            border: Border.all(color: isActive ? color : color.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _statusDisplayName(statusEnum),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                    color: isActive ? Colors.white : color),
                              ),
                              AppSpacing.hXs,
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.2),
                                  borderRadius: AppRadius.pill,
                                ),
                                child: Text('$count',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                                      color: isActive ? Colors.white : color),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: (80 * i).ms, duration: 300.ms)
                        .slideX(begin: 0.1, duration: 300.ms, curve: Curves.easeOut);
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── D. Time-Series Chart ─────────────────────────────────────────────

  Widget _buildChartSection() {
    final isDark = AppTheme.isDark(context);
    final isLoading = _timeSeriesLoading && _timeSeriesData == null;
    final hasData = _timeSeriesData != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0),
          child: AnimatedListItem(
            index: 3,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppTheme.cardOf(context),
                borderRadius: AppRadius.lg,
                boxShadow: AppShadow.soft(isDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.attach_money_rounded, size: AppIconSize.md, color: AppTheme.accentColor),
                      AppSpacing.hSm,
                      Text('Revenue',
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                      const Spacer(),
                      _chartPeriodToggle(),
                    ],
                  ),
                  AppSpacing.vLg,
                  SizedBox(
                    height: 200,
                    child: isLoading
                      ? _shimmerBox(height: 200)
                      : hasData
                        ? _buildRevenueChart()
                        : Center(
                            child: Text('No data yet',
                              style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
          child: AnimatedListItem(
            index: 4,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppTheme.cardOf(context),
                borderRadius: AppRadius.lg,
                boxShadow: AppShadow.soft(isDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.insights_rounded, size: AppIconSize.md, color: AppTheme.successColor),
                      AppSpacing.hSm,
                      Text('Activity',
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vSm,
                  Row(
                    children: [
                      _chartLegendDot(context.ticketAccent, 'Tickets'),
                      AppSpacing.hMd,
                      _chartLegendDot(context.fundingAccent, 'Pledges'),
                    ],
                  ),
                  AppSpacing.vLg,
                  SizedBox(
                    height: 200,
                    child: isLoading
                      ? _shimmerBox(height: 200)
                      : hasData
                        ? _buildActivityChart()
                        : Center(
                            child: Text('No data yet',
                              style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chartLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
      ],
    );
  }

  Widget _chartPeriodToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final days in [7, 30, 90])
            GestureDetector(
              onTap: () {
                if (_chartDays != days) {
                  setState(() => _chartDays = days);
                  _loadTimeSeries(statusFilter: _dashboardStatusFilter, eventId: _dashboardEventId, genre: _dashboardGenreFilter);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _chartDays == days ? AppTheme.accentColor : Colors.transparent,
                  borderRadius: AppRadius.pill,
                ),
                child: Text(
                  '${days}d',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _chartDays == days
                      ? Colors.white
                      : AppTheme.textSecondaryOf(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    final points = (_timeSeriesData!['points'] as List?) ?? [];
    if (points.isEmpty) {
      return Center(
        child: Text('No data for this period',
          style: TextStyle(color: AppTheme.textSecondaryOf(context)),
        ),
      );
    }

    final isDark = AppTheme.isDark(context);
    final revenueColor = AppTheme.accentColor;

    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      final p = points[i] as Map;
      spots.add(FlSpot(i.toDouble(), ((p['revenue_cents'] as num?)?.toDouble() ?? 0) / 100));
    }

    final maxY = spots.map((s) => s.y).reduce(math.max);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2 + 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 4 : 1,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppTheme.dividerOf(context),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: _chartTitles(points),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.cardOf(context),
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              return LineTooltipItem(
                '\$${s.y.toStringAsFixed(0)}',
                TextStyle(color: revenueColor, fontWeight: FontWeight.w700, fontSize: 12),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: revenueColor,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: revenueColor.withValues(alpha: isDark ? 0.15 : 0.08),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildActivityChart() {
    final points = (_timeSeriesData!['points'] as List?) ?? [];
    if (points.isEmpty) {
      return Center(
        child: Text('No data for this period',
          style: TextStyle(color: AppTheme.textSecondaryOf(context)),
        ),
      );
    }

    final isDark = AppTheme.isDark(context);
    final ticketColor = context.ticketAccent;
    final pledgeColor = context.fundingAccent;

    final ticketSpots = <FlSpot>[];
    final pledgeSpots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      final p = points[i] as Map;
      ticketSpots.add(FlSpot(i.toDouble(), (p['tickets_sold'] as num?)?.toDouble() ?? 0));
      pledgeSpots.add(FlSpot(i.toDouble(), (p['pledges_count'] as num?)?.toDouble() ?? 0));
    }

    final maxY = math.max(
      ticketSpots.map((s) => s.y).reduce(math.max),
      pledgeSpots.map((s) => s.y).reduce(math.max),
    );

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2 + 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 4 : 1,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppTheme.dividerOf(context),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: _chartTitles(points),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.cardOf(context),
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final isTicket = s.barIndex == 0;
              return LineTooltipItem(
                isTicket ? '${s.y.toInt()} tickets' : '${s.y.toInt()} pledges',
                TextStyle(
                  color: isTicket ? ticketColor : pledgeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: ticketSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: ticketColor,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: ticketColor.withValues(alpha: isDark ? 0.15 : 0.08),
            ),
          ),
          LineChartBarData(
            spots: pledgeSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: pledgeColor,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: pledgeColor.withValues(alpha: isDark ? 0.15 : 0.08),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  FlTitlesData _chartTitles(List points) {
    return FlTitlesData(
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: math.max(1, (points.length / 5).ceilToDouble()),
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
            final dateStr = (points[idx] as Map)['date'] as String? ?? '';
            final dt = DateTime.tryParse(dateStr);
            if (dt == null) return const SizedBox.shrink();
            return Text(
              DateFormat.MMMd().format(dt),
              style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context)),
            );
          },
        ),
      ),
    );
  }

  // ── E. Event Carousels ───────────────────────────────────────────────

  List<Widget> _buildCarouselSections() {
    final trending = (_dashboardData!['trending_events'] as List?) ?? [];
    final top = (_dashboardData!['top_events'] as List?) ?? [];

    if (trending.isEmpty && top.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0),
            child: AnimatedListItem(
              index: 4,
              child: EmptyState(
                icon: Icons.rocket_launch_rounded,
                title: 'Create your first event',
                subtitle: 'Your trending and top-earning events will appear here.',
              ),
            ),
          ),
        ),
      ];
    }

    return [
      if (trending.isNotEmpty)
        SliverToBoxAdapter(
          child: _buildEventCarousel(
            title: 'Your Trending Events',
            icon: Icons.trending_up_rounded,
            events: trending,
            index: 4,
          ),
        ),
      if (top.isNotEmpty)
        SliverToBoxAdapter(
          child: _buildEventCarousel(
            title: 'Your Top Earners',
            icon: Icons.emoji_events_rounded,
            events: top,
            index: 5,
          ),
        ),
    ];
  }

  List<Widget> _buildTrendingPopularCarousels() {
    final trending = (_dashboardData!['trending_events'] as List?) ?? [];
    final popular = (_dashboardData!['popular_events'] as List?) ?? [];

    if (trending.isEmpty && popular.isEmpty) return [];

    return [
      if (trending.isNotEmpty)
        SliverToBoxAdapter(
          child: _buildEventCarousel(
            title: 'Trending Events',
            icon: Icons.trending_up_rounded,
            events: trending,
            index: 4,
          ),
        ),
      if (popular.isNotEmpty)
        SliverToBoxAdapter(
          child: _buildEventCarousel(
            title: 'Popular Events',
            icon: Icons.star_rounded,
            events: popular,
            index: 5,
          ),
        ),
    ];
  }

  Widget _buildEventCarousel({
    required String title,
    required IconData icon,
    required List events,
    required int index,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.xxl, 0, 0),
      child: AnimatedListItem(
        index: index,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                children: [
                  Icon(icon, size: AppIconSize.sm, color: AppTheme.accentColor),
                  AppSpacing.hSm,
                  Text(title,
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.vMd,
            SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                itemCount: events.length,
                separatorBuilder: (_, __) => AppSpacing.hMd,
                itemBuilder: (ctx, i) {
                  final e = Event.fromJson(events[i] as Map<String, dynamic>);
                  return SizedBox(
                    width: 260,
                    child: PressFeedback(
                      child: EventCard(
                        event: e,
                        isBookmarked: _bookmarkedIds.contains(e.id),
                        onBookmarkToggle: () => _toggleBookmark(e.id),
                        onTap: () => context.push('/events/${e.id}'),
                      ),
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

  // ── F. Activity Feed ─────────────────────────────────────────────────

  Widget _buildActivityFeed() {
    final feed = (_dashboardData!['recent_activity'] as List?) ?? [];
    if (feed.isEmpty) return const SizedBox.shrink();

    final isDark = AppTheme.isDark(context);
    final uniqueEvents = <int, String>{};
    for (final item in feed) {
      final m = item as Map<String, dynamic>;
      uniqueEvents[m['event_id'] as int] = m['event_title'] as String? ?? '';
    }

    final showFilter = uniqueEvents.length >= 4;
    final filtered = _activityFilterEventId == null
      ? feed
      : feed.where((item) => (item as Map)['event_id'] == _activityFilterEventId).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0),
      child: AnimatedListItem(
        index: 6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_rounded, size: AppIconSize.sm, color: context.fundingAccent),
                AppSpacing.hSm,
                Text('Recent Activity',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
            if (showFilter) ...[
              AppSpacing.vMd,
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _feedFilterChip(label: 'All', eventId: null),
                    for (final entry in uniqueEvents.entries) ...[
                      AppSpacing.hSm,
                      _feedFilterChip(
                        label: entry.value.length > 20 ? '${entry.value.substring(0, 20)}...' : entry.value,
                        eventId: entry.key,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            AppSpacing.vMd,
            for (int i = 0; i < filtered.length; i++)
              _buildActivityItem(filtered[i] as Map<String, dynamic>, i, isDark),
          ],
        ),
      ),
    );
  }

  Widget _feedFilterChip({required String label, required int? eventId}) {
    final selected = _activityFilterEventId == eventId;
    return GestureDetector(
      onTap: () => setState(() => _activityFilterEventId = eventId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentColor : AppTheme.surfaceOf(context),
          borderRadius: AppRadius.pill,
          border: selected ? null : Border.all(color: AppTheme.dividerOf(context)),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textSecondaryOf(context),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> item, int index, bool isDark) {
    final type = item['type'] as String? ?? '';
    final actorName = item['actor_name'] as String? ?? 'Someone';
    final eventTitle = item['event_title'] as String? ?? '';
    final amountCents = item['amount_cents'] as int? ?? 0;
    final createdAt = item['created_at'] as String? ?? '';

    IconData icon;
    Color iconColor;
    String action;
    switch (type) {
      case 'ticket_sale':
        icon = Icons.confirmation_number_rounded;
        iconColor = context.ticketAccent;
        action = 'bought a ticket';
      case 'pledge':
        icon = Icons.volunteer_activism_rounded;
        iconColor = context.fundingAccent;
        action = 'pledged';
      case 'sponsor_bid':
        icon = Icons.handshake_rounded;
        iconColor = context.sponsorAccent;
        final bidStatus = (item['extra'] as Map?)?['bid_status'] as String? ?? '';
        action = 'bid ($bidStatus)';
      default:
        icon = Icons.circle;
        iconColor = AppTheme.textSecondaryOf(context);
        action = 'activity';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: AppRadius.md,
          boxShadow: AppShadow.card(isDark),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: AppRadius.sm,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            AppSpacing.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: actorName,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimaryOf(context)),
                      ),
                      TextSpan(
                        text: ' $action',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context)),
                      ),
                    ]),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    eventTitle,
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            AppSpacing.hSm,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCents(amountCents),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.successColor),
                ),
                Text(
                  _relativeTime(createdAt),
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (60 * index).ms, duration: 300.ms)
      .slideY(begin: 0.05, duration: 300.ms, curve: Curves.easeOut);
  }

  // ── G. Quick Actions ─────────────────────────────────────────────────

  Widget _buildQuickActionsSection(dynamic user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryOf(context), letterSpacing: 0.5,
            ),
          ),
          AppSpacing.vLg,
          AnimatedListItem(
            index: 7,
            child: Row(
              children: [
                _quickActionCard(
                  icon: Icons.add_circle_rounded,
                  label: 'Create Event',
                  color: AppTheme.accentColor,
                  onTap: () async {
                    final created = await context.push<bool>('/events/create');
                    if (created == true && mounted) {
                      _applyFilters();
                      _loadFeatured();
                      _loadDashboard();
                    }
                  },
                ),
                AppSpacing.hMd,
                _quickActionCard(
                  icon: Icons.location_city_rounded,
                  label: 'Venues',
                  color: AppTheme.accentColor,
                  onTap: () => context.push('/venues'),
                ),
                AppSpacing.hMd,
                _quickActionCard(
                  icon: Icons.confirmation_number_rounded,
                  label: 'Ticket Tiers',
                  color: context.statusSelling,
                  onTap: () => context.push('/ticket-strategies'),
                ),
              ],
            ),
          ),
          AppSpacing.vMd,
          AnimatedListItem(
            index: 8,
            child: Row(
              children: [
                _quickActionCard(
                  icon: Icons.receipt_long_rounded,
                  label: 'All Sales',
                  color: AppTheme.successColor,
                  onTap: () => context.push('/manage/ticket-sales'),
                ),
                AppSpacing.hMd,
                _quickActionCard(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scanned',
                  color: context.sponsorAccent,
                  onTap: () => context.push('/manage/scanned-tickets'),
                ),
                AppSpacing.hMd,
                _quickActionCard(
                  icon: Icons.hourglass_top_rounded,
                  label: 'Waitlist',
                  color: context.statusPending,
                  onTap: () => context.push('/manage/waitlist'),
                ),
              ],
            ),
          ),
          AppSpacing.vMd,
          AnimatedListItem(
            index: 9,
            child: Row(
              children: [
                _quickActionCard(
                  icon: Icons.discount_rounded,
                  label: 'Discounts',
                  color: AppTheme.errorColor,
                  onTap: () => context.push('/manage/discounts'),
                ),
                AppSpacing.hMd,
                _quickActionCard(
                  icon: Icons.handshake_rounded,
                  label: 'Sponsors',
                  color: context.managementAccent,
                  onTap: () => context.push('/manage/sponsors'),
                ),
                AppSpacing.hMd,
                _quickActionCard(
                  icon: Icons.category_rounded,
                  label: 'Sponsorships',
                  color: context.sponsorAccent,
                  onTap: () => context.push('/sponsor-category-templates'),
                ),
              ],
            ),
          ),
          AppSpacing.vMd,
          AnimatedListItem(
            index: 10,
            child: Row(
              children: [
                _quickActionCard(
                  icon: Icons.volunteer_activism_rounded,
                  label: 'Pledges',
                  color: context.fundingAccent,
                  onTap: () => context.push('/manage/pledges'),
                ),
                AppSpacing.hMd,
                _quickActionCard(
                  icon: Icons.bookmark_rounded,
                  label: 'Bookmarks',
                  color: AppTheme.warningColor,
                  onTap: () => context.push('/bookmarks'),
                ),
              ],
            ),
          ),
          if (user != null && user.isAdmin) ...[
            AppSpacing.vMd,
            AnimatedListItem(
              index: 11,
              child: Row(
                children: [
                  _quickActionCard(
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Admin',
                    color: AppTheme.primaryColor,
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
                    color: AppTheme.accentColor,
                    onTap: () => context.push('/my-tickets'),
                  ),
                  AppSpacing.hSm,
                  _customerQuickAction(
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
                        selectedColor: _statusChipColor(context, s),
                        backgroundColor: AppTheme.cardOf(context),
                        side: BorderSide(
                          color: isActive
                              ? _statusChipColor(context, s)
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
    final bidCount = _sponsorBidEvents.length;

    final filteredBids = _sponsorBidEvents.where((item) {
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
                    child: Text('Sponsorships',
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gavel_rounded, size: 13,
                            color: AppTheme.textSecondaryOf(context)),
                        const SizedBox(width: 4),
                        Text(
                          '$bidCount bid${bidCount != 1 ? "s" : ""}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              AppSpacing.vLg,
              Row(
                children: [
                  _customerQuickAction(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Sponsor Tickets',
                    color: context.managementAccent,
                    onTap: () => context.push('/sponsor/tickets'),
                  ),
                  AppSpacing.hSm,
                  _customerQuickAction(
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
                          selectedColor: _statusChipColor(context, s),
                          backgroundColor: AppTheme.cardOf(context),
                          side: BorderSide(
                            color: isActive
                                ? _statusChipColor(context, s)
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
          child: _buildSponsorBidsList(filteredBids),
        ),
      ],
    );
  }


  Widget _buildSponsorBidsList(List<_SponsorBidEvent> filtered) {
    if (_sponsorBidEventsLoading) {
      return SingleChildScrollView(child: ShimmerEventList(count: 3));
    }
    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.gavel_rounded,
        title: _sponsorBidEvents.isEmpty ? 'No bids yet' : 'No matches',
        subtitle: _sponsorBidEvents.isEmpty
            ? 'Events you bid on will appear here'
            : 'Try a different search term',
      );
    }
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: _refreshSponsorData,
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
                onTap: () => context.push('/events/${item.event.id}'),
              ),
            ),
          );
        },
      ),
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
                    color: AppTheme.cardOf(context),
                    borderRadius: AppRadius.xl,
                  ),
                  child: Center(
                    child: Text(
                      user.initial,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimaryOf(context),
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
      String title, IconData icon, List<Event> items, int sectionIndex,
      {VoidCallback? onSeeAll, Widget? trailing,
       void Function(Event event)? onEventTap, Widget? genreChips}) {
    final seeAllAction = onSeeAll ?? () {
      setState(() => _navIndex = 1);
      context.go('/?tab=explore');
    };
    return SliverToBoxAdapter(
      child: AnimatedListItem(
        index: sectionIndex,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxl, bottom: AppSpacing.md),
              child: trailing != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                      child: Row(
                        children: [
                          Icon(icon, size: 20, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: AppTheme.textPrimaryOf(context),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: seeAllAction,
                            child: Text(
                              'See all',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          trailing,
                        ],
                      ),
                    )
                  : SectionHeader(
                      title: title,
                      icon: icon,
                      actionLabel: 'See all',
                      onAction: seeAllAction,
                    ),
            ),
            if (genreChips != null) genreChips,
            SizedBox(
              height: 320,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final event = items[index];
                  final isSelected = _dashboardEventId == event.id;
                  return Container(
                    width: 280,
                    margin: const EdgeInsets.only(right: AppSpacing.md),
                    decoration: isSelected ? BoxDecoration(
                      borderRadius: AppRadius.lg,
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.accentColor
                            : AppTheme.primaryColor,
                        width: 2.5,
                      ),
                    ) : null,
                    child: Stack(
                      children: [
                        EventCard(
                          event: event,
                          imageUrl: event.firstImageUrl,
                          onTap: onEventTap != null
                              ? () => onEventTap(event)
                              : () => context.push('/events/${event.id}'),
                          isBookmarked: _bookmarkedIds.contains(event.id),
                          onBookmarkToggle: () => _toggleBookmark(event.id),
                        ),
                        if (onEventTap != null)
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: GestureDetector(
                              onTap: () => context.push('/events/${event.id}'),
                              child: Icon(
                                Icons.arrow_forward,
                                size: 18,
                                color: AppTheme.textSecondaryOf(context),
                              ),
                            ),
                          ),
                      ],
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

class _DashboardKpiCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final double? deltaPercent;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool isActive;
  final bool invertDelta;

  const _DashboardKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    this.deltaPercent,
    required this.accentColor,
    this.onTap,
    this.isActive = false,
    this.invertDelta = false,
  });

  @override
  State<_DashboardKpiCard> createState() => _DashboardKpiCardState();
}

class _DashboardKpiCardState extends State<_DashboardKpiCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final accent = widget.accentColor;
    final delta = widget.deltaPercent;

    return Material(
      color: AppTheme.cardOf(context),
      borderRadius: AppRadius.lg,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: AppRadius.lg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lg,
            boxShadow: AppShadow.soft(isDark),
            border: Border.all(
              color: widget.isActive ? accent : AppTheme.dividerOf(context),
              width: widget.isActive ? 2 : 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: AppRadius.sm,
                    ),
                    child: Icon(widget.icon, size: 18, color: accent),
                  ),
                  if (delta != null) ...[
                    const Spacer(),
                    ScaleTransition(
                      scale: CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
                      child: Builder(builder: (_) {
                        final isPositive = widget.invertDelta ? delta < 0 : delta >= 0;
                        final deltaColor = isPositive ? AppTheme.successColor : AppTheme.errorColor;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: deltaColor.withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: AppRadius.pill,
                          ),
                          child: Text(
                            '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: deltaColor,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
              AppSpacing.vMd,
              Text(
                widget.value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
              AppSpacing.vXs,
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ],
          ),
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
                gradient: LinearGradient(
                  colors: [context.cardGradientStart, context.cardGradientEnd],
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
                            context.bidAccepted, Icons.check_circle_rounded),
                      if (item.paid > 0)
                        _bidChip('${item.paid} Paid',
                            context.bidPaid, Icons.payment_rounded),
                      if (item.pending > 0)
                        _bidChip('${item.pending} Under Review',
                            context.bidPending, Icons.hourglass_top_rounded),
                      if (item.rejected > 0)
                        _bidChip('${item.rejected} Rejected',
                            context.bidRejected, Icons.cancel_rounded),
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

