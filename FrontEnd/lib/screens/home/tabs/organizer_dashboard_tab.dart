import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../home_shared.dart';
import '../../../utils/date_time_utils.dart';
import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../models/event.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/animated_list_item.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/error_state.dart';
import '../../../widgets/event_card.dart';
import '../../../widgets/press_feedback.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/shimmer_loaders.dart';

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
  int? _activityFilterEventId;
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
        widget.onEventsLoaded?.call(_statusFilteredEvents.map((e) => e.id).toList());
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
    return AppDateFormat.dateOnly(dt);
  }

  static const _periodOptions = {'7d': '7d', '30d': '30d', '90d': '90d', '1y': '1y'};
  static const _periodToDays = {'7d': 7, '30d': 30, '90d': 90, '1y': 365};

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
            SliverToBoxAdapter(child: _buildStatusChips()),
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
                child: _buildStatusFilteredSection(),
              ),
              if (_dashboardEventTitle != null)
                SliverToBoxAdapter(child: _buildEventFilterBanner()),
            ],
          ] else if (_dashboardKpiFilter != null) ...[
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
              SliverToBoxAdapter(
                child: _buildKpiFilteredSection(),
              ),
              if (_dashboardEventTitle != null)
                SliverToBoxAdapter(child: _buildEventFilterBanner()),
            ],
          ],
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
            ..._buildCarouselSections(),
            SliverToBoxAdapter(child: _buildActivityFeed()),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

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
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: AppRadius.lg,
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
            duration: 1200.ms,
            color: isDark ? Colors.white12 : Colors.white60);
  }

  Widget _buildStatusChips() {
    final breakdown = ((_statusBreakdownAll ?? _dashboardData?['status_breakdown'] as List?) ?? [])
        .where((item) =>
            (item as Map<String, dynamic>)['status'] != 'draft')
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
            Text(
              'Event Status',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryOf(context),
                letterSpacing: 0.5,
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
                        (s) => s.name == status,
                        orElse: () => EventStatus.draft,
                      );
                      final color = statusChipColor(context, statusEnum);
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? color
                                : color.withValues(
                                    alpha: isDark ? 0.2 : 0.1),
                            borderRadius: AppRadius.pill,
                            border: Border.all(
                                color: isActive
                                    ? color
                                    : color.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                statusDisplayName(statusEnum),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isActive ? Colors.white : color),
                              ),
                              AppSpacing.hXs,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : color.withValues(alpha: 0.2),
                                  borderRadius: AppRadius.pill,
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isActive ? Colors.white : color),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: (80 * i).ms, duration: 300.ms)
                          .slideX(
                              begin: 0.1,
                              duration: 300.ms,
                              curve: Curves.easeOut);
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

  Widget _buildStatusFilteredSection() {
    final genres = _statusFilteredEvents
        .map((e) => e.genre)
        .where((g) => g != null && g.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final displayEvents = _dashboardGenreFilter != null
        ? _statusFilteredEvents
            .where((e) => e.genre == _dashboardGenreFilter)
            .toList()
        : _statusFilteredEvents;
    return _buildFeaturedSection(
      '${statusDisplayName(EventStatus.values.firstWhere(
        (s) => s.name == _dashboardStatusFilter,
        orElse: () => EventStatus.draft,
      ))} Events',
      statusChipIcon(EventStatus.values.firstWhere(
        (s) => s.name == _dashboardStatusFilter,
        orElse: () => EventStatus.draft,
      )),
      displayEvents,
      0,
      onSeeAll: () {
        widget.onNavigateToExplore?.call(
            _dashboardStatusFilter, _dashboardGenreFilter);
      },
      onClearFilter: () {
        setState(() {
          _dashboardStatusFilter = null;
          _dashboardEventId = null;
          _dashboardEventTitle = null;
          _dashboardGenreFilter = null;
        });
        _loadDashboard();
      },
      genreChips: genres.length > 1 ? genres : null,
      onEventTap: (event) {
        if (_dashboardEventId == event.id) {
          setState(() {
            _dashboardEventId = null;
            _dashboardEventTitle = null;
          });
          _loadDashboard(
              statusFilter: _dashboardStatusFilter,
              genre: _dashboardGenreFilter);
        } else {
          setState(() {
            _dashboardEventId = event.id;
            _dashboardEventTitle = event.title;
          });
          _loadDashboard(
              eventId: event.id, genre: _dashboardGenreFilter);
        }
      },
    );
  }

  Widget _buildKpiFilteredSection() {
    final genres = _kpiFilteredEvents
        .map((e) => e.genre)
        .where((g) => g != null && g.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final displayEvents = _dashboardGenreFilter != null
        ? _kpiFilteredEvents
            .where((e) => e.genre == _dashboardGenreFilter)
            .toList()
        : _kpiFilteredEvents;
    return _buildFeaturedSection(
      _kpiSectionTitle(_dashboardKpiFilter!),
      _kpiIcon(_dashboardKpiFilter!),
      displayEvents,
      0,
      onSeeAll: () {
        widget.onNavigateToExplore?.call(null, _dashboardGenreFilter);
      },
      onClearFilter: () {
        setState(() {
          _dashboardKpiFilter = null;
          _kpiFilteredEvents = [];
          _dashboardEventId = null;
          _dashboardEventTitle = null;
          _dashboardGenreFilter = null;
        });
        _loadDashboard();
      },
      genreChips: genres.length > 1 ? genres : null,
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
    );
  }

  Widget _buildEventFilterBanner() {
    final isStatusFilter = _dashboardStatusFilter != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 0),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt_rounded,
            size: 16,
            color: isStatusFilter ? AppTheme.primaryColor : AppTheme.accentColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Showing metrics for: $_dashboardEventTitle',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isStatusFilter
                    ? AppTheme.primaryColor
                    : AppTheme.accentColor,
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
              if (isStatusFilter) {
                _loadDashboard(
                    statusFilter: _dashboardStatusFilter,
                    genre: _dashboardGenreFilter);
              } else {
                _loadDashboard(genre: _dashboardGenreFilter);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close,
                  size: 16, color: AppTheme.textSecondaryOf(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedSection(
    String title,
    IconData icon,
    List<Event> items,
    int sectionIndex, {
    VoidCallback? onClearFilter,
    VoidCallback? onSeeAll,
    List<String?>? genreChips,
    void Function(Event event)? onEventTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl, bottom: AppSpacing.md),
      child: AnimatedListItem(
        index: sectionIndex,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
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
                  if (onSeeAll != null)
                    GestureDetector(
                      onTap: onSeeAll,
                      child: Text(
                        'See all',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  if (onSeeAll != null && onClearFilter != null)
                    const SizedBox(width: 12),
                  if (onClearFilter != null)
                    GestureDetector(
                      onTap: onClearFilter,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceOf(context),
                          borderRadius: AppRadius.pill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close,
                                size: 14,
                                color: AppTheme.textSecondaryOf(context)),
                            const SizedBox(width: 4),
                            Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (genreChips != null && genreChips.length > 1) ...[
              Padding(
                padding: const EdgeInsets.only(
                    left: AppSpacing.lg, bottom: AppSpacing.sm),
                child: SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _genreChip('All', null),
                      for (final g in genreChips) if (g != null) _genreChip(g, g),
                    ],
                  ),
                ),
              ),
            ],
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
                    decoration: isSelected
                        ? BoxDecoration(
                            borderRadius: AppRadius.lg,
                            border: Border.all(
                              color:
                                  Theme.of(context).brightness == Brightness.dark
                                  ? AppTheme.accentColor
                                  : AppTheme.primaryColor,
                              width: 2.5,
                            ),
                          )
                        : null,
                    child: Stack(
                      children: [
                        EventCard(
                          event: event,
                          imageUrl: event.firstImageUrl,
                          onTap: onEventTap != null
                              ? () => onEventTap(event)
                              : () => context.push('/events/${event.id}'),
                          isBookmarked: widget.bookmarkedIds.contains(event.id),
                          onBookmarkToggle: () =>
                              widget.onToggleBookmark(event.id),
                        ),
                        if (onEventTap != null)
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: GestureDetector(
                              onTap: () =>
                                  context.push('/events/${event.id}'),
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
            color: isActive
                ? color
                : color.withValues(alpha: isDark ? 0.15 : 0.1),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(
                  'Period',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondaryOf(context)),
                ),
                const SizedBox(width: 10),
                ..._periodOptions.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: _dashboardPeriod == e.key,
                        onSelected: (_) {
                          if (_dashboardPeriod != e.key) {
                            setState(() {
                              _dashboardPeriod = e.key;
                              _chartDays = _periodToDays[e.key] ?? 30;
                            });
                            _loadDashboard(
                              statusFilter: _dashboardStatusFilter,
                              eventId: _dashboardEventId,
                              genre: _dashboardGenreFilter,
                            );
                          }
                        },
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _dashboardPeriod == e.key
                              ? Colors.white
                              : AppTheme.textSecondaryOf(context),
                        ),
                        selectedColor: AppTheme.accentColor,
                        backgroundColor: AppTheme.surfaceOf(context),
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    )),
              ],
            ),
          ),
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
                    onTap: () => _pushWithParams('/manage/ticket-sales'),
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
                    deltaPercent:
                        (backers['delta_percent'] as num?)?.toDouble(),
                    accentColor: context.fundingAccent,
                    onTap: () => _pushWithParams('/manage/pledges'),
                  ),
                ),
                AppSpacing.hMd,
                Expanded(
                  child: _DashboardKpiCard(
                    icon: Icons.handshake_rounded,
                    label: 'Total Sponsors',
                    value: '${sponsors?['value'] ?? 0}',
                    deltaPercent:
                        (sponsors?['delta_percent'] as num?)?.toDouble(),
                    accentColor: context.sponsorAccent,
                    onTap: () => _pushWithParams('/manage/sponsors'),
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
                      if (_dashboardEventId != null) {
                        context.push('/events/$_dashboardEventId');
                      } else {
                        widget.onNavigateToExplore?.call(
                            _dashboardStatusFilter, _dashboardGenreFilter);
                      }
                    },
                  ),
                ),
                AppSpacing.hMd,
                Expanded(
                  child: _DashboardKpiCard(
                    icon: Icons.undo_rounded,
                    label: 'Refund Rate',
                    value:
                        '${(refundRate?['value'] as num?)?.toStringAsFixed(1) ?? '0.0'}%',
                    deltaPercent:
                        (refundRate?['delta_percent'] as num?)?.toDouble(),
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

  void _pushWithParams(String basePath) {
    final params = <String, String>{};
    if (_dashboardStatusFilter != null) {
      params['event_status'] = _dashboardStatusFilter!;
    }
    if (_dashboardGenreFilter != null) params['genre'] = _dashboardGenreFilter!;
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

  Widget _buildChartSection() {
    final isDark = AppTheme.isDark(context);
    final isLoading = _timeSeriesLoading && _timeSeriesData == null;
    final hasData = _timeSeriesData != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0),
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
                      Icon(Icons.attach_money_rounded,
                          size: AppIconSize.md,
                          color: AppTheme.accentColor),
                      AppSpacing.hSm,
                      Text(
                        'Revenue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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
                                child: Text(
                                  'No data yet',
                                  style: TextStyle(
                                      color:
                                          AppTheme.textSecondaryOf(context)),
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
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
                      Icon(Icons.insights_rounded,
                          size: AppIconSize.md,
                          color: AppTheme.successColor),
                      AppSpacing.hSm,
                      Text(
                        'Activity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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
                                child: Text(
                                  'No data yet',
                                  style: TextStyle(
                                      color:
                                          AppTheme.textSecondaryOf(context)),
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 11, color: AppTheme.textSecondaryOf(context)),
        ),
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
          for (final entry
              in {7: '7d', 30: '30d', 90: '90d', 365: '1y'}.entries)
            GestureDetector(
              onTap: () {
                if (_chartDays != entry.key) {
                  setState(() => _chartDays = entry.key);
                  _loadTimeSeries(
                    statusFilter: _dashboardStatusFilter,
                    eventId: _dashboardEventId,
                    genre: _dashboardGenreFilter,
                  );
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _chartDays == entry.key
                      ? AppTheme.accentColor
                      : Colors.transparent,
                  borderRadius: AppRadius.pill,
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _chartDays == entry.key
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
        child: Text(
          'No data for this period',
          style: TextStyle(color: AppTheme.textSecondaryOf(context)),
        ),
      );
    }

    final isDark = AppTheme.isDark(context);
    final revenueColor = AppTheme.accentColor;

    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      final p = points[i] as Map;
      spots.add(FlSpot(
          i.toDouble(),
          ((p['revenue_cents'] as num?)?.toDouble() ?? 0) / 100));
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
                TextStyle(
                    color: revenueColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
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
        child: Text(
          'No data for this period',
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
      ticketSpots.add(FlSpot(
          i.toDouble(), (p['tickets_sold'] as num?)?.toDouble() ?? 0));
      pledgeSpots.add(FlSpot(
          i.toDouble(), (p['pledges_count'] as num?)?.toDouble() ?? 0));
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
                isTicket
                    ? '${s.y.toInt()} tickets'
                    : '${s.y.toInt()} pledges',
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
              AppDateFormat.dateOnly(dt),
              style: TextStyle(
                  fontSize: 10, color: AppTheme.textSecondaryOf(context)),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildCarouselSections() {
    final trending = (_dashboardData!['trending_events'] as List?) ?? [];
    final top = (_dashboardData!['top_events'] as List?) ?? [];

    if (trending.isEmpty && top.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0),
            child: AnimatedListItem(
              index: 4,
              child: EmptyState(
                icon: Icons.rocket_launch_rounded,
                title: 'Create your first event',
                subtitle:
                    'Your trending and top-earning events will appear here.',
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
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
                        isBookmarked: widget.bookmarkedIds.contains(e.id),
                        onBookmarkToggle: () =>
                            widget.onToggleBookmark(e.id),
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
        : feed
            .where((item) =>
                (item as Map)['event_id'] == _activityFilterEventId)
            .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0),
      child: AnimatedListItem(
        index: 6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_rounded,
                    size: AppIconSize.sm,
                    color: context.fundingAccent),
                AppSpacing.hSm,
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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
                        label: entry.value.length > 20
                            ? '${entry.value.substring(0, 20)}...'
                            : entry.value,
                        eventId: entry.key,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            AppSpacing.vMd,
            for (int i = 0; i < filtered.length; i++)
              _buildActivityItem(
                  filtered[i] as Map<String, dynamic>, i, isDark),
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
          color: selected
              ? AppTheme.accentColor
              : AppTheme.surfaceOf(context),
          borderRadius: AppRadius.pill,
          border: selected
              ? null
              : Border.all(color: AppTheme.dividerOf(context)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : AppTheme.textSecondaryOf(context),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem(
      Map<String, dynamic> item, int index, bool isDark) {
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
        final bidStatus =
            (item['extra'] as Map?)?['bid_status'] as String? ?? '';
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
              width: 36,
              height: 36,
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
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.textPrimaryOf(context)),
                      ),
                      TextSpan(
                        text: ' $action',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondaryOf(context)),
                      ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    eventTitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryOf(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.successColor),
                ),
                Text(
                  _relativeTime(createdAt),
                  style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondaryOf(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (60 * index).ms, duration: 300.ms)
        .slideY(begin: 0.05, duration: 300.ms, curve: Curves.easeOut);
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
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
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
              color: widget.isActive
                  ? accent
                  : AppTheme.dividerOf(context),
              width: widget.isActive ? 2 : 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: AppRadius.sm,
                    ),
                    child: Icon(widget.icon, size: 18, color: accent),
                  ),
                  if (delta != null) ...[
                    const Spacer(),
                    ScaleTransition(
                      scale: CurvedAnimation(
                          parent: _ctrl, curve: Curves.elasticOut),
                      child: Builder(builder: (_) {
                        final isPositive = widget.invertDelta
                            ? delta < 0
                            : delta >= 0;
                        final deltaColor = isPositive
                            ? AppTheme.successColor
                            : AppTheme.errorColor;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: deltaColor
                                .withValues(alpha: isDark ? 0.2 : 0.1),
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
