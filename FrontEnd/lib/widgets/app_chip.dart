import 'package:flutter/material.dart';
import '../config/theme.dart';

/// A standardised filter/sort chip that routes all active-state styling through
/// [AppTheme.chipActive]. This is the single source of truth for chip colours
/// across the app — update here to change every chip at once.
///
/// Usage:
/// ```dart
/// AppChip(
///   label: 'Purchased',
///   selected: _filter == 'purchased',
///   onSelected: (_) => setState(() => _filter = 'purchased'),
///   chipColor: AppIcons.ticketStatusColor('purchased', isDark: isDark),
///   avatarIcon: Icons.check_circle_rounded,
/// )
/// ```
class AppChip extends StatelessWidget {
  /// The display text.
  final String label;

  /// Whether this chip is currently selected.
  final bool selected;

  /// Called when the user taps the chip.
  final ValueChanged<bool> onSelected;

  /// The semantic colour for this chip (accent, status, genre, etc.).
  /// [AppTheme.chipActive] will darken light colours automatically so that
  /// white label text is always readable.
  final Color chipColor;

  /// Optional leading icon. Coloured with [activeLabel] when selected,
  /// [chipColor] when inactive.
  final IconData? avatarIcon;

  /// Label font size. Defaults to 13.
  final double fontSize;

  /// When true, applies [VisualDensity.compact] and
  /// [MaterialTapTargetSize.shrinkWrap] for dense chip rows.
  final bool compact;

  /// Background colour when inactive. Defaults to [AppTheme.cardOf(context)].
  final Color? bgColor;

  /// Border when inactive. Defaults to [AppTheme.dividerOf(context)].
  /// Pass [BorderSide.none] for borderless chips.
  final BorderSide? inactiveSide;

  /// Optional chip shape override (e.g. fully-rounded pill).
  final OutlinedBorder? shape;

  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.chipColor,
    this.avatarIcon,
    this.fontSize = 13,
    this.compact = false,
    this.bgColor,
    this.inactiveSide,
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    final (activeBg, activeLabel) = AppTheme.chipActive(chipColor);
    final inactiveBg = bgColor ?? AppTheme.cardOf(context);
    final BorderSide resolvedSide = selected
        ? BorderSide(color: activeBg)
        : (inactiveSide ?? BorderSide(color: AppTheme.dividerOf(context)));

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      avatar: avatarIcon != null
          ? Icon(avatarIcon, size: 14,
              color: selected ? activeLabel : chipColor)
          : null,
      color: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? activeBg : inactiveBg),
      side: resolvedSide,
      shape: shape,
      labelStyle: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: selected ? activeLabel : AppTheme.textPrimaryOf(context),
      ),
      materialTapTargetSize: compact
          ? MaterialTapTargetSize.shrinkWrap
          : MaterialTapTargetSize.padded,
      visualDensity:
          compact ? VisualDensity.compact : VisualDensity.standard,
    );
  }
}
