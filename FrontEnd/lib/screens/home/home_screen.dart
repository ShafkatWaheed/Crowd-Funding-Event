import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/event_card.dart';

String _statusDisplayName(EventStatus s) {
  switch (s) {
    case EventStatus.draft:
      return 'Draft';
    case EventStatus.pending_approval:
      return 'Unpublished';
    case EventStatus.approved:
      return 'Published';
    case EventStatus.live:
      return 'Live';
    case EventStatus.ended:
      return 'Ended';
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

  // My registered events (includes cancelled)
  List<Event> _myEvents = [];
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

    // Organizers/admins see all statuses (including draft/cancelled)
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
    final events = context.watch<EventProvider>();
    final user = auth.user;
    final dateFmt = DateFormat('MMM d');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          user != null ? 'Hi, ${user.displayLabel}' : 'CrowdFund Events',
        ),
        actions: [
          if (user != null && user.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Admin',
              onPressed: () => context.go('/admin'),
            ),
          if (user != null && user.isOrganizer)
            IconButton(
              icon: const Icon(Icons.location_city),
              tooltip: 'Venues',
              onPressed: () => context.go('/venues'),
            ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _applyFilters();
          await Future.wait([
            _loadFeatured(),
            _loadMyEvents(),
          ]);
        },
        child: CustomScrollView(
          slivers: [
            // ── Search & Filters ──
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search events...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        ),
                      ),
                      onSubmitted: (_) => _applyFilters(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('All')),
                              ...EventStatus.values
                                  .where((s) =>
                                      (user != null &&
                                          (user.isOrganizer ||
                                              user.isAdmin)) ||
                                      (s != EventStatus.draft &&
                                          s != EventStatus.pending_approval &&
                                          s != EventStatus.cancelled))
                                  .map((s) => DropdownMenuItem(
                                      value: s.name,
                                      child:
                                          Text(_statusDisplayName(s)))),
                            ],
                            onChanged: (v) {
                              setState(() => _selectedStatus = v);
                              _applyFilters();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            _showAdvanced
                                ? Icons.expand_less
                                : Icons.tune,
                            color: AppTheme.primaryColor,
                          ),
                          tooltip: 'Advanced filters',
                          onPressed: () => setState(
                              () => _showAdvanced = !_showAdvanced),
                        ),
                        ElevatedButton.icon(
                          onPressed: _applyFilters,
                          icon: const Icon(Icons.filter_list, size: 18),
                          label: const Text('Filter'),
                        ),
                      ],
                    ),
                    // ── Advanced Filters ──
                    if (_showAdvanced) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedRegType,
                              decoration: const InputDecoration(
                                labelText: 'Registration',
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: null, child: Text('Any')),
                                DropdownMenuItem(
                                    value: 'open', child: Text('Open')),
                                DropdownMenuItem(
                                    value: 'closed',
                                    child: Text('Closed')),
                              ],
                              onChanged: (v) {
                                setState(() => _selectedRegType = v);
                                _applyFilters();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<bool?>(
                              value: _hasFunding,
                              decoration: const InputDecoration(
                                labelText: 'Funding',
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: null, child: Text('Any')),
                                DropdownMenuItem(
                                    value: true,
                                    child: Text('Has Funding')),
                                DropdownMenuItem(
                                    value: false,
                                    child: Text('No Funding')),
                              ],
                              onChanged: (v) {
                                setState(() => _hasFunding = v);
                                _applyFilters();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedGenre,
                        decoration: const InputDecoration(
                          labelText: 'Genre / Category',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('All Genres')),
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickDate(true),
                              icon: const Icon(Icons.calendar_today,
                                  size: 16),
                              label: Text(_dateFrom != null
                                  ? 'From: ${dateFmt.format(_dateFrom!)}'
                                  : 'Start date'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickDate(false),
                              icon: const Icon(Icons.calendar_today,
                                  size: 16),
                              label: Text(_dateTo != null
                                  ? 'To: ${dateFmt.format(_dateTo!)}'
                                  : 'End date'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.clear_all, size: 18),
                          label: const Text('Clear all'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── My Events (registered, includes cancelled) ──
            if (_myEvents.isNotEmpty)
              _buildFeaturedSection(
                  'My Events', Icons.bookmark_outline, _myEvents),

            // ── Featured Sections ──
            if (!_featuredLoading) ...[
              if (_trending.isNotEmpty)
                _buildFeaturedSection(
                    'Trending', Icons.trending_up, _trending),
              if (_comingSoon.isNotEmpty)
                _buildFeaturedSection(
                    'Coming Soon', Icons.upcoming, _comingSoon),
              if (_popular.isNotEmpty)
                _buildFeaturedSection(
                    'Popular', Icons.star_outline, _popular),
            ],

            // ── Section header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Text(
                  'All Events',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // ── Event list ──
            if (events.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (events.error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(events.error!),
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
                      Icon(Icons.event_busy,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No events found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final event = events.events[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: EventCard(
                        event: event,
                        onTap: () =>
                            context.go('/events/${event.id}'),
                      ),
                    );
                  },
                  childCount: events.events.length,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton:
          user != null && (user.isOrganizer || user.isAdmin)
              ? FloatingActionButton.extended(
                  onPressed: () => context.go('/events/create'),
                  icon: const Icon(Icons.add),
                  label: const Text('New Event'),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                )
              : null,
    );
  }

  SliverToBoxAdapter _buildFeaturedSection(
      String title, IconData icon, List<Event> items) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final event = items[index];
                return _FeaturedCard(
                  event: event,
                  onTap: () => context.go('/events/${event.id}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const _FeaturedCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        DateFormat('MMM d, y').format(event.startTime),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (event.venue != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${event.venue!.name}, ${event.venue!.city}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (event.genre != null &&
                    event.genre!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.category,
                          size: 14, color: AppTheme.secondaryColor),
                      const SizedBox(width: 4),
                      Text(
                        event.genre![0].toUpperCase() +
                            event.genre!.substring(1),
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.secondaryColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (event.registrationCount > 0)
                      Row(
                        children: [
                          Icon(Icons.group,
                              size: 14, color: AppTheme.primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            '${event.registrationCount}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    if (event.fundingGoalCents != null &&
                        event.fundingGoalCents! > 0)
                      Text(
                        event.totalPledgedFormatted,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successColor,
                        ),
                      ),
                  ],
                ),
                if (event.fundingGoalCents != null &&
                    event.fundingGoalCents! > 0) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: event.fundingProgress.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(
                        event.fundingProgress >= 1.0
                            ? AppTheme.successColor
                            : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
