import 'package:flutter/material.dart';

import '../../../config/theme.dart';

class CreateEventStepIndicator extends StatelessWidget {
  final List<String> stepLabels;
  final List<IconData> stepIcons;
  final int currentStep;
  final Set<int> stepsWithErrors;
  final ValueChanged<int> onGoToStep;

  const CreateEventStepIndicator({
    super.key,
    required this.stepLabels,
    required this.stepIcons,
    required this.currentStep,
    required this.stepsWithErrors,
    required this.onGoToStep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        border: Border(bottom: BorderSide(color: AppTheme.dividerOf(context))),
      ),
      child: Row(
        children: List.generate(stepLabels.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepBefore = i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                color: stepBefore < currentStep
                    ? AppTheme.accentColor
                    : AppTheme.dividerOf(context),
              ),
            );
          }
          final step = i ~/ 2;
          return _buildStepDot(context, step);
        }),
      ),
    );
  }

  Widget _buildStepDot(BuildContext context, int step) {
    final isCompleted = step < currentStep;
    final isCurrent = step == currentStep;
    final hasError = stepsWithErrors.contains(step);
    final canTap = step < currentStep;

    return GestureDetector(
      onTap: canTap ? () => onGoToStep(step) : null,
      child: Opacity(
        opacity: step > currentStep ? 0.45 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: isCurrent ? 32 : 26,
                  height: isCurrent ? 32 : 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasError
                        ? AppTheme.errorColor
                        : isCompleted || isCurrent
                            ? AppTheme.accentColor
                            : AppTheme.surfaceOf(context),
                    border: Border.all(
                      color: hasError
                          ? AppTheme.errorColor
                          : isCompleted || isCurrent
                              ? AppTheme.accentColor
                              : AppTheme.dividerOf(context),
                      width: isCurrent ? 2.5 : 1.5,
                    ),
                  ),
                  child: Center(
                    child: hasError
                        ? const Icon(Icons.priority_high, size: 14, color: Colors.white)
                        : isCompleted
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Icon(
                                stepIcons[step],
                                size: isCurrent ? 16 : 13,
                                color: isCurrent
                                    ? Colors.white
                                    : AppTheme.textSecondaryOf(context),
                              ),
                  ),
                ),
                if (hasError)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.cardOf(context), width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              stepLabels[step],
              style: TextStyle(
                fontSize: 9,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: hasError
                    ? AppTheme.errorColor
                    : isCurrent
                        ? AppTheme.accentColor
                        : isCompleted
                            ? AppTheme.textPrimaryOf(context)
                            : AppTheme.textSecondaryOf(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
