import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/date_time_utils.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/sponsor.dart';
import '../../models/user.dart';
import '../../models/rating.dart';
import '../../repositories/base_repository.dart';
import '../../providers/user_provider.dart';
import '../../providers/sponsor_provider.dart';
import '../../widgets/app_chip.dart';
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
  SponsorPublicProfile? _profile;
  RatingsSummary? _ratingsSummary;
  bool _loading = true;

  List<SponsorEventItem> _events = [];
  bool _loadingEvents = true;

  final _eventSearchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String _eventSearchQuery = '';
  String? _eventStatusFilter;

  static const _statusFilters = <(String, String?)>[
    ('All', null),
    ('Funding', 'approved'),
    ('Selling', 'selling_tickets'),
    ('Live', 'live'),
    ('Completed', 'completed'),
    ('Cancelled', 'cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _loadRatings();
      if (widget.isOrganizerView) _loadEvents();
    });
  }

  @override
  void dispose() {
    _eventSearchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  List<SponsorEventItem> get _filteredEvents {
    var list = _events;
    if (_eventStatusFilter != null) {
      list = list.where((e) => e.status == _eventStatusFilter).toList();
    }
    if (_eventSearchQuery.isNotEmpty) {
      final q = _eventSearchQuery.toLowerCase();
      list = list.where((e) {
        final title = e.title.toLowerCase();
        final venue = (e.venueName ?? '').toLowerCase();
        return title.contains(q) || venue.contains(q);
      }).toList();
    }
    return list;
  }

  void _onEventSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_eventSearchQuery != value) {
        setState(() => _eventSearchQuery = value);
      }
    });
  }

  void _onEventStatusFilterChanged(String? status) {
    if (_eventStatusFilter == status) return;
    setState(() => _eventStatusFilter = status);
  }

  Future<void> _load() async {
    try {
      final userRepo = context.read<UserProvider>();
      final data = await userRepo.getSponsorPublicProfile(widget.userId);
      if (mounted) setState(() { _profile = data; _loading = false; });
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ApiError.extractMessage(e));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadRatings() async {
    try {
      final userRepo = context.read<UserProvider>();
      final data = await userRepo.getUserRatingsSummary(widget.userId);
      if (mounted) setState(() => _ratingsSummary = data);
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _loadEvents() async {
    try {
      final api = context.read<SponsorProvider>();
      final data = await api.getSponsorEventsForOrganizer(widget.userId);
      if (mounted) {
        setState(() {
          _events = data;
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
    final companyName = _profile?.companyName ?? _profile?.displayName ?? 'Sponsor';

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
                      if (_profile!.description != null &&
                          _profile!.description!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildDescription(),
                      ],
                      if (_profile!.hasContactInfo) ...[
                        const SizedBox(height: 20),
                        _buildSocialSection(),
                      ],
                      if (_ratingsSummary != null && _ratingsSummary!.count > 0) ...[
                        const SizedBox(height: 20),
                        _buildRatingsSection(context),
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
    final companyName = p.companyName ?? p.displayName ?? 'Sponsor';
    final contactName = p.contactName ?? '';
    final profession = p.profession ?? '';
    final logoUrl = p.logoUrl;
    final websiteUrl = p.websiteUrl;
    final memberSince = p.memberSince;

    DateTime? joinDate;
    if (memberSince != null) {
      try { joinDate = DateTime.parse(memberSince); } catch (e) { debugPrint(e.toString()); }
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
            backgroundImage: logoUrl != null && logoUrl.isNotEmpty
                ? NetworkImage(ApiConfig.imageUrl(logoUrl))
                : null,
            child: logoUrl == null || logoUrl.isEmpty
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
          if (websiteUrl != null && websiteUrl.isNotEmpty)
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
                      websiteUrl.replaceFirst(RegExp(r'^https?://'), ''),
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
              'Member since ${AppDateFormat.monthYear(joinDate)}',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondaryOf(context)),
            ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final p = _profile!;
    final totalBids = p.totalBids;
    final acceptedBids = p.acceptedBids;
    final eventsSponsored = p.eventsSponsored;

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
                color: context.sponsorAccent,
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
            _profile!.description!,
            style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppTheme.textPrimaryOf(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingsSection(BuildContext context) {
    final s = _ratingsSummary!;
    final avgStars = s.avgStars;
    final count = s.count;
    final topReviews = s.topReviews;
    final worstReviews = s.worstReviews;

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
          if (worstReviews.isNotEmpty && worstReviews.first.stars < 4) ...[
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

  Widget _reviewTile(Rating r) {
    final stars = r.stars;
    final name = r.raterName;
    final desc = r.description ?? '';
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

  Widget _buildSocialSection() {
    final p = _profile!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: AppTheme.socialHeaderGradient(isDark),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.public_rounded, size: 16, color: AppTheme.accentColor),
                const SizedBox(width: 8),
                Text(
                  'Contact & Social',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.brandIndigo,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (p.contactEmail?.isNotEmpty ?? false)
                  _socialChip(Icons.alternate_email_rounded, p.contactEmail!, 'mailto:${p.contactEmail!}', AppTheme.brandIndigo),
                if (p.websiteUrl?.isNotEmpty ?? false)
                  _socialChip(Icons.language_rounded, 'Website', p.websiteUrl!.startsWith('http') ? p.websiteUrl! : 'https://${p.websiteUrl}', AppTheme.brandIndigo),
                if (p.instagram?.isNotEmpty ?? false)
                  _socialChip(Icons.camera_alt_outlined, 'Instagram', 'https://instagram.com/${p.instagram}', AppTheme.brandInstagram),
                if (p.twitter?.isNotEmpty ?? false)
                  _socialChip(Icons.alternate_email_rounded, 'X / Twitter', 'https://x.com/${p.twitter}', AppTheme.primaryColor),
                if (p.facebook?.isNotEmpty ?? false)
                  _socialChip(Icons.facebook_rounded, 'Facebook', 'https://facebook.com/${p.facebook}', AppTheme.brandFacebook),
                if (p.linkedin?.isNotEmpty ?? false)
                  _socialChip(Icons.work_outline_rounded, 'LinkedIn', 'https://linkedin.com/in/${p.linkedin}', AppTheme.brandLinkedIn),
                if (p.youtube?.isNotEmpty ?? false)
                  _socialChip(Icons.play_circle_outline_rounded, 'YouTube', 'https://youtube.com/@${p.youtube}', AppTheme.brandYouTube),
                if (p.tiktok?.isNotEmpty ?? false)
                  _socialChip(Icons.music_note_rounded, 'TikTok', 'https://tiktok.com/@${p.tiktok}', AppTheme.primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialChip(IconData icon, String label, String url, Color color) {
    return GestureDetector(
      onTap: () => _openUrl(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsSection() {
    final filtered = _filteredEvents;

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
                  child: Text('${filtered.length}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentColor)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _eventSearchCtrl,
            onChanged: _onEventSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search events\u2026',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _eventSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _eventSearchCtrl.clear();
                        setState(() => _eventSearchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.inputFillOf(context),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              isDense: true,
            ),
            style: TextStyle(
                fontSize: 14, color: AppTheme.textPrimaryOf(context)),
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
                final active = _eventStatusFilter == f.$2;
                return AppChip(
                  label: f.$1,
                  selected: active,
                  onSelected: (_) =>
                      _onEventStatusFilterChanged(active ? null : f.$2),
                  chipColor: AppTheme.accentColor,
                  fontSize: 12,
                  compact: true,
                  bgColor: AppTheme.surfaceOf(ctx),
                  inactiveSide: BorderSide.none,
                );
              },
            ),
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
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                    _eventSearchQuery.isNotEmpty || _eventStatusFilter != null
                        ? 'No matching events'
                        : 'No sponsored events yet.',
                    style: TextStyle(color: AppTheme.textSecondaryOf(context))),
              ),
            )
          else
            ...filtered.map((e) => Padding(
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
  final SponsorEventItem event;

  const _SponsorEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final title = event.title;
    final status = event.status;
    final venueName = event.venueName;
    final venueCity = event.venueCity;
    final startTime = event.startTime;
    final totalCents = event.totalAmountCents;
    final amount = '\$${(totalCents / 100).toStringAsFixed(2)}';
    final bids = event.bids;

    String dateStr = '';
    if (startTime != null) {
      try {
        final dt = DateTime.parse(startTime);
        dateStr = AppDateFormat.dateOnly(dt);
      } catch (e) { debugPrint(e.toString()); }
    }

    return GestureDetector(
      onTap: () => context.push('/events/${event.eventId}'),
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
            if (bids.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...bids.map((b) {
                final cat = b.category;
                final cents = b.amountCents;
                final bidStatus = b.status;
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
      'live' => context.statusLive,
      'selling_tickets' => AppTheme.accentColor,
      'waiting_event_date' => context.statusWaiting,
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

  Color _bidStatusColor(BuildContext context, String status) {
    return switch (status) {
      'pending' => context.bidPending,
      'accepted' => AppTheme.accentColor,
      'paid' => AppTheme.secondaryColor,
      'rejected' => AppTheme.errorColor,
      _ => AppTheme.textSecondaryOf(context),
    };
  }
}


/// Quick-view bottom sheet for sponsor profile.
void showSponsorProfileSheet(BuildContext context, int sponsorUserId, {bool isOrganizerView = false}) {
  final userRepo = context.read<UserProvider>();
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    backgroundColor: AppTheme.cardOf(context),
    builder: (ctx) {
      return FutureBuilder<SponsorPublicProfile>(
        future: userRepo.getSponsorPublicProfile(sponsorUserId),
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
          final companyName = p.companyName ?? p.displayName ?? 'Sponsor';
          final contactName = p.contactName ?? '';
          final profession = p.profession ?? '';
          final logoUrl = p.logoUrl;
          final totalBids = p.totalBids;
          final acceptedBids = p.acceptedBids;
          final eventsSponsored = p.eventsSponsored;
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
                  backgroundImage: logoUrl != null && logoUrl.isNotEmpty
                      ? NetworkImage(ApiConfig.imageUrl(logoUrl))
                      : null,
                  child: logoUrl == null || logoUrl.isEmpty
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
                    _sheetStat(ctx, '$eventsSponsored', 'Events', ctx.sponsorAccent),
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
