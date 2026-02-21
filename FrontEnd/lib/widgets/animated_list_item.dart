import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/design_tokens.dart';

class AnimatedListItem extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration staggerDelay;
  final Duration duration;
  final double slideOffset;

  const AnimatedListItem({
    super.key,
    required this.child,
    this.index = 0,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 400),
    this.slideOffset = 20,
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate(delay: staggerDelay * index)
        .fadeIn(duration: duration, curve: AppCurve.enter)
        .slideY(
          begin: slideOffset / 100,
          end: 0,
          duration: duration,
          curve: AppCurve.enter,
        );
  }
}
