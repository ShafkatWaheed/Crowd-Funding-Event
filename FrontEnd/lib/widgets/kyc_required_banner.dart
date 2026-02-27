import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/theme.dart';

class KycRequiredBanner extends StatelessWidget {
  const KycRequiredBanner({super.key, this.action});

  final String? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: AppTheme.warningColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Identity Verification Required',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  action != null
                      ? 'Complete identity verification to $action.'
                      : 'Complete identity verification to access this feature.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.push('/profile'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text('Verify', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
