import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../services/api_service.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/event_lifecycle_bar.dart';
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
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _ratingsSummary;
  List<Event> _events = [];
  bool _loadingProfile = true;
  bool _loadingEvents = true;
  bool _loadingMoreEvents = false;
  bool _hasMoreEvents = true;

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
      final data = await api.getPublicEvents(widget.userId, offset: 0, limit: _pageSize);
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
      final data = await api.getPublicEvents(widget.userId, offset: _events.length, limit: _pageSize);
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
                    _buildTrustSection(trust),
                    const SizedBox(height: 24),
                  ],
                  if (_ratingsSummary != null && (_ratingsSummary!['count'] as int? ?? 0) > 0) ...[
                    _buildRatingsSection(),
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

  Widget _buildTrustSection(Map<String, dynamic> trust) {
    final score = ((trust['trust_score'] ?? 0.0) as num).toDouble();
    final label = trust['label'] ?? 'New';
    final completed = trust['completed_events'] ?? 0;
    final published = trust['published_events'] ?? 0;
    final pct = (score * 100).toInt();

    Color trustColor;
    IconData trustIcon;
    switch (label) {
      case 'Excellent':
        trustColor = const Color(0xFF05944F);
        trustIcon = Icons.verified_rounded;
      case 'Good':
        trustColor = const Color(0xFF0077B6);
        trustIcon = Icons.verified_outlined;
      case 'Fair':
        trustColor = const Color(0xFFFFC043);
        trustIcon = Icons.shield_outlined;
      default:
        trustColor = const Color(0xFFE11900);
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

  Widget _buildRatingsSection() {
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
              Icon(Icons.reviews_rounded, size: 16, color: Colors.amber),
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

  Widget _buildEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.event_rounded, size: 16, color: AppTheme.textSecondaryOf(context)),
            const SizedBox(width: 8),
            Text('Public Events', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondaryOf(context), letterSpacing: 0.3)),
          ],
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
                  Text('No public events yet', style: TextStyle(color: AppTheme.textSecondaryOf(context))),
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
                  color: _statusColor(event.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(Icons.event_rounded, size: 22, color: _statusColor(event.status)),
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
                  color: _statusColor(event.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel(event.status),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor(event.status)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(EventStatus s) {
    return switch (s) {
      EventStatus.live => const Color(0xFF05944F),
      EventStatus.selling_tickets => const Color(0xFF00838F),
      EventStatus.completed => const Color(0xFF7356BF),
      EventStatus.cancelled => const Color(0xFF8B0000),
      EventStatus.approved => const Color(0xFF276EF1),
      _ => const Color(0xFF757575),
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
