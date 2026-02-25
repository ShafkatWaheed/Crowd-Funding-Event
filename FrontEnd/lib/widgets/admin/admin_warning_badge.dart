import 'package:flutter/material.dart';

import '../../config/theme.dart';

class AdminWarningBadge extends StatelessWidget {
  const AdminWarningBadge({
    super.key,
    required this.count,
    this.compact = false,
  });

  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    final warn = AppTheme.warningOf(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: warn.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: compact ? 12 : 14,
            color: warn,
          ),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: warn,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminWarningList extends StatelessWidget {
  const AdminWarningList({super.key, required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();

    final warn = AppTheme.warningOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: warnings.map((w) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: warn,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  w,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
