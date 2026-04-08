import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_icons.dart';
import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../models/event.dart';

/// Decorative colours for the static map placeholder illustration.
/// These are not semantic tokens — they represent water, parks, roads, and
/// buildings in a stylised mini-map drawn when no real coordinates are available.
class _MapColors {
  _MapColors._();

  // Background / base
  static Color base(bool isDark) =>
      isDark ? const Color(0xFF111C2E) : const Color(0xFFE8EEDE);

  // Water area
  static Color water(bool isDark) => isDark
      ? const Color(0xFF0E1A30)
      : const Color(0xFF8CB4F0).withValues(alpha: 0.55);

  // Park fill + border
  static Color park(bool isDark) => isDark
      ? const Color(0xFF1E4020).withValues(alpha: 0.75)
      : const Color(0xFF8CC364).withValues(alpha: 0.50);
  static Color parkBorder(bool isDark) => isDark
      ? const Color(0xFF2E6030).withValues(alpha: 0.45)
      : const Color(0xFF64AA46).withValues(alpha: 0.35);

  // Building blocks
  static Color block(bool isDark) => isDark
      ? const Color(0xFF162236).withValues(alpha: 0.90)
      : const Color(0xFFC8D7B4).withValues(alpha: 0.75);

  // Roads
  static Color roadMain(bool isDark) =>
      isDark ? const Color(0xFF253550) : Colors.white.withValues(alpha: 0.93);
  static Color roadSecondary(bool isDark) => isDark
      ? const Color(0xFF1E2D46).withValues(alpha: 0.88)
      : Colors.white.withValues(alpha: 0.70);
}

class GettingThereCard extends StatefulWidget {
  final Event event;

  const GettingThereCard({super.key, required this.event});

  @override
  State<GettingThereCard> createState() => _GettingThereCardState();
}

class _GettingThereCardState extends State<GettingThereCard> {
  final Set<String> _expanded = {};

  void _toggle(String key) => setState(() {
        _expanded.contains(key) ? _expanded.remove(key) : _expanded.add(key);
      });

  // Truncate a long transport string to a concise chip label
  static String _shortLabel(String text) {
    if (text.length <= 24) return text;
    final comma = text.indexOf(',');
    if (comma > 0 && comma <= 22) return text.substring(0, comma);
    final dot = text.indexOf('.');
    if (dot > 0 && dot <= 22) return text.substring(0, dot);
    return '${text.substring(0, 21)}…';
  }

  // ── Map thumbnail ──────────────────────────────────────────────────────────
  Widget _buildMap(bool isDark) {
    final venue = widget.event.venue;
    final lat = venue?.lat;
    final lng = venue?.lng;
    final fadeTo =
        AppTheme.cardOf(context).withValues(alpha: 0.65);
    final pinColor = AppTheme.errorOf(context);

    if (lat != null && lng != null) {
      final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
      final style = isDark ? 'dark-v11' : 'streets-v12';
      final tileUrl = token.isNotEmpty
          ? 'https://api.mapbox.com/styles/v1/mapbox/$style/tiles/{z}/{x}/{y}@2x?access_token=$token'
          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

      return SizedBox(
        height: 130,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(lat, lng),
                initialZoom: 15.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: tileUrl,
                  maxZoom: 19,
                  userAgentPackageName: 'com.crowdfunding.app',
                  tileProvider: NetworkTileProvider(),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(lat, lng),
                      width: 36,
                      height: 44,
                      child: Icon(
                        Icons.pin_drop_rounded,
                        size: 36,
                        color: pinColor,
                        shadows: [
                          Shadow(
                              color: pinColor.withValues(alpha: 0.40),
                              blurRadius: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Bottom fade overlay
            Positioned(
              left: 0, right: 0, bottom: 0, height: 28,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, fadeTo],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Fallback: painted placeholder (no coordinates) ──
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      const h = 130.0;
      final base = _MapColors.base(isDark);
      final water = _MapColors.water(isDark);
      final park = _MapColors.park(isDark);
      final parkBorder = _MapColors.parkBorder(isDark);
      final block = _MapColors.block(isDark);
      final roadMain = _MapColors.roadMain(isDark);
      final roadSec = _MapColors.roadSecondary(isDark);

      const blocks = [
        [0.58, 0.08, 0.16, 0.22],
        [0.76, 0.08, 0.18, 0.22],
        [0.58, 0.38, 0.16, 0.24],
        [0.76, 0.38, 0.18, 0.24],
        [0.58, 0.70, 0.16, 0.22],
        [0.76, 0.70, 0.18, 0.22],
      ];

      return SizedBox(
        height: h,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Container(width: w, height: h, color: base),
            Positioned(
              left: 0, top: 0, bottom: 0, width: w * 0.18,
              child: Container(color: water),
            ),
            Positioned(
              left: w * 0.22, top: h * 0.10, width: w * 0.32, height: h * 0.80,
              child: Container(
                decoration: BoxDecoration(
                  color: park,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: parkBorder),
                ),
              ),
            ),
            for (final b in blocks)
              Positioned(
                left: w * b[0], top: h * b[1], width: w * b[2], height: h * b[3],
                child: Container(
                  decoration: BoxDecoration(
                    color: block,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Positioned(
              left: w * 0.18, right: 0, top: h * 0.50 - 5, height: 10,
              child: Container(color: roadMain),
            ),
            Positioned(
              left: w * 0.54, right: 0, top: h * 0.28 - 3, height: 6,
              child: Container(color: roadSec),
            ),
            Positioned(
              left: w * 0.54, right: 0, top: h * 0.72 - 3, height: 6,
              child: Container(color: roadSec),
            ),
            Positioned(
              left: w * 0.54 - 5, top: 0, bottom: 0, width: 10,
              child: Container(color: roadMain),
            ),
            Positioned(
              left: w * 0.73 - 3, top: 0, bottom: 0, width: 6,
              child: Container(color: roadSec),
            ),
            Positioned(
              left: w * 0.54 - 16,
              top: h * 0.50 - 32,
              child: Icon(
                Icons.pin_drop_rounded,
                size: 32,
                color: pinColor,
                shadows: [
                  Shadow(color: pinColor.withValues(alpha: 0.40), blurRadius: 10),
                ],
              ),
            ),
            Positioned(
              left: 0, right: 0, bottom: 0, height: 28,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, fadeTo],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── Expandable transport chip ──────────────────────────────────────────────
  Widget _buildChip(
    BuildContext context, {
    required String key,
    required IconData icon,
    required Color color,
    required String text,
    required bool isDark,
  }) {
    final expanded = _expanded.contains(key);
    return GestureDetector(
      onTap: () => _toggle(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(expanded ? 12 : 20),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            expanded
                ? Flexible(
                    child: Text(text,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: color)))
                : Text(_shortLabel(text),
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(width: 2),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 11,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    if (event.venue == null && !event.hasTransportInfo) {
      return const SizedBox.shrink();
    }

    final isDark = AppTheme.isDark(context);
    final hasVenue = event.venue != null;

    return Column(
      children: [
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.cardOf(context),
            borderRadius: AppRadius.lg,
            boxShadow: AppShadow.card(isDark),
            border: isDark
                ? Border.all(color: Colors.white.withValues(alpha: 0.07))
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Map thumbnail (only when venue is set) ──
              if (hasVenue) _buildMap(isDark),

              Padding(
                padding: AppSpacing.paddingLg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Section header ──
                    Row(
                      children: [
                        Icon(AppIcons.venueHeader.icon,
                            size: AppIconSize.sm,
                            color: AppIcons.venueHeader.color(isDark)),
                        AppSpacing.hSm,
                        Text(
                          'Getting There',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondaryOf(context),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.vMd,

                    // ── Venue name + address compact row ──
                    if (hasVenue) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(AppIcons.venueName.icon,
                              size: 16, color: AppIcons.venueName.color(isDark)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.venue!.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimaryOf(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(AppIcons.venueAddress.icon,
                                        size: 11,
                                        color: AppTheme.errorOf(context)),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        event.venue!.fullAddress,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondaryOf(context)),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                          height: 1,
                          color: AppTheme.accentColor.withValues(alpha: 0.09)),
                      const SizedBox(height: 10),
                    ],

                    // ── Expandable transport chips ──
                    if (event.hasTransportInfo) ...[
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          if (event.parkingInfo != null &&
                              event.parkingInfo!.isNotEmpty)
                            _buildChip(context,
                                key: 'parking',
                                icon: AppIcons.venueParking.icon,
                                color: AppIcons.venueParking.color(isDark),
                                text: event.parkingInfo!,
                                isDark: isDark),
                          if (event.transitInfo != null &&
                              event.transitInfo!.isNotEmpty)
                            _buildChip(context,
                                key: 'transit',
                                icon: AppIcons.venueTransit.icon,
                                color: AppIcons.venueTransit.color(isDark),
                                text: event.transitInfo!,
                                isDark: isDark),
                          if (event.rideshareInfo != null &&
                              event.rideshareInfo!.isNotEmpty)
                            _buildChip(context,
                                key: 'rideshare',
                                icon: AppIcons.venueRideshare.icon,
                                color: AppIcons.venueRideshare.color(isDark),
                                text: event.rideshareInfo!,
                                isDark: isDark),
                          if (event.accessibilityInfo != null &&
                              event.accessibilityInfo!.isNotEmpty)
                            _buildChip(context,
                                key: 'accessibility',
                                icon: AppIcons.venueAccessibility.icon,
                                color: AppIcons.venueAccessibility.color(isDark),
                                text: event.accessibilityInfo!,
                                isDark: isDark),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Get Directions button ──
                    if (event.directionsUrl != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(event.directionsUrl!);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: Icon(AppIcons.venueHeader.icon,
                              size: AppIconSize.sm),
                          label: const Text('Get Directions'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryOf(context),
                            side: BorderSide(
                                color: AppTheme.primaryOf(context)
                                    .withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.md),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AppSpacing.vXl,
      ],
    );
  }
}
