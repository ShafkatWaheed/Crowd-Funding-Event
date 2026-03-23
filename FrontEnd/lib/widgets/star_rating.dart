import 'package:flutter/material.dart';
import '../config/theme.dart';

class StarRating extends StatelessWidget {
  final int rating;
  final ValueChanged<int>? onChanged;
  final double size;

  const StarRating({super.key, required this.rating, this.onChanged, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return GestureDetector(
          onTap: onChanged != null ? () => onChanged!(i + 1) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
              color: i < rating ? AppTheme.warningColor : AppTheme.textSecondaryOf(context),
              size: size,
            ),
          ),
        );
      }),
    );
  }
}

class StarRatingDisplay extends StatelessWidget {
  final double? avgStars;
  final int count;
  final double size;

  const StarRatingDisplay({super.key, this.avgStars, required this.count, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final stars = avgStars ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          if (i < stars.floor()) {
            return Icon(Icons.star_rounded, color: AppTheme.warningColor, size: size);
          } else if (i < stars.ceil() && stars % 1 >= 0.3) {
            return Icon(Icons.star_half_rounded, color: AppTheme.warningColor, size: size);
          }
          return Icon(Icons.star_outline_rounded, color: AppTheme.warningColor.withValues(alpha: 0.4), size: size);
        }),
        const SizedBox(width: 6),
        Text(
          avgStars != null ? avgStars!.toStringAsFixed(1) : '—',
          style: TextStyle(
            fontSize: size * 0.8,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '($count)',
          style: TextStyle(
            fontSize: size * 0.65,
            color: AppTheme.textSecondaryOf(context),
          ),
        ),
      ],
    );
  }
}
