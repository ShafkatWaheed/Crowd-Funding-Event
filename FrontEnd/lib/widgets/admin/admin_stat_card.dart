import 'package:flutter/material.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';

/// Metric card for admin Overview (users, events, commissions, etc.).
class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.width = 180,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              AppSpacing.vMd,
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.vXs,
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.textSecondaryOf(context),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
