import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/star_rating.dart';

class SponsorProfileScreen extends StatefulWidget {
  final int userId;
  final bool isOrganizerView;
  const SponsorProfileScreen({
    super.key,
    required this.userId,
    this.isOrganizerView = false,
  });

  @override
  State<SponsorProfileScreen> createState() => _SponsorProfileScreenState();
}

class _SponsorProfileScreenState extends State<SponsorProfileScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _ratingsSummary;
  bool _loading = true;

  List<Map<String, dynamic>> _events = [];
  bool _loadingEvents = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _loadRatings();
      if (widget.isOrganizerView) _loadEvents();
    });
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getSponsorPublicProfile(widget.userId);
      if (mounted) setState(() { _profile = data; _loading = false; });
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ApiService.extractError(e));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadRatings() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getUserRatingsSummary(widget.userId);
      if (mounted) setState(() => _ratingsSummary = data);
    } catch (_) {}
  }

  Future<void> _loadEvents() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getSponsorEventsForOrganizer(widget.userId);
      if (mounted) {
        setState(() {
          _events = data.cast<Map<String, dynamic>>();
          _loadingEvents = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  Future<void> _refresh() async {
    await _load();
    await _loadRatings();
    if (widget.isOrganizerView) await _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    final companyName = _profile?['company_name'] ?? _profile?['display_name'] ?? 'Sponsor';

    return Scaffold(
      appBar: AppBar(title: Text(_loading ? 'Sponsor Profile' : companyName)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: List.generate(4, (_) => const ShimmerListTile())),
              )
            : _profile == null
                ? const Center(child: Text('Profile not found'))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildStats(),
                      if (_profile!['description'] != null &&
                          (_profile!['description'] as String).isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildDescription(),
                      ],
                      if (_ratingsSummary != null && (_ratingsSummary!['count'] as int? ?? 0) > 0) ...[
                        const SizedBox(height: 20),
                        _buildRatingsSection(),
                      ],
                      if (widget.isOrganizerView) ...[
                        const SizedBox(height: 20),
                        _buildEventsSection(),
                      ],
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeader() {
    final p = _profile!;
    final companyName = p['company_name'] ?? p['display_name'] ?? 'Sponsor';
    final contactName = p['contact_name'] ?? '';
    final profession = p['profession'] ?? '';
    final logoUrl = p['logo_url'];
    final websiteUrl = p['website_url'];
    final memberSince = p['member_since'];

    DateTime? joinDate;
    if (memberSince != null) {
      try { joinDate = DateTime.parse(memberSince); } catch (_) {}
    }

    final initial = companyName.isNotEmpty ? companyName[0].toUpperCase() : '?';

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
            radius: 40,
            backgroundColor: AppTheme.accentColor.withValues(alpha: 0.15),
            backgroundImage: logoUrl != null && logoUrl.toString().isNotEmpty
                ? NetworkImage(ApiConfig.imageUrl(logoUrl))
                : null,
            child: logoUrl == null || logoUrl.toString().isEmpty
                ? Text(initial,
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accentColor))
                : null,
          ),
          const SizedBox(height: 14),
          Text(companyName,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimaryOf(context))),
          if (contactName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(contactName,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondaryOf(context))),
          ],
          if (profession.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(profession,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentColor)),
            ),
          ],
          const SizedBox(height: 14),
          if (websiteUrl != null && websiteUrl.toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _openUrl(websiteUrl),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language_rounded,
                        size: 14, color: AppTheme.accentColor),
                    const SizedBox(width: 5),
                    Text(
                      websiteUrl.toString().replaceFirst(RegExp(r'^https?://'), ''),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentColor,
                          decoration: TextDecoration.underline),
                    ),
                  ],
                ),
              ),
            ),
          if (joinDate != null)
            Text(
              'Member since ${DateFormat.yMMMM().format(joinDate)}',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondaryOf(context)),
            ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final p = _profile!;
    final totalBids = p['total_bids'] ?? 0;
    final acceptedBids = p['accepted_bids'] ?? 0;
    final eventsSponsored = p['events_sponsored'] ?? 0;

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
              Icon(Icons.analytics_rounded,
                  size: 16, color: AppTheme.textSecondaryOf(context)),
              const SizedBox(width: 8),
              Text('Sponsorship Activity',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondaryOf(context),
                      letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statCard(
                icon: Icons.gavel_rounded,
                value: '$totalBids',
                label: 'Total Bids',
                color: AppTheme.accentColor,
              ),
              const SizedBox(width: 12),
              _statCard(
                icon: Icons.check_circle_rounded,
                value: '$acceptedBids',
                label: 'Accepted',
                color: AppTheme.successColor,
              ),
              const SizedBox(width: 12),
              _statCard(
                icon: Icons.event_rounded,
                value: '$eventsSponsored',
                label: 'Events',
                color: Colors.deepPurple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondaryOf(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildDescription() {
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
              Icon(Icons.info_outline_rounded,
                  size: 16, color: AppTheme.textSecondaryOf(context)),
              const SizedBox(width: 8),
              Text('About',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondaryOf(context),
                      letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _profile!['description'],
            style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppTheme.textPrimaryOf(context)),
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
              Icon(Icons.event_rounded,
                  size: 16, color: AppTheme.textSecondaryOf(context)),
              const SizedBox(width: 8),
              Text('Sponsored Events',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondaryOf(context),
                      letterSpacing: 0.3)),
              const SizedBox(width: 8),
              if (!_loadingEvents)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${_events.length}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentColor)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingEvents)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )),
            )
          else if (_events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No sponsored events yet.',
                    style: TextStyle(color: AppTheme.textSecondaryOf(context))),
              ),
            )
          else
            ..._events.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SponsorEventCard(event: e),
            )),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}


class _SponsorEventCard extends StatelessWidget {
  final Map<String, dynamic> event;

  const _SponsorEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final title = event['title'] ?? 'Untitled';
    final status = event['status'] ?? '';
    final venueName = event['venue_name'];
    final venueCity = event['venue_city'];
    final startTime = event['start_time'];
    final totalCents = event['total_amount_cents'] ?? 0;
    final amount = '\$${(totalCents / 100).toStringAsFixed(2)}';
    final bids = (event['bids'] as List?) ?? [];
    final summary = event['bid_summary'] as Map<String, dynamic>? ?? {};
    final pending = summary['pending'] ?? 0;
    final accepted = summary['accepted'] ?? 0;
    final rejected = summary['rejected'] ?? 0;
    final paid = summary['paid'] ?? 0;

    String dateStr = '';
    if (startTime != null) {
      try {
        final dt = DateTime.parse(startTime);
        dateStr = DateFormat('MMM d, yyyy').format(dt);
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => context.push('/events/${event['event_id']}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.dividerOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryOf(context))),
                ),
                _statusBadge(context, status),
              ],
            ),
            const SizedBox(height: 6),
            if (dateStr.isNotEmpty || venueName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    if (dateStr.isNotEmpty) ...[
                      Icon(Icons.calendar_today_rounded,
                          size: 13,
                          color: AppTheme.textSecondaryOf(context)),
                      const SizedBox(width: 4),
                      Text(dateStr,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondaryOf(context))),
                    ],
                    if (dateStr.isNotEmpty && venueName != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text('\u2022',
                            style: TextStyle(
                                color: AppTheme.textSecondaryOf(context),
                                fontSize: 9)),
                      ),
                    if (venueName != null) ...[
                      Icon(Icons.location_on_rounded,
                          size: 13,
                          color: AppTheme.textSecondaryOf(context)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          venueCity != null
                              ? '$venueName, $venueCity'
                              : venueName,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondaryOf(context)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            Divider(color: AppTheme.dividerOf(context), height: 12),
            Row(
              children: [
                Text('Total: ',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context))),
                Text(amount,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.secondaryColor)),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (pending > 0)
                  _summaryChip(context, '$pending Under Review', Colors.orange),
                if (accepted > 0)
                  _summaryChip(
                      context, '$accepted Accepted', AppTheme.accentColor),
                if (paid > 0)
                  _summaryChip(
                      context, '$paid Paid', AppTheme.secondaryColor),
                if (rejected > 0)
                  _summaryChip(
                      context, '$rejected Rejected', AppTheme.errorColor),
              ],
            ),
            if (bids.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...bids.map((b) {
                final cat = b['category'] ?? '';
                final cents = b['amount_cents'] ?? 0;
                final bidStatus = b['status'] ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Icon(Icons.circle,
                          size: 5, color: _bidStatusColor(context, bidStatus)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(cat,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textPrimaryOf(context))),
                      ),
                      Text(
                        '\$${(cents / 100).toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryOf(context)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                          bidStatus == 'pending'
                              ? 'under review'
                              : bidStatus,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _bidStatusColor(context, bidStatus))),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context, String status) {
    final color = switch (status) {
      'approved' => AppTheme.secondaryColor,
      'live' => const Color(0xFFE11900),
      'selling_tickets' => AppTheme.accentColor,
      'waiting_event_date' => Colors.orange,
      'completed' => AppTheme.textSecondaryOf(context),
      'cancelled' => AppTheme.errorColor,
      _ => AppTheme.textSecondaryOf(context),
    };
    final label = switch (status) {
      'approved' => 'Funding',
      'live' => 'Live',
      'selling_tickets' => 'Selling Tickets',
      'waiting_event_date' => 'Awaiting Date',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style:
              TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _summaryChip(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style:
              TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Color _bidStatusColor(BuildContext context, String status) {
    return switch (status) {
      'pending' => Colors.orange,
      'accepted' => AppTheme.accentColor,
      'paid' => AppTheme.secondaryColor,
      'rejected' => AppTheme.errorColor,
      _ => AppTheme.textSecondaryOf(context),
    };
  }
}


/// Quick-view bottom sheet for sponsor profile.
void showSponsorProfileSheet(BuildContext context, int sponsorUserId, {bool isOrganizerView = false}) {
  final api = context.read<ApiService>();
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    backgroundColor: AppTheme.cardOf(context),
    builder: (ctx) {
      return FutureBuilder<Map<String, dynamic>>(
        future: api.getSponsorPublicProfile(sponsorUserId),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError || !snap.hasData) {
            return SizedBox(
              height: 200,
              child: Center(
                child: Text('Could not load sponsor profile',
                    style: TextStyle(color: AppTheme.textSecondaryOf(ctx))),
              ),
            );
          }

          final p = snap.data!;
          final companyName = p['company_name'] ?? p['display_name'] ?? 'Sponsor';
          final contactName = p['contact_name'] ?? '';
          final profession = p['profession'] ?? '';
          final logoUrl = p['logo_url'];
          final totalBids = p['total_bids'] ?? 0;
          final acceptedBids = p['accepted_bids'] ?? 0;
          final eventsSponsored = p['events_sponsored'] ?? 0;
          final initial = companyName.isNotEmpty ? companyName[0].toUpperCase() : '?';

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerOf(ctx),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppTheme.accentColor.withValues(alpha: 0.15),
                  backgroundImage: logoUrl != null && logoUrl.toString().isNotEmpty
                      ? NetworkImage(ApiConfig.imageUrl(logoUrl))
                      : null,
                  child: logoUrl == null || logoUrl.toString().isEmpty
                      ? Text(initial,
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accentColor))
                      : null,
                ),
                const SizedBox(height: 12),
                Text(companyName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryOf(ctx))),
                if (contactName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(contactName,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryOf(ctx))),
                ],
                if (profession.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(profession,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentColor)),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _sheetStat(ctx, '$totalBids', 'Bids', AppTheme.accentColor),
                    const SizedBox(width: 16),
                    _sheetStat(ctx, '$acceptedBids', 'Accepted', AppTheme.successColor),
                    const SizedBox(width: 16),
                    _sheetStat(ctx, '$eventsSponsored', 'Events', Colors.deepPurple),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SponsorProfileScreen(
                          userId: sponsorUserId,
                          isOrganizerView: isOrganizerView,
                        ),
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('View Full Profile',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _sheetStat(BuildContext context, String value, String label, Color color) {
  return Column(
    children: [
      Text(value,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              fontSize: 11, color: AppTheme.textSecondaryOf(context))),
    ],
  );
}
