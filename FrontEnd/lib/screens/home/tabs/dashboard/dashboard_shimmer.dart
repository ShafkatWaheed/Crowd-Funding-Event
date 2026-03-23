import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../config/design_tokens.dart';
import '../../../../config/theme.dart';

class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          AppSpacing.vLg,
          Row(
            children: [
              Expanded(child: shimmerBox(context, height: 110)),
              AppSpacing.hMd,
              Expanded(child: shimmerBox(context, height: 110)),
            ],
          ),
          AppSpacing.vMd,
          Row(
            children: [
              Expanded(child: shimmerBox(context, height: 110)),
              AppSpacing.hMd,
              Expanded(child: shimmerBox(context, height: 110)),
            ],
          ),
          AppSpacing.vXl,
          shimmerBox(context, height: 40),
          AppSpacing.vXl,
          shimmerBox(context, height: 200),
          AppSpacing.vXl,
          shimmerBox(context, height: 180),
        ],
      ),
    );
  }
}

Widget shimmerBox(BuildContext context, {required double height}) {
  final isDark = AppTheme.isDark(context);
  return Container(
    height: height,
    decoration: BoxDecoration(
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.06),
      borderRadius: AppRadius.lg,
    ),
  )
      .animate(onPlay: (c) => c.repeat())
      .shimmer(
          duration: 1200.ms,
          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.6));
}
