import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../config/theme.dart';
import '../../config/design_tokens.dart';

class ProfileSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final int delay;

  const ProfileSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: AppRadius.lg,
          boxShadow: AppShadow.soft(isDark),
          border: Border.all(
            color: AppTheme.dividerOf(context).withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: AppIconSize.md, color: AppTheme.accentColor),
                AppSpacing.hSm,
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondaryOf(context),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            AppSpacing.vLg,
            ...children,
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: delay))
        .fadeIn(duration: 400.ms)
        .slideY(
            begin: 0.08, end: 0, duration: 400.ms, curve: AppCurve.enter);
  }
}

InputDecoration profileFieldDecoration(
  BuildContext context, {
  required String label,
  required IconData icon,
  String? hint,
  Widget? suffix,
  bool readOnly = false,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, size: AppIconSize.md),
    suffixIcon: suffix,
    filled: true,
    fillColor: readOnly
        ? AppTheme.surfaceOf(context).withValues(alpha: 0.5)
        : AppTheme.inputFillOf(context),
    border: OutlineInputBorder(
      borderRadius: AppRadius.md,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.md,
      borderSide: BorderSide(color: AppTheme.dividerOf(context), width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.md,
      borderSide: const BorderSide(color: AppTheme.accentColor, width: 1.5),
    ),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
  );
}
