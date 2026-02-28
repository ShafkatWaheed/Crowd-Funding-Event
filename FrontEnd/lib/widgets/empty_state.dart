import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';
import '../config/design_tokens.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: AppSpacing.huge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.accentSurfaceOf(context),
                shape: BoxShape.circle,
                boxShadow: AppShadow.soft(isDark),
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: AppTheme.accentColor.withValues(alpha: 0.7),
              ),
            )
                .animate()
                .fadeIn(duration: AppDuration.normal)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  duration: AppDuration.normal,
                  curve: AppCurve.overshoot,
                ),
            AppSpacing.vXxl,
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ).animate(delay: 100.ms).fadeIn(duration: AppDuration.normal),
            if (subtitle != null) ...[
              AppSpacing.vSm,
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                  height: 1.5,
                ),
              ).animate(delay: 200.ms).fadeIn(duration: AppDuration.normal),
            ],
            if (actionLabel != null && onAction != null) ...[
              AppSpacing.vXxl,
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ).animate(delay: 300.ms).fadeIn(duration: AppDuration.normal),
            ],
          ],
        ),
      ),
    );
  }
}
