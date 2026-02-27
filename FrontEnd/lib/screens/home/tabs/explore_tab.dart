import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../home_shared.dart';
import '../../../utils/date_time_utils.dart';
import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../models/event.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/event_provider.dart';
import '../../../widgets/animated_list_item.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/error_state.dart';
import '../../../widgets/event_card.dart';
import '../../../widgets/event_map_widget.dart';
import '../../../widgets/shimmer_loaders.dart';

class ExploreTab extends StatefulWidget {
  final Set<int> bookmarkedIds;
  final void Function(int) onToggleBookmark;
  final List<String> cities;
  final List<String> genres;
  final String? initialStatus;
  final String? initialGenre;
  final void Function(void Function() refresh)? onRefreshReady;

  const ExploreTab({
    super.key,
    required this.bookmarkedIds,
    required this.onToggleBookmark,
    required this.cities,
    required this.genres,
    this.initialStatus,
    this.initialGenre,
    this.onRefreshReady,
  });

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  final _searchController = TextEditingController();
  String? _selectedStatus;
  String? _selectedRegType;
  String? _selectedGenre;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool? _hasFunding;
  bool _showAdvanced = false;
  bool _showMapView = false;
  String? _selectedCity;

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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    if (widget.initialStatus != null) _selectedStatus = widget.initialStatus;
    if (widget.initialGenre != null) _selectedGenre = widget.initialGenre;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFilters();
      widget.onRefreshReady?.call(_applyFilters);
    });
  }

  @override
  void didUpdateWidget(ExploreTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStatus != widget.initialStatus ||
        oldWidget.initialGenre != widget.initialGenre) {
      setState(() {
        _selectedStatus = widget.initialStatus;
        _selectedGenre = widget.initialGenre;
      });
      _applyFilters();
    }
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
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
    if (_selectedCity != null) {
      filters['city'] = _selectedCity;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user != null && (user.isOrganizer || user.isAdmin)) {
      filters['include_all_statuses'] = true;
    }
    if (user != null && user.isOrganizer) {
      filters['organizer_id'] = user.id;
    }
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
      _selectedCity = null;
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
          horizontal: 14,
          vertical: AppSpacing.sm,
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
          horizontal: 14,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
          borderRadius: AppRadius.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: AppIconSize.sm,
              color: AppTheme.textSecondaryOf(context),
            ),
            AppSpacing.hSm,
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
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
    final events = context.watch<EventProvider>();
    final user = auth.user;
    final isDark = AppTheme.isDark(context);
    

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent * 0.8 &&
            !events.isLoadingMore &&
            events.hasMore &&
            !events.isLoading) {
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
                AppSpacing.xl,
                56,
                AppSpacing.xl,
                AppSpacing.sm,
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
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                      ),
                      if (user != null && user.isOrganizer)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withValues(alpha: 0.1),
                            borderRadius: AppRadius.pill,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: AppIconSize.sm,
                                color: AppTheme.accentColor,
                              ),
                              AppSpacing.hXs,
                              Text(
                                'Organizer View',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accentColor,
                                ),
                              ),
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
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppTheme.textSecondaryOf(context),
                      ),
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
                        horizontal: AppSpacing.lg,
                        vertical: 14,
                      ),
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
                                padding: const EdgeInsets.only(
                                  right: AppSpacing.sm,
                                ),
                                child: ChoiceChip(
                                  label: Text(statusDisplayName(s)),
                                  selected: isActive,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedStatus = selected ? s.name : null;
                                    });
                                    _applyFilters();
                                  },
                                  selectedColor: statusChipColor(context, s),
                                  backgroundColor: AppTheme.cardOf(context),
                                  side: BorderSide(
                                    color: isActive
                                        ? statusChipColor(context, s)
                                        : AppTheme.dividerOf(context),
                                  ),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? Colors.white
                                        : AppTheme.textPrimaryOf(context),
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
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
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Any')),
                              DropdownMenuItem(
                                value: 'open',
                                child: Text('Open'),
                              ),
                              DropdownMenuItem(
                                value: 'closed',
                                child: Text('Closed'),
                              ),
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
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All'),
                              ),
                              ...widget.genres.map((g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(
                                      g[0].toUpperCase() + g.substring(1),
                                    ),
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
                    if (widget.cities.isNotEmpty) ...[
                      AppSpacing.vSm,
                      DropdownButtonFormField<String>(
                        value: _selectedCity,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'City',
                          filled: true,
                          fillColor: AppTheme.inputFillOf(context),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.sm,
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Cities'),
                          ),
                          ...widget.cities.map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c),
                              )),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedCity = v);
                          _applyFilters();
                        },
                      ),
                    ],
                    AppSpacing.vSm,
                    Row(
                      children: [
                        Expanded(
                          child: _dateChip(
                            label: _dateFrom != null
                                ? 'From: ${AppDateFormat.dateOnly(_dateFrom!)}'
                                : 'Start date',
                            onTap: () => _pickDate(true),
                          ),
                        ),
                        AppSpacing.hSm,
                        Expanded(
                          child: _dateChip(
                            label: _dateTo != null
                                ? 'To: ${AppDateFormat.dateOnly(_dateTo!)}'
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
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                6,
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                  organizerId:
                      user != null && user.isOrganizer ? user.id : null,
                  search: _searchController.text.isNotEmpty
                      ? _searchController.text
                      : null,
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
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
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
                        isBookmarked: widget.bookmarkedIds.contains(event.id),
                        onBookmarkToggle: () =>
                            widget.onToggleBookmark(event.id),
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
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
