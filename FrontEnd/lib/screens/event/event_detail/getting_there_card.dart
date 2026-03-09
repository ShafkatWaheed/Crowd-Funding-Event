import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_icons.dart';
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
              if (event.venue != null) ...[
                EventDetailHelpers.modernInfoRow(context,
                    AppIcons.venueName.icon, 'Venue', event.venue!.name,
                    iconColor: AppIcons.venueName.color(isDark)),
                EventDetailHelpers.modernInfoRow(context,
                    AppIcons.venueAddress.icon, 'Address', event.venue!.fullAddress,
                    iconColor: AppIcons.venueAddress.color(isDark)),
              ],
              if (event.parkingInfo != null && event.parkingInfo!.isNotEmpty)
                EventDetailHelpers.modernInfoRow(context,
                    AppIcons.venueParking.icon, 'Parking', event.parkingInfo!,
                    iconColor: AppIcons.venueParking.color(isDark)),
              if (event.transitInfo != null && event.transitInfo!.isNotEmpty)
                EventDetailHelpers.modernInfoRow(context,
                    AppIcons.venueTransit.icon, 'Transit', event.transitInfo!,
                    iconColor: AppIcons.venueTransit.color(isDark)),
              if (event.rideshareInfo != null && event.rideshareInfo!.isNotEmpty)
                EventDetailHelpers.modernInfoRow(context,
                    AppIcons.venueRideshare.icon, 'Rideshare', event.rideshareInfo!,
                    iconColor: AppIcons.venueRideshare.color(isDark)),
              if (event.accessibilityInfo != null &&
                  event.accessibilityInfo!.isNotEmpty)
                EventDetailHelpers.modernInfoRow(context,
                    AppIcons.venueAccessibility.icon, 'Accessibility',
                    event.accessibilityInfo!,
                    iconColor: AppIcons.venueAccessibility.color(isDark)),
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
                    icon: Icon(AppIcons.venueHeader.icon,
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
