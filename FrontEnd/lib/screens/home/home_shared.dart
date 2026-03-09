import 'package:flutter/material.dart';

import '../../config/app_icons.dart';
import '../../config/design_tokens.dart';
import '../../models/event.dart';
import '../../utils/date_time_utils.dart';

export '../../models/sponsor.dart' show SponsorBidEvent;

String statusDisplayName(EventStatus s) =>
    AppIcons.forEventStatus(s).displayName;

Color statusChipColor(BuildContext context, EventStatus s) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return AppIcons.forEventStatus(s).color(isDark);
}

IconData statusChipIcon(EventStatus s) =>
    AppIcons.forEventStatus(s).icon;

String formatCents(int cents) =>
    '\$${(cents / 100).toStringAsFixed(2)}';

String relativeTime(DateTime dt) => AppDateFormat.relativeTime(dt);

Widget customerQuickAction({
  required BuildContext context,
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.md,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: AppIconSize.md, color: color),
            AppSpacing.hSm,
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    ),
  );
}
