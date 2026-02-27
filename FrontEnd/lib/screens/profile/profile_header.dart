import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../config/theme.dart';
import '../../config/design_tokens.dart';
import '../../models/user.dart';

class ProfileHeaderCard extends StatelessWidget {
  final AppUser user;

  const ProfileHeaderCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: AppRadius.xl,
        boxShadow: AppShadow.elevated(isDark),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              user.initial,
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
          AppSpacing.vMd,
          Text(
            user.displayName ?? 'User',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          AppSpacing.vXs,
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: AppRadius.pill,
            ),
            child: Text(
              user.role.name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ),
          AppSpacing.vSm,
          Text(
            user.email,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(
            begin: 0.1, end: 0, duration: 500.ms, curve: AppCurve.enter);
  }
}
