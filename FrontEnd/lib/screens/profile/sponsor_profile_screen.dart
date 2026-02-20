import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/star_rating.dart';

class SponsorProfileScreen extends StatefulWidget {
  final int userId;
  const SponsorProfileScreen({super.key, required this.userId});

  @override
  State<SponsorProfileScreen> createState() => _SponsorProfileScreenState();
}

class _SponsorProfileScreenState extends State<SponsorProfileScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _ratingsSummary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _loadRatings();
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

  @override
  Widget build(BuildContext context) {
    final companyName = _profile?['company_name'] ?? _profile?['display_name'] ?? 'Sponsor';

    return Scaffold(
      appBar: AppBar(title: Text(_loading ? 'Sponsor Profile' : companyName)),
      body: RefreshIndicator(
        onRefresh: () async { await _load(); await _loadRatings(); },
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
                ? NetworkImage(logoUrl)
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Quick-view bottom sheet for sponsor profile.
/// Call this from any screen to show a sponsor preview with "View Full Profile" button.
void showSponsorProfileSheet(BuildContext context, int sponsorUserId) {
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
                      ? NetworkImage(logoUrl)
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
                        builder: (_) => SponsorProfileScreen(userId: sponsorUserId),
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
