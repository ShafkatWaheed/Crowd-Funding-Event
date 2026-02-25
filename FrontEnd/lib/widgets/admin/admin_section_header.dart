import 'package:flutter/material.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';

/// Consistent section header for admin tabs (e.g. "Pending Cancellations", "Under Review").
class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.count,
    this.description,
  });

  final IconData icon;
  final String title;
  final Color? iconColor;
  final int? count;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppTheme.accentOf(context);
    final label = count != null ? '$title ($count)' : title;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: AppIconSize.md),
              AppSpacing.hMd,
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                description!,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
