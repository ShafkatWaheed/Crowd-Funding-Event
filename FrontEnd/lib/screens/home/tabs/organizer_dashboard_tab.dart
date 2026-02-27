import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../home_shared.dart';
import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../models/event.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/error_state.dart';
import 'dashboard/dashboard_activity_feed.dart';
import 'dashboard/dashboard_chart_section.dart';
import 'dashboard/dashboard_event_carousel.dart';
import 'dashboard/dashboard_featured_section.dart';
import 'dashboard/dashboard_helpers.dart';
import 'dashboard/dashboard_kpi_section.dart';
import 'dashboard/dashboard_shimmer.dart';
import 'dashboard/dashboard_status_chips.dart';

class OrganizerDashboardTab extends StatefulWidget {
  final Set<int> bookmarkedIds;
  final void Function(int) onToggleBookmark;
  final void Function(List<int> eventIds)? onEventsLoaded;
  final void Function(String? status, String? genre)? onNavigateToExplore;

  const OrganizerDashboardTab({
    super.key,
    required this.bookmarkedIds,
    required this.onToggleBookmark,
    this.onEventsLoaded,
    this.onNavigateToExplore,
  });

  @override
  State<OrganizerDashboardTab> createState() => _OrganizerDashboardTabState();
}

class _OrganizerDashboardTabState extends State<OrganizerDashboardTab> {
  Map<String, dynamic>? _dashboardData;
  List<dynamic>? _statusBreakdownAll;
  bool _dashboardLoading = false;
  String? _dashboardError;
  Map<String, dynamic>? _timeSeriesData;
  bool _timeSeriesLoading = false;
  int _chartDays = 30;
  String _dashboardPeriod = '30d';
  String? _dashboardStatusFilter;
  String? _dashboardGenreFilter;
  String? _dashboardKpiFilter;
  int? _dashboardEventId;
  String? _dashboardEventTitle;
  List<Event> _statusFilteredEvents = [];
  List<Event> _kpiFilteredEvents = [];
  bool _statusFilterLoading = false;
  bool _kpiFilterLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard());
  }

  Future<void> _loadDashboard({
    String? statusFilter,
    int? eventId,
    String? genre,
  }) async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null || !(auth.user!.isOrganizer || auth.user!.isAdmin)) {
      return;
    }
    setState(() {
      _dashboardLoading = true;
      _dashboardError = null;
    });
    try {
      final api = context.read<ApiService>();
      final data = await api.getOrganizerDashboard(
        status: statusFilter,
        eventId: eventId,
        genre: genre,
        period: _dashboardPeriod,
      );
      if (mounted) {
        setState(() {
          _dashboardData = data;
          if (statusFilter == null && eventId == null && genre == null) {
            _statusBreakdownAll =
                (data['status_breakdown'] as List?)?.toList();
          }
          _dashboardLoading = false;
        });
        _loadTimeSeries(
          statusFilter: statusFilter,
          eventId: eventId,
          genre: genre,
        );
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

  Future<void> _loadTimeSeries({
    String? statusFilter,
    int? eventId,
    String? genre,
  }) async {
    setState(() => _timeSeriesLoading = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getOrganizerTimeSeries(
        days: _chartDays,
        status: statusFilter,
        eventId: eventId,
        genre: genre,
      );
      if (mounted) {
        setState(() {
          _timeSeriesData = data;
          _timeSeriesLoading = false;
        });
      }
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
      final result = await api.getEvents(
        params: {
          'status': status,
          'include_all_statuses': true,
          if (user != null && user.isOrganizer) 'organizer_id': user.id,
        },
        limit: 50,
      );
      if (mounted) {
        final data = (result['items'] as List?) ?? [];
        setState(() {
          _statusFilteredEvents =
              data.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
          _statusFilterLoading = false;
        });
        widget.onEventsLoaded
            ?.call(_statusFilteredEvents.map((e) => e.id).toList());
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
      final result = await api.getEvents(
        params: {
          'include_all_statuses': true,
          if (user != null && user.isOrganizer) 'organizer_id': user.id,
        },
        limit: 100,
      );
      if (mounted) {
        final data = (result['items'] as List?) ?? [];
        final allEvents =
            data.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
        final List<Event> filtered;
        switch (kpi) {
          case 'tickets':
            filtered =
                allEvents.where((e) => e.ticketsSoldCount > 0).toList();
          case 'backers':
            filtered = allEvents
                .where((e) => (e.totalPledgedCents ?? 0) > 0)
                .toList();
          default:
            filtered = allEvents;
        }
        setState(() {
          _kpiFilteredEvents = filtered;
          _kpiFilterLoading = false;
        });
        widget.onEventsLoaded?.call(filtered.map((e) => e.id).toList());
      }
    } catch (e) {
      debugPrint('_loadKpiFilteredEvents error: $e');
      if (mounted) setState(() => _kpiFilterLoading = false);
    }
  }

  void _pushWithParams(String basePath) {
    if (basePath == '/events') {
      if (_dashboardEventId != null) {
        context.push('/events/$_dashboardEventId');
      } else {
        widget.onNavigateToExplore?.call(
            _dashboardStatusFilter, _dashboardGenreFilter);
      }
      return;
    }
    final params = <String, String>{};
    if (_dashboardStatusFilter != null) {
      params['event_status'] = _dashboardStatusFilter!;
    }
    if (_dashboardGenreFilter != null) {
      params['genre'] = _dashboardGenreFilter!;
    }
    if (_dashboardEventId != null) {
      params['event_id'] = _dashboardEventId.toString();
    }
    if (_dashboardEventTitle != null) {
      params['event_title'] = _dashboardEventTitle!;
    }
    final query = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final path = query.isNotEmpty ? '$basePath?$query' : basePath;
    context.push(path);
  }

  void _clearAllFilters() {
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
  }

  void _onGenreSelected(String? genre) {
    setState(() => _dashboardGenreFilter = genre);
    _loadDashboard(
      statusFilter: _dashboardStatusFilter,
      eventId: _dashboardEventId,
      genre: genre,
    );
  }

  void _onFilteredEventTap(Event event, {bool isStatusFilter = false}) {
    if (_dashboardEventId == event.id) {
      setState(() {
        _dashboardEventId = null;
        _dashboardEventTitle = null;
      });
    } else {
      setState(() {
        _dashboardEventId = event.id;
        _dashboardEventTitle = event.title;
      });
    }
    _loadDashboard(
      statusFilter: isStatusFilter ? _dashboardStatusFilter : null,
      eventId: _dashboardEventId,
      genre: _dashboardGenreFilter,
    );
  }

  void _clearEventFilter() {
    setState(() {
      _dashboardEventId = null;
      _dashboardEventTitle = null;
    });
    _loadDashboard(
      statusFilter: _dashboardStatusFilter,
      genre: _dashboardGenreFilter,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () => _loadDashboard(
        statusFilter: _dashboardStatusFilter,
        eventId: _dashboardEventId,
        genre: _dashboardGenreFilter,
      ),
      child: CustomScrollView(
        slivers: [
          if (_dashboardData != null || _statusBreakdownAll != null)
            SliverToBoxAdapter(
              child: DashboardStatusChips(
                breakdown: _statusBreakdownAll ??
                    (_dashboardData?['status_breakdown'] as List?) ??
                    [],
                activeStatus: _dashboardStatusFilter,
                onStatusSelected: (status) {
                  setState(() {
                    _dashboardStatusFilter = status;
                    _statusFilterLoading = true;
                  });
                  _loadStatusFilteredEvents(status);
                },
                onStatusCleared: _clearAllFilters,
              ),
            ),

          // Status-filtered event section
          if (_dashboardStatusFilter != null) ...[
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
              SliverToBoxAdapter(
                  child: _buildFilteredSection(isStatusFilter: true)),
              if (_dashboardEventTitle != null)
                SliverToBoxAdapter(
                  child: DashboardEventFilterBanner(
                    eventTitle: _dashboardEventTitle!,
                    isStatusFilter: true,
                    onClear: _clearEventFilter,
                  ),
                ),
            ],
          ]

          // KPI-filtered event section
          else if (_dashboardKpiFilter != null) ...[
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
                  icon: kpiIcon(_dashboardKpiFilter!),
                  title: kpiEmptyTitle(_dashboardKpiFilter!),
                  subtitle: kpiEmptySubtitle(_dashboardKpiFilter!),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                  child: _buildFilteredSection(isStatusFilter: false)),
              if (_dashboardEventTitle != null)
                SliverToBoxAdapter(
                  child: DashboardEventFilterBanner(
                    eventTitle: _dashboardEventTitle!,
                    isStatusFilter: false,
                    onClear: _clearEventFilter,
                  ),
                ),
            ],
          ],

          // Main dashboard content
          if (_dashboardLoading && _dashboardData == null)
            const SliverToBoxAdapter(child: DashboardShimmer())
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
            SliverToBoxAdapter(
              child: DashboardKpiSection(
                dashboardData: _dashboardData!,
                dashboardPeriod: _dashboardPeriod,
                onPeriodChanged: (period) {
                  setState(() {
                    _dashboardPeriod = period;
                    _chartDays = periodToDays[period] ?? 30;
                  });
                  _loadDashboard(
                    statusFilter: _dashboardStatusFilter,
                    eventId: _dashboardEventId,
                    genre: _dashboardGenreFilter,
                  );
                },
                onNavigate: _pushWithParams,
              ),
            ),
            SliverToBoxAdapter(
              child: DashboardChartSection(
                timeSeriesData: _timeSeriesData,
                timeSeriesLoading: _timeSeriesLoading,
                chartDays: _chartDays,
                onChartDaysChanged: (days) {
                  setState(() => _chartDays = days);
                  _loadTimeSeries(
                    statusFilter: _dashboardStatusFilter,
                    eventId: _dashboardEventId,
                    genre: _dashboardGenreFilter,
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: DashboardEventCarousels(
                dashboardData: _dashboardData!,
                bookmarkedIds: widget.bookmarkedIds,
                onToggleBookmark: widget.onToggleBookmark,
              ),
            ),
            SliverToBoxAdapter(
              child: DashboardActivityFeed(
                feed: (_dashboardData!['recent_activity'] as List?) ?? [],
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildFilteredSection({required bool isStatusFilter}) {
    final events =
        isStatusFilter ? _statusFilteredEvents : _kpiFilteredEvents;
    final genres = events
        .map((e) => e.genre)
        .where((g) => g != null && g.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final displayEvents = _dashboardGenreFilter != null
        ? events.where((e) => e.genre == _dashboardGenreFilter).toList()
        : events;

    final String title;
    final IconData icon;
    if (isStatusFilter) {
      final statusEnum = EventStatus.values.firstWhere(
        (s) => s.name == _dashboardStatusFilter,
        orElse: () => EventStatus.draft,
      );
      title = '${statusDisplayName(statusEnum)} Events';
      icon = statusChipIcon(statusEnum);
    } else {
      title = kpiSectionTitle(_dashboardKpiFilter!);
      icon = kpiIcon(_dashboardKpiFilter!);
    }

    return DashboardFeaturedSection(
      title: title,
      icon: icon,
      events: displayEvents,
      sectionIndex: 0,
      selectedEventId: _dashboardEventId,
      genreFilter: _dashboardGenreFilter,
      bookmarkedIds: widget.bookmarkedIds,
      onToggleBookmark: widget.onToggleBookmark,
      onGenreSelected: _onGenreSelected,
      onSeeAll: () => widget.onNavigateToExplore?.call(
          isStatusFilter ? _dashboardStatusFilter : null,
          _dashboardGenreFilter),
      onClearFilter: () {
        setState(() {
          if (isStatusFilter) {
            _dashboardStatusFilter = null;
          } else {
            _dashboardKpiFilter = null;
            _kpiFilteredEvents = [];
          }
          _dashboardEventId = null;
          _dashboardEventTitle = null;
          _dashboardGenreFilter = null;
        });
        _loadDashboard();
      },
      genreChips: genres.length > 1 ? genres : null,
      onEventTap: (e) => _onFilteredEventTap(e, isStatusFilter: isStatusFilter),
    );
  }
}
