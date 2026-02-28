import 'package:flutter/material.dart';
import '../config/design_tokens.dart';

/// A widget that smoothly animates between a loading placeholder and content.
///
/// Wraps [AnimatedSwitcher] with sensible defaults for shimmer→content
/// transitions. Uses [ValueKey] based on [loading] to trigger the switch.
class LoadingSwitcher extends StatelessWidget {
  final bool loading;
  final Widget loadingChild;
  final Widget child;
  final Duration duration;

  const LoadingSwitcher({
    super.key,
    required this.loading,
    required this.loadingChild,
    required this.child,
  }) : duration = AppDuration.normal;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppCurve.enter,
      switchOutCurve: AppCurve.exit,
      child: loading
          ? KeyedSubtree(key: const ValueKey('loading'), child: loadingChild)
          : KeyedSubtree(key: const ValueKey('content'), child: child),
    );
  }
}
