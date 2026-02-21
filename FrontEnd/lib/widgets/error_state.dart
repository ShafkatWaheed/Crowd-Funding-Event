import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../config/design_tokens.dart';

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  const ErrorState({
    super.key,
    this.message = 'Something went wrong. Please try again.',
    this.onRetry,
    this.retryLabel = 'Retry',
    this.icon = Icons.error_outline_rounded,
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
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.errorSurfaceOf(context),
                shape: BoxShape.circle,
                boxShadow: AppShadow.soft(isDark),
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppTheme.errorColor.withValues(alpha: 0.7),
              ),
            ),
            AppSpacing.vXxl,
            Text(
              'Oops!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            AppSpacing.vSm,
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryOf(context),
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              AppSpacing.vXxl,
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: AppIconSize.md),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
