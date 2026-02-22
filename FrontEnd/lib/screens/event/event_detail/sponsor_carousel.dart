import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../config/api_config.dart';
import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../services/api_service.dart';

class SponsorCarousel extends StatefulWidget {
  final int eventId;
  const SponsorCarousel({required this.eventId});

  @override
  State<SponsorCarousel> createState() => _SponsorCarouselState();
}

class _SponsorCarouselState extends State<SponsorCarousel> {
  List<Map<String, dynamic>> _sponsors = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getEventSponsors(widget.eventId);
      if (mounted) {
        setState(() {
          _sponsors = data.cast<Map<String, dynamic>>();
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _navigateToSponsorProfile(Map<String, dynamic> sponsor) {
    final userId = sponsor['sponsor_user_id'];
    if (userId != null) {
      context.push('/users/$userId/sponsor-profile');
    }
  }

  void _showSponsorSheet(Map<String, dynamic> sponsor) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: AppSpacing.paddingXxl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: AppSpacing.xxxl,
              backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
              backgroundImage: sponsor['logo_url'] != null
                  ? NetworkImage(ApiConfig.imageUrl(sponsor['logo_url']))
                  : null,
              child: sponsor['logo_url'] == null
                  ? Text(
                      (sponsor['company_name'] as String? ?? '?')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            AppSpacing.vMd,
            Text(
              sponsor['company_name'] ?? 'Sponsor',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (sponsor['website_url'] != null &&
                (sponsor['website_url'] as String).isNotEmpty) ...[
              AppSpacing.vSm,
              Text(
                sponsor['website_url'],
                style: TextStyle(
                    color: AppTheme.accentColor, fontSize: 13),
              ),
            ],
            AppSpacing.vLg,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _sponsors.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            'Sponsored by',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ),
        AppSpacing.vMd,
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _sponsors.length,
            separatorBuilder: (_, __) => AppSpacing.hMd,
            itemBuilder: (context, index) {
              final s = _sponsors[index];
              final name = s['company_name'] as String? ?? 'Sponsor';
              return GestureDetector(
                onTap: () => _navigateToSponsorProfile(s),
                child: SizedBox(
                  width: 64,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: AppSpacing.xxl,
                        backgroundColor:
                            AppTheme.accentColor.withValues(alpha: 0.12),
                        backgroundImage: s['logo_url'] != null
                            ? NetworkImage(ApiConfig.imageUrl(s['logo_url']))
                            : null,
                        child: s['logo_url'] == null
                            ? Text(
                                name.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppTheme.accentColor),
                              )
                            : null,
                      ),
                      AppSpacing.vXs,
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
