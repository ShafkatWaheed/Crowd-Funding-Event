import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../config/design_tokens.dart';

class AnimatedStatCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final int value;
  final String? suffix;
  final Color? accentColor;
  final Duration animationDuration;

  const AnimatedStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.suffix,
    this.accentColor,
    this.animationDuration = const Duration(milliseconds: 800),
  });

  @override
  State<AnimatedStatCard> createState() => _AnimatedStatCardState();
}

class _AnimatedStatCardState extends State<AnimatedStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _countAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _countAnim = Tween<double>(begin: 0, end: widget.value.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: AppCurve.decelerate),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedStatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _countAnim = Tween<double>(
        begin: oldWidget.value.toDouble(),
        end: widget.value.toDouble(),
      ).animate(
        CurvedAnimation(parent: _controller, curve: AppCurve.decelerate),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final accent = widget.accentColor ?? AppTheme.accentColor;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: AppRadius.lg,
        boxShadow: AppShadow.soft(isDark),
        border: Border.all(
          color: AppTheme.dividerOf(context),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: AppRadius.md,
            ),
            child: Icon(widget.icon, size: AppIconSize.md, color: accent),
          ),
          AppSpacing.vMd,
          AnimatedBuilder(
            animation: _countAnim,
            builder: (context, _) {
              final display = _countAnim.value.round().toString();
              return Text(
                widget.suffix != null ? '$display${widget.suffix}' : display,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              );
            },
          ),
          AppSpacing.vXs,
          Text(
            widget.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}
