import 'package:flutter/material.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';

/// Empty state for admin tabs (e.g. "No events awaiting approval").
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppTheme.textSecondaryOf(context),
          ),
          AppSpacing.vLg,
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: AppTheme.textSecondaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
