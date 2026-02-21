import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../config/design_tokens.dart';

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool isScrollControlled = true,
  double? maxHeightFraction,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final content = builder(ctx);
      return _AppBottomSheetWrapper(
        maxHeightFraction: maxHeightFraction ?? 0.9,
        child: content,
      );
    },
  );
}

class _AppBottomSheetWrapper extends StatelessWidget {
  final Widget child;
  final double maxHeightFraction;
  const _AppBottomSheetWrapper({
    required this.child,
    required this.maxHeightFraction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * maxHeightFraction,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: AppRadius.topXxl,
        boxShadow: AppShadow.elevated(isDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DragHandle(),
          Flexible(child: child),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.dividerOf(context),
            borderRadius: AppRadius.pill,
          ),
        ),
      ),
    );
  }
}
