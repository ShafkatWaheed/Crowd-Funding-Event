import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_typography.dart';
import 'design_tokens.dart';

class AppTheme {
  // ─── Shared brand colours (constant, mode-agnostic) ───
  static const Color accentColor = Color(0xFF276EF1);        // Uber blue
  static const Color secondaryColor = Color(0xFF05944F);     // Uber green
  static const Color errorColor = Color(0xFFE11900);         // Uber red
  static const Color successColor = Color(0xFF05944F);       // Green
  static const Color warningColor = Color(0xFFFFC043);       // Uber amber

  // ─── Extended vibrant brand palette (from combined_design.html) ───
  static const Color purpleColor  = Color(0xFF9333EA);   // --pu  (VIP/premium)
  static const Color orangeColor  = Color(0xFFFF8C00);   // --ora (pledge base)
  static const Color magentaColor = Color(0xFFC026D3);   // --donate
  static const Color cyanColor    = Color(0xFF0891B2);   // selling_tickets, refund_processing
  static const Color tealColor    = Color(0xFF0D9488);   // education genre
  static const Color slateColor   = Color(0xFF475569);   // business genre
  static const Color yellowColor  = Color(0xFFEAB308);   // under_review

  // ─── Tinted surfaces for vibrant colours (light mode) ───
  static const Color purpleSurface  = Color(0xFFF5F0FF);
  static const Color orangeSurface  = Color(0xFFFFF3E0);
  static const Color magentaSurface = Color(0xFFFCF0FF);

  // ─── Tinted surfaces for vibrant colours (dark mode) ───
  static const Color _dkPurpleSurface  = Color(0xFF1E1028);
  static const Color _dkOrangeSurface  = Color(0xFF2A1E08);
  static const Color _dkMagentaSurface = Color(0xFF2A0E28);

  // ─── Gradient accents ───
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF276EF1), Color(0xFF5B8DEF)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF05944F), Color(0xFF34D399)],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE11900), Color(0xFFFF6B4A)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
  );

  /// Amber pledge gradient — `#FF8C00 → #FFC043` (matches combined_design.html).
  static const LinearGradient pledgeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8C00), Color(0xFFFFC043)],
  );

  /// Purple–magenta donate gradient.
  static const LinearGradient donateGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9333EA), Color(0xFFC026D3)],
  );

  // ─── Third-party brand colours (social media) ───
  static const Color brandInstagram = Color(0xFFE1306C);
  static const Color brandFacebook  = Color(0xFF1877F2);
  static const Color brandLinkedIn  = Color(0xFF0A66C2);
  static const Color brandYouTube   = Color(0xFFFF0000);
  static const Color brandIndigo    = Color(0xFF4F46E5);

  // ─── Medal colours (leaderboards) ───
  static const Color medalGold   = Color(0xFFD4A017);
  static const Color medalSilver = Color(0xFF9E9E9E);
  static const Color medalBronze = Color(0xFFCD7F32);

  // ─── Auth screen gradient ───
  static LinearGradient authGradient(bool isDark) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: isDark
        ? [const Color(0xFF0A0A1A), const Color(0xFF121228)]
        : [const Color(0xFFF0F4FF), const Color(0xFFF8FAFF)],
  );

  // ─── Social/contact section header gradient ───
  static LinearGradient socialHeaderGradient(bool isDark) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: isDark
        ? [const Color(0xFF1A1035), const Color(0xFF0D1B3E)]
        : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
  );

  /// Purple funding CTA gradient (deep → mid → vivid purple).
  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purpleColor, purpleColor, purpleColor],
  );

  // ─── Tinted surface colours (light mode) ───
  static const Color accentSurface  = Color(0xFFF0F4FF);  // blue tint
  static const Color successSurface = Color(0xFFECFDF3);   // green tint
  static const Color warningSurface = Color(0xFFFFF8E1);   // amber tint
  static const Color errorSurface   = Color(0xFFFFF0EE);   // red tint

  // ─── Tinted surface colours (dark mode) ───
  static const Color _dkAccentSurface  = Color(0xFF1A2340);
  static const Color _dkSuccessSurface = Color(0xFF0D2818);
  static const Color _dkWarningSurface = Color(0xFF2A2210);
  static const Color _dkErrorSurface   = Color(0xFF2A1210);

  // ─── Light palette ───
  static const Color primaryColor = Color(0xFF000000);       // Uber black
  static const Color surfaceColor = Color(0xFFF6F6F6);       // Light grey bg
  static const Color darkSurface = Color(0xFF141414);        // Near-black
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF141414);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color dividerColor = Color(0xFFE2E2E2);
  static const Color shimmer = Color(0xFFEEEEEE);

  // ─── Dark palette ───
  static const Color _dkPrimary = Color(0xFFFFFFFF);
  static const Color _dkSurface = Color(0xFF121212);
  static const Color _dkCard = Color(0xFF1E1E1E);
  static const Color _dkTextPrimary = Color(0xFFEAEAEA);
  static const Color _dkTextSecondary = Color(0xFF9E9E9E);
  static const Color _dkDivider = Color(0xFF2C2C2C);
  static const Color _dkShimmer = Color(0xFF2A2A2A);
  static const Color _dkInputFill = Color(0xFF252525);

  // ─── Context-aware helpers ───
  static Color primaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dkPrimary : primaryColor;

  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dkSurface : surfaceColor;

  static Color cardOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dkCard : cardColor;

  static Color textPrimaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dkTextPrimary : textPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dkTextSecondary : textSecondary;

  static Color dividerOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dkDivider : dividerColor;

  static Color shimmerOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dkShimmer : shimmer;

  static Color shimmerHighlightOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF3A3A3A)
          : const Color(0xFFF5F5F5);

  static Color inputFillOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dkInputFill : Colors.white;

  static Color accentSurfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dkAccentSurface : accentSurface;

  static Color successSurfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dkSuccessSurface : successSurface;

  static Color warningSurfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dkWarningSurface : warningSurface;

  static Color errorSurfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dkErrorSurface : errorSurface;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Option-A glow header decoration — single source of truth.
  /// Dark: near-black base with colour radiating from top-left corner.
  /// Light: very pale pastel tint base with softer colour glow.
  static BoxDecoration glowHeaderDecoration({
    required Color color,
    required bool isDark,
    BorderRadius? borderRadius,
  }) {
    // LinearGradient top-left → bottom-right reliably covers the full header
    // regardless of dimensions. Both stops fully opaque so the glow is vivid.
    final Color glowStop, base;
    if (isDark) {
      base = const Color(0xFF0A0A0A);
      glowStop = Color.lerp(base, color, 0.88)!;
    } else {
      base = Color.lerp(color, Colors.white, 0.86)!;
      glowStop = Color.lerp(base, color, 0.65)!;
    }
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [glowStop, base, base],
        stops: const [0.0, 0.55, 1.0],
      ),
      borderRadius: borderRadius,
    );
  }

  /// Foreground colours to use on top of [glowHeaderDecoration].
  static Color glowHeaderTitle(bool isDark) =>
      isDark ? Colors.white : textPrimary;
  static Color glowHeaderSubtitle(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.6) : textSecondary;
  static Color glowHeaderIconBox(Color color, bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.12) : color.withValues(alpha: 0.12);
  static Color glowHeaderBadgeBg(Color color, bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.18) : color.withValues(alpha: 0.10);
  static Color glowHeaderBadgeBorder(Color color, bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.35) : color.withValues(alpha: 0.28);
  static Color glowHeaderBadgeText(Color color, bool isDark) =>
      isDark ? Colors.white : color;

  // ─── Frosted-glass neutral tokens (chip/button backgrounds) ───
  /// Semi-transparent neutral background — works on any card surface.
  static Color frostedBg(bool isDark, {double darkAlpha = 0.08, double lightAlpha = 0.06}) =>
      isDark ? Colors.white.withValues(alpha: darkAlpha) : Colors.black.withValues(alpha: lightAlpha);

  /// Primary foreground (text + icon) on a frosted-glass surface.
  static Color frostedFg(bool isDark) => isDark ? Colors.white : Colors.black87;

  /// Secondary / subdued foreground on a frosted-glass surface.
  static Color frostedFgSub(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.45);

  /// Foreground colour to place on a solid coloured chip/button.
  /// Returns white or near-black depending on the background luminance.
  static Color onColor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.light
          ? Colors.black87
          : Colors.white;

  /// Returns the [bg, label] pair for an active filter chip.
  /// Light colours are darkened just enough so white text is always legible,
  /// keeping chip labels visually consistent regardless of the chip's hue.
  static (Color bg, Color label) chipActive(Color color) {
    final bg = ThemeData.estimateBrightnessForColor(color) == Brightness.light
        ? Color.lerp(color, Colors.black, 0.28)!
        : color;
    return (bg, Colors.white);
  }

  // ─── Vibrant colour surfaces (context-aware) ───
  static Color purpleSurfaceOf(BuildContext context) =>
      isDark(context) ? _dkPurpleSurface : purpleSurface;
  static Color orangeSurfaceOf(BuildContext context) =>
      isDark(context) ? _dkOrangeSurface : orangeSurface;
  static Color magentaSurfaceOf(BuildContext context) =>
      isDark(context) ? _dkMagentaSurface : magentaSurface;

  // ─── Brand colours – dark-mode–aware variants ───
  static Color accentOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF5B8DEF) : accentColor;

  static Color successOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF66BB6A) : successColor;

  static Color errorOf(BuildContext context) =>
      isDark(context) ? const Color(0xFFEF5350) : errorColor;

  static Color warningOf(BuildContext context) =>
      isDark(context) ? const Color(0xFFFFB74D) : warningColor;

  // ──────────────────────── LIGHT THEME ────────────────────────
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: surfaceColor,
    );

    return base.copyWith(
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        error: errorColor,
        surface: cardColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      textTheme: _textTheme(base, textPrimary, textSecondary),
      appBarTheme: _appBarTheme(Colors.white, textPrimary),
      cardTheme: _cardTheme(cardColor),
      inputDecorationTheme: _inputTheme(Colors.white, dividerColor, primaryColor, textSecondary),
      elevatedButtonTheme: _elevatedButtonTheme(primaryColor),
      outlinedButtonTheme: _outlinedButtonTheme(primaryColor, dividerColor),
      textButtonTheme: _textButtonTheme(),
      floatingActionButtonTheme: _fabTheme(primaryColor),
      bottomNavigationBarTheme: _bottomNavTheme(Colors.white, primaryColor, textSecondary),
      dividerTheme: DividerThemeData(color: dividerColor, thickness: 1, space: 0),
      chipTheme: _chipTheme(surfaceColor, primaryColor, textPrimary, Colors.white),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? primaryColor : Colors.white),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? Colors.white : textPrimary),
          side: WidgetStatePropertyAll(BorderSide(color: dividerColor)),
          textStyle: WidgetStatePropertyAll(AppTypography.segmentedButton),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        selectedIconTheme: IconThemeData(color: primaryColor),
        unselectedIconTheme: IconThemeData(color: textSecondary),
        selectedLabelTextStyle: AppTypography.navRailSelected.copyWith(color: primaryColor),
        unselectedLabelTextStyle: AppTypography.navRailDefault.copyWith(color: textSecondary),
        indicatorColor: accentColor.withValues(alpha: 0.12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xl),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  // ──────────────────────── DARK THEME ────────────────────────
  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _dkSurface,
    );

    return base.copyWith(
      colorScheme: ColorScheme.dark(
        primary: _dkPrimary,
        secondary: accentColor,
        error: errorColor,
        surface: _dkCard,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: _dkTextPrimary,
      ),
      textTheme: _textTheme(base, _dkTextPrimary, _dkTextSecondary),
      appBarTheme: _appBarTheme(_dkCard, _dkTextPrimary),
      cardTheme: _cardTheme(_dkCard),
      inputDecorationTheme: _inputTheme(_dkInputFill, _dkDivider, accentColor, _dkTextSecondary),
      elevatedButtonTheme: _elevatedButtonTheme(accentColor),
      outlinedButtonTheme: _outlinedButtonTheme(_dkTextPrimary, _dkDivider),
      textButtonTheme: _textButtonTheme(),
      floatingActionButtonTheme: _fabTheme(accentColor),
      bottomNavigationBarTheme: _bottomNavTheme(_dkCard, accentColor, _dkTextSecondary),
      dividerTheme: DividerThemeData(color: _dkDivider, thickness: 1, space: 0),
      chipTheme: _chipTheme(const Color(0xFF252525), accentColor, _dkTextPrimary, Colors.white),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? accentColor : _dkCard),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? Colors.white : _dkTextPrimary),
          side: WidgetStatePropertyAll(BorderSide(color: _dkDivider)),
          textStyle: WidgetStatePropertyAll(AppTypography.segmentedButton),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _dkCard,
        selectedIconTheme: IconThemeData(color: accentColor),
        unselectedIconTheme: IconThemeData(color: _dkTextSecondary),
        selectedLabelTextStyle: AppTypography.navRailSelected.copyWith(color: accentColor),
        unselectedLabelTextStyle: AppTypography.navRailDefault.copyWith(color: _dkTextSecondary),
        indicatorColor: accentColor.withValues(alpha: 0.15),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _dkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xl),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _dkCard,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  // ─── Shared builders ───

  static TextTheme _textTheme(ThemeData base, Color primary, Color secondary) {
    return GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge:   AppTypography.displayLarge.copyWith(color: primary),
      displayMedium:  AppTypography.displayMedium.copyWith(color: primary),
      displaySmall:   AppTypography.displaySmall.copyWith(color: primary),
      headlineLarge:  AppTypography.headlineLarge.copyWith(color: primary),
      headlineMedium: AppTypography.headlineMedium.copyWith(color: primary),
      headlineSmall:  AppTypography.headlineSmall.copyWith(color: primary),
      titleLarge:     AppTypography.titleLarge.copyWith(color: primary),
      titleMedium:    AppTypography.titleMedium.copyWith(color: primary),
      titleSmall:     AppTypography.titleSmall.copyWith(color: primary),
      bodyLarge:      AppTypography.bodyLarge.copyWith(color: primary),
      bodyMedium:     AppTypography.bodyMedium.copyWith(color: primary),
      bodySmall:      AppTypography.bodySmall.copyWith(color: secondary),
      labelLarge:     AppTypography.labelLarge.copyWith(color: primary),
      labelMedium:    AppTypography.labelMedium.copyWith(color: primary),
      labelSmall:     AppTypography.labelSmall.copyWith(color: secondary),
    );
  }

  static AppBarTheme _appBarTheme(Color bg, Color fg) {
    return AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AppTypography.appBarTitle.copyWith(color: fg),
      iconTheme: IconThemeData(color: fg, size: AppIconSize.lg),
    );
  }

  static CardThemeData _cardTheme(Color color) {
    return CardThemeData(
      elevation: 0,
      color: color,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
      margin: EdgeInsets.zero,
    );
  }

  static InputDecorationTheme _inputTheme(Color fill, Color border, Color focus, Color hint) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(borderRadius: AppRadius.md, borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: AppRadius.md, borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: AppRadius.md, borderSide: BorderSide(color: focus, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
      hintStyle: AppTypography.inputHint.copyWith(color: hint),
      labelStyle: AppTypography.inputHint.copyWith(color: hint),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(Color bg) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: AppSpacing.lg),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
        textStyle: AppTypography.buttonLarge,
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(Color fg, Color border) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
        textStyle: AppTypography.buttonMedium,
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentColor,
        textStyle: AppTypography.buttonMedium,
      ),
    );
  }

  static FloatingActionButtonThemeData _fabTheme(Color bg) {
    return FloatingActionButtonThemeData(
      backgroundColor: bg,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
    );
  }

  static BottomNavigationBarThemeData _bottomNavTheme(Color bg, Color selected, Color unselected) {
    return BottomNavigationBarThemeData(
      backgroundColor: bg,
      selectedItemColor: selected,
      unselectedItemColor: unselected,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
    );
  }

  static ChipThemeData _chipTheme(Color bg, Color selected, Color labelColor, Color selectedLabelColor) {
    return ChipThemeData(
      backgroundColor: bg,
      selectedColor: selected,
      secondarySelectedColor: selected,
      labelStyle: AppTypography.chip.copyWith(color: labelColor),
      secondaryLabelStyle: AppTypography.chip.copyWith(color: selectedLabelColor),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      showCheckmark: true,
      checkmarkColor: selectedLabelColor,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  AppColors — context-aware semantic colours for dark/light mode
// ═══════════════════════════════════════════════════════════════════════════

extension AppColors on BuildContext {
  bool get _dk => Theme.of(this).brightness == Brightness.dark;

  // ─── Vibrant extended palette (purple / orange / magenta) ───
  Color get purpleAccent   => _dk ? const Color(0xFFBB86FC) : AppTheme.purpleColor;
  Color get orangeAccent   => _dk ? const Color(0xFFFFB74D) : AppTheme.orangeColor;
  Color get magentaAccent  => _dk ? const Color(0xFFE040FB) : AppTheme.magentaColor;
  Color get purpleSurface  => _dk ? AppTheme._dkPurpleSurface  : AppTheme.purpleSurface;
  Color get orangeSurface  => _dk ? AppTheme._dkOrangeSurface  : AppTheme.orangeSurface;
  Color get magentaSurface => _dk ? AppTheme._dkMagentaSurface : AppTheme.magentaSurface;

  // ─── Section accent colours (icons, titles, buttons in themed sections) ───
  Color get ticketAccent    => _dk ? const Color(0xFF4DB6AC) : Colors.teal;
  Color get fundingAccent   => _dk ? const Color(0xFFFFB74D) : Colors.orange;
  Color get sponsorAccent   => _dk ? const Color(0xFFB39DDB) : Colors.deepPurple;
  Color get managementAccent => _dk ? const Color(0xFF7986CB) : Colors.indigo;
  Color get photoAccent     => _dk ? const Color(0xFFFFE57F) : Colors.amber.shade500;
  Color get scheduleAccent  => _dk ? const Color(0xFF81C784) : Colors.green;
  Color get discountAccent  => _dk ? const Color(0xFFEF5350) : Colors.red;
  Color get reviewAccent    => _dk ? const Color(0xFFFFD54F) : Colors.amber;
  Color get feedAccent      => _dk ? const Color(0xFF90CAF9) : Colors.blue;

  // ─── Section surface tints (light background behind section cards) ───
  Color get ticketSurface     => _dk ? const Color(0xFF1A2E2B) : Colors.teal.withValues(alpha: 0.06);
  Color get fundingSurface    => _dk ? const Color(0xFF2E2A1A) : Colors.orange.withValues(alpha: 0.06);
  Color get sponsorSurface    => _dk ? const Color(0xFF251A2E) : Colors.deepPurple.withValues(alpha: 0.06);
  Color get managementSurface => _dk ? const Color(0xFF1A1F2E) : Colors.indigo.withValues(alpha: 0.06);
  Color get scheduleSurface   => _dk ? const Color(0xFF1A2E1A) : Colors.green.withValues(alpha: 0.06);

  // ─── Status colours — 4 semantic groups ───
  Color get statusDraft      => _dk ? const Color(0xFF9E9E9E) : const Color(0xFF6B6B6B);  // inactive
  Color get statusPending    => _dk ? const Color(0xFFFFB74D) : const Color(0xFFD4940A);  // attention
  Color get statusApproved   => _dk ? const Color(0xFF5B8DEF) : const Color(0xFF276EF1);  // active
  Color get statusLive       => _dk ? const Color(0xFF5B8DEF) : const Color(0xFF276EF1);  // active
  Color get statusSelling    => _dk ? const Color(0xFF5B8DEF) : const Color(0xFF276EF1);  // active
  Color get statusWaiting    => _dk ? const Color(0xFFFFB74D) : const Color(0xFFD4940A);  // attention
  Color get statusCompleted  => _dk ? const Color(0xFF9E9E9E) : const Color(0xFF6B6B6B);  // inactive
  Color get statusCancelled  => _dk ? const Color(0xFFEF5350) : const Color(0xFFE11900);  // negative

  // ─── Trust score colours ───
  Color get trustHigh   => _dk ? const Color(0xFF66BB6A) : const Color(0xFF05944F);
  Color get trustMedium => _dk ? const Color(0xFFFFB74D) : Colors.orange;
  Color get trustLow    => _dk ? const Color(0xFFEF5350) : Colors.red;

  // ─── Bid status colours ───
  Color get bidAccepted => _dk ? const Color(0xFF66BB6A) : Colors.green.shade600;
  Color get bidPaid     => _dk ? const Color(0xFF42A5F5) : Colors.blue.shade600;
  Color get bidPending  => _dk ? const Color(0xFFFFB74D) : Colors.orange.shade700;
  Color get bidRejected => _dk ? const Color(0xFFEF5350) : Colors.red.shade600;

  // ─── Misc semantic colours ───
  Color get onDarkSurface   => Colors.white;
  Color get overlayScrim    => Colors.black54;
  Color get cardGradientStart => _dk ? const Color(0xFF1B1B2F) : const Color(0xFF1B1B2F);
  Color get cardGradientEnd   => _dk ? const Color(0xFF162447) : const Color(0xFF162447);
}
