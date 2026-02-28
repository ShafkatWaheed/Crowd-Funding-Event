import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event.dart';
import 'event_detail_helpers.dart';

class GettingThereCard extends StatelessWidget {
  final Event event;

  const GettingThereCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    if (event.venue == null && !event.hasTransportInfo) {
      return const SizedBox.shrink();
    }

    final isDark = AppTheme.isDark(context);
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: AppTheme.cardOf(context),
            borderRadius: AppRadius.lg,
            boxShadow: AppShadow.card(isDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_rounded,
                      size: AppIconSize.sm,
                      color: AppTheme.textSecondaryOf(context)),
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
              if (event.venue != null) ...[
                EventDetailHelpers.modernInfoRow(
                    context, Icons.place_rounded, 'Venue', event.venue!.name),
                EventDetailHelpers.modernInfoRow(context, Icons.map_outlined,
                    'Address', event.venue!.fullAddress),
              ],
              if (event.parkingInfo != null && event.parkingInfo!.isNotEmpty)
                EventDetailHelpers.modernInfoRow(context,
                    Icons.local_parking_rounded, 'Parking', event.parkingInfo!),
              if (event.transitInfo != null && event.transitInfo!.isNotEmpty)
                EventDetailHelpers.modernInfoRow(
                    context,
                    Icons.directions_transit_rounded,
                    'Transit',
                    event.transitInfo!),
              if (event.rideshareInfo != null && event.rideshareInfo!.isNotEmpty)
                EventDetailHelpers.modernInfoRow(context,
                    Icons.local_taxi_rounded, 'Rideshare', event.rideshareInfo!),
              if (event.accessibilityInfo != null &&
                  event.accessibilityInfo!.isNotEmpty)
                EventDetailHelpers.modernInfoRow(
                    context,
                    Icons.accessible_rounded,
                    'Accessibility',
                    event.accessibilityInfo!),
              if (event.directionsUrl != null) ...[
                AppSpacing.vMd,
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
                    icon: const Icon(Icons.navigation_rounded,
                        size: AppIconSize.sm),
                    label: const Text('Get Directions'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryOf(context),
                      side: BorderSide(
                          color:
                              AppTheme.primaryOf(context).withValues(alpha:0.4)),
                      shape:
                          RoundedRectangleBorder(borderRadius: AppRadius.md),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        AppSpacing.vXl,
      ],
    );
  }
}
