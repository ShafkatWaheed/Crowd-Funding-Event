import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../config/api_config.dart';
import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/sponsor.dart';
import '../../../providers/sponsor_provider.dart';

class SponsorCarousel extends StatefulWidget {
  final int eventId;
  const SponsorCarousel({super.key, required this.eventId});

  @override
  State<SponsorCarousel> createState() => _SponsorCarouselState();
}

class _SponsorCarouselState extends State<SponsorCarousel> {
  List<EventSponsor> _sponsors = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final api = context.read<SponsorProvider>();
      final data = await api.getEventSponsors(widget.eventId);
      if (mounted) {
        setState(() {
          _sponsors = data;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _navigateToSponsorProfile(EventSponsor sponsor) {
    context.push('/users/${sponsor.sponsorUserId}/sponsor-profile');
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
              final name = s.companyName;
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
                        backgroundImage: s.logoUrl != null
                            ? NetworkImage(ApiConfig.imageUrl(s.logoUrl!))
                            : null,
                        child: s.logoUrl == null
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
