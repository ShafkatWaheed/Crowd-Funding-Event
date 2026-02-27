import 'package:flutter/material.dart';

import '../../../config/theme.dart';

class CreateEventBottomNav extends StatelessWidget {
  final int currentStep;
  final int stepCount;
  final List<String> stepLabels;
  final bool isLoading;
  final bool publish;
  final VoidCallback onPrevStep;
  final VoidCallback onNextStep;
  final VoidCallback onSubmit;

  const CreateEventBottomNav({
    super.key,
    required this.currentStep,
    required this.stepCount,
    required this.stepLabels,
    required this.isLoading,
    required this.publish,
    required this.onPrevStep,
    required this.onNextStep,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentStep == stepCount - 1;
    final isFirst = currentStep == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (!isFirst) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPrevStep,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppTheme.dividerOf(context)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: isLast ? _buildSubmitButton(context) : _buildNextButton(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onSubmit,
      icon: isLoading
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.check_circle_rounded, size: 18),
      label: Text(isLoading
          ? 'Creating...'
          : publish
              ? 'Create & Publish'
              : 'Save as Draft'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: publish ? AppTheme.accentColor : AppTheme.textSecondaryOf(context),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  Widget _buildNextButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onNextStep,
      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
      label: Text(currentStep < stepCount - 1
          ? 'Next: ${stepLabels[currentStep + 1]}'
          : 'Next'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: AppTheme.accentColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }
}
