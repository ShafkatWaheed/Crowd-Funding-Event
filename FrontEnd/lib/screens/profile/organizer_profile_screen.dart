import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../services/api_service.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/star_rating.dart';

class OrganizerProfileScreen extends StatefulWidget {
  final int userId;
  const OrganizerProfileScreen({super.key, required this.userId});

  @override
  State<OrganizerProfileScreen> createState() => _OrganizerProfileScreenState();
}

class _OrganizerProfileScreenState extends State<OrganizerProfileScreen> {
  static const _pageSize = 20;

  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _ratingsSummary;
  List<Event> _events = [];
  bool _loadingProfile = true;
  bool _loadingEvents = true;
  bool _loadingMoreEvents = false;
  bool _hasMoreEvents = true;
  String? _statusFilter;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
      _loadEvents();
      _loadRatings();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent * 0.8 &&
        !_loadingMoreEvents &&
        _hasMoreEvents &&
        !_loadingEvents) {
      _loadMoreEvents();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getPublicProfile(widget.userId);
      if (mounted) setState(() { _profile = data; _loadingProfile = false; });
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ApiService.extractError(e));
        setState(() => _loadingProfile = false);
      }
    }
  }

  Future<void> _loadEvents() async {
    setState(() { _loadingEvents = true; _hasMoreEvents = true; });
    try {
      final api = context.read<ApiService>();
      final data = await api.getPublicEvents(
        widget.userId,
        offset: 0,
        limit: _pageSize,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        status: _statusFilter,
      );
      if (mounted) {
        setState(() {
          _events = data.map((j) => Event.fromJson(j)).toList();
          _hasMoreEvents = data.length >= _pageSize;
          _loadingEvents = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  Future<void> _loadMoreEvents() async {
    if (_loadingMoreEvents || !_hasMoreEvents) return;
    setState(() => _loadingMoreEvents = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getPublicEvents(
        widget.userId,
        offset: _events.length,
        limit: _pageSize,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        status: _statusFilter,
      );
      if (mounted) {
        setState(() {
          _events.addAll(data.map((j) => Event.fromJson(j)));
          _hasMoreEvents = data.length >= _pageSize;
          _loadingMoreEvents = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMoreEvents = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (_searchQuery != value) {
        _searchQuery = value;
        _loadEvents();
      }
    });
  }

  void _onStatusFilterChanged(String? status) {
    if (_statusFilter == status) return;
    setState(() => _statusFilter = status);
    _loadEvents();
  }

  Future<void> _loadRatings() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getUserRatingsSummary(widget.userId);
      if (mounted) setState(() => _ratingsSummary = data);
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadProfile(), _loadEvents(), _loadRatings()]);
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?['display_name'] ?? 'User';
    final role = _profile?['role'] ?? '';
    final address = _profile?['address'];
    final yoe = _profile?['years_of_experience'];
    final trust = _profile?['trust'];
    final createdAt = _profile?['created_at'];
    final sponsorProfile = _profile?['sponsor_profile'];

    return Scaffold(
      appBar: AppBar(title: Text(_loadingProfile ? 'Profile' : name)),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: _loadingProfile
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: List.generate(4, (_) => const ShimmerListTile())),
              )
            : ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                children: [
                  _buildProfileHeader(name, role, address, yoe, trust, createdAt, sponsorProfile),
                  const SizedBox(height: 24),
                  if (trust != null) ...[
                    _buildTrustSection(context, trust),
                    const SizedBox(height: 24),
                  ],
                  if (_profile?['event_metrics'] != null) ...[
                    _buildEventMetrics(context, _profile!['event_metrics'] as Map<String, dynamic>),
                    const SizedBox(height: 24),
                  ],
                  if (_ratingsSummary != null && (_ratingsSummary!['count'] as int? ?? 0) > 0) ...[
                    _buildRatingsSection(context),
                    const SizedBox(height: 24),
                  ],
                  _buildEventsSection(),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileHeader(
    String name, String role, String? address, int? yoe,
    Map<String, dynamic>? trust, String? createdAt,
    Map<String, dynamic>? sponsorProfile,
  ) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    DateTime? memberSince;
    if (createdAt != null) {
      try { memberSince = DateTime.parse(createdAt); } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppTheme.accentColor.withValues(alpha: 0.15),
            child: Text(initials, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.accentColor)),
          ),
          const SizedBox(height: 12),
          Text(name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimaryOf(context))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              role[0].toUpperCase() + role.substring(1),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accentColor),
            ),
          ),
          if (sponsorProfile != null) ...[
            const SizedBox(height: 6),
            Text(
              sponsorProfile['company_name'] ?? '',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryOf(context)),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (address != null && address.toString().isNotEmpty)
                _infoPill(Icons.location_on_rounded, address.toString()),
              if (yoe != null) ...[
                const SizedBox(width: 12),
                _infoPill(Icons.work_rounded, '$yoe yr${yoe == 1 ? '' : 's'} exp'),
              ],
            ],
          ),
          if (memberSince != null) ...[
            const SizedBox(height: 8),
            Text(
              'Member since ${DateFormat.yMMMM().format(memberSince)}',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondaryOf(context)),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryOf(context))),
        ],
      ),
    );
  }

  Widget _buildTrustSection(BuildContext context, Map<String, dynamic> trust) {
    final score = ((trust['trust_score'] ?? 0.0) as num).toDouble();
    final label = trust['label'] ?? 'New';
    final completed = trust['completed_events'] ?? 0;
    final published = trust['published_events'] ?? 0;
    final pct = (score * 100).toInt();

    Color trustColor;
    IconData trustIcon;
    switch (label) {
      case 'Excellent':
        trustColor = context.trustHigh;
        trustIcon = Icons.verified_rounded;
      case 'Good':
        trustColor = AppTheme.accentColor;
        trustIcon = Icons.verified_outlined;
      case 'Fair':
        trustColor = context.trustMedium;
        trustIcon = Icons.shield_outlined;
      default:
        trustColor = context.trustLow;
        trustIcon = Icons.shield_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_rounded, size: 16, color: AppTheme.textSecondaryOf(context)),
              const SizedBox(width: 8),
              Text('Trust Score', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondaryOf(context), letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(trustIcon, size: 28, color: trustColor),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$label ($pct%)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: trustColor)),
                  const SizedBox(height: 2),
                  Text('$completed completed of $published published events',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppTheme.dividerOf(context),
              valueColor: AlwaysStoppedAnimation(trustColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventMetrics(BuildContext context, Map<String, dynamic> metrics) {
    final items = <_MetricItem>[
      _MetricItem('Completed', metrics['completed'] ?? 0, context.managementAccent, Icons.check_circle_rounded),
      _MetricItem('Cancelled', metrics['cancelled'] ?? 0, context.statusCancelled, Icons.cancel_rounded),
      _MetricItem('Live', metrics['live'] ?? 0, AppTheme.successColor, Icons.play_circle_rounded),
      _MetricItem('Funding', metrics['approved'] ?? 0, AppTheme.accentColor, Icons.monetization_on_rounded),
      _MetricItem('Selling', metrics['selling_tickets'] ?? 0, context.statusSelling, Icons.confirmation_num_rounded),
      _MetricItem('Total', metrics['total'] ?? 0, AppTheme.textSecondaryOf(context), Icons.bar_chart_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 16, color: AppTheme.textSecondaryOf(context)),
              const SizedBox(width: 8),
              Text('Event Metrics',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondaryOf(context), letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items.map((m) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: m.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(m.icon, size: 16, color: m.color),
                  const SizedBox(width: 6),
                  Text('${m.count}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: m.color)),
                  const SizedBox(width: 4),
                  Text(m.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: m.color)),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingsSection(BuildContext context) {
    final s = _ratingsSummary!;
    final avgStars = s['avg_stars'] as double?;
    final count = s['count'] as int? ?? 0;
    final topReviews = (s['top_reviews'] as List?) ?? [];
    final worstReviews = (s['worst_reviews'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.reviews_rounded, size: 16, color: context.reviewAccent),
              const SizedBox(width: 8),
              Text('Reviews',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondaryOf(context), letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 12),
          StarRatingDisplay(avgStars: avgStars, count: count, size: 20),
          if (topReviews.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Top Reviews',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryOf(context))),
            const SizedBox(height: 6),
            ...topReviews.take(5).map((r) => _reviewTile(r)),
          ],
          if (worstReviews.isNotEmpty && (worstReviews.first['stars'] as int? ?? 5) < 4) ...[
            const SizedBox(height: 14),
            Text('Critical Reviews',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryOf(context))),
            const SizedBox(height: 6),
            ...worstReviews.take(5).map((r) => _reviewTile(r)),
          ],
        ],
      ),
    );
  }

  Widget _reviewTile(dynamic r) {
    final stars = r['stars'] as int? ?? 0;
    final name = r['rater_name'] ?? 'Anonymous';
    final desc = r['description'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StarRating(rating: stars, size: 12),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desc.isNotEmpty)
                  Text(desc, style: TextStyle(fontSize: 12, color: AppTheme.textPrimaryOf(context)), maxLines: 2, overflow: TextOverflow.ellipsis),
                Text('— $name', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _statusFilters = <(String, String?)>[
    ('All', null),
    ('Funding', 'approved'),
    ('Selling', 'selling_tickets'),
    ('Live', 'live'),
    ('Completed', 'completed'),
    ('Cancelled', 'cancelled'),
  ];

  Widget _buildEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.event_rounded, size: 16, color: AppTheme.textSecondaryOf(context)),
            const SizedBox(width: 8),
            Text('Events', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondaryOf(context), letterSpacing: 0.3)),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search events...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      _searchQuery = '';
                      _loadEvents();
                    },
                  )
                : null,
            filled: true,
            fillColor: AppTheme.inputFillOf(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            isDense: true,
          ),
          style: TextStyle(fontSize: 14, color: AppTheme.textPrimaryOf(context)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _statusFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final f = _statusFilters[i];
              final active = _statusFilter == f.$2;
              return ChoiceChip(
                label: Text(f.$1),
                selected: active,
                onSelected: (_) => _onStatusFilterChanged(active ? null : f.$2),
                selectedColor: AppTheme.accentColor,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? ctx.onDarkSurface : AppTheme.textSecondaryOf(ctx),
                ),
                backgroundColor: AppTheme.surfaceOf(context),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingEvents)
          Column(children: List.generate(3, (_) => const ShimmerListTile()))
        else if (_events.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.event_busy_rounded, size: 40, color: AppTheme.textSecondaryOf(context)),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isNotEmpty || _statusFilter != null ? 'No matching events' : 'No public events yet',
                    style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                  ),
                ],
              ),
            ),
          )
        else ...[
          ...List.generate(_events.length, (i) {
            final event = _events[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i < _events.length - 1 ? 12 : 0),
              child: _ProfileEventCard(
                event: event,
                onTap: () => context.push('/events/${event.id}'),
              ),
            );
          }),
          if (_loadingMoreEvents)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ],
    );
  }
}

class _ProfileEventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const _ProfileEventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.dividerOf(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor(context, event.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(Icons.event_rounded, size: 22, color: _statusColor(context, event.status)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryOf(context))),
                    const SizedBox(height: 3),
                    if (event.startTime != null)
                      Text(DateFormat('MMM d, y').format(event.startTime!),
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(context, event.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel(event.status),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor(context, event.status)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context, EventStatus s) {
    return switch (s) {
      EventStatus.live => AppTheme.successColor,
      EventStatus.selling_tickets => context.statusSelling,
      EventStatus.completed => context.managementAccent,
      EventStatus.cancelled => context.statusCancelled,
      EventStatus.approved => AppTheme.accentColor,
      _ => context.statusDraft,
    };
  }

  String _statusLabel(EventStatus s) {
    return switch (s) {
      EventStatus.approved => 'Funding',
      EventStatus.selling_tickets => 'Tickets',
      EventStatus.live => 'Live',
      EventStatus.completed => 'Completed',
      EventStatus.cancelled => 'Cancelled',
      _ => s.name,
    };
  }
}

class _MetricItem {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _MetricItem(this.label, this.count, this.color, this.icon);
}
