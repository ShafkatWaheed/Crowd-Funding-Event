import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'design_tokens.dart';

class AppTheme {
  // ─── Shared brand colours (constant, mode-agnostic) ───
  static const Color accentColor = Color(0xFF276EF1);        // Uber blue
  static const Color secondaryColor = Color(0xFF05944F);     // Uber green
  static const Color errorColor = Color(0xFFE11900);         // Uber red
  static const Color successColor = Color(0xFF05944F);       // Green
  static const Color warningColor = Color(0xFFFFC043);       // Uber amber

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
      chipTheme: _chipTheme(surfaceColor, primaryColor),
      dialogTheme: DialogTheme(
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
      chipTheme: _chipTheme(const Color(0xFF252525), accentColor),
      dialogTheme: DialogTheme(
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
      displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: primary, letterSpacing: -1, height: 1.15),
      displayMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: primary, letterSpacing: -0.5, height: 1.2),
      displaySmall: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w900, color: primary, letterSpacing: -1.5, height: 1.1),
      headlineLarge: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: primary, height: 1.25),
      headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: primary, height: 1.3),
      headlineSmall: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: primary, height: 1.3),
      titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: primary),
      titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
      titleSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      bodyLarge: GoogleFonts.inter(fontSize: 16, color: primary, height: 1.5),
      bodyMedium: GoogleFonts.inter(fontSize: 14, color: primary, height: 1.5),
      bodySmall: GoogleFonts.inter(fontSize: 12, color: secondary, height: 1.4),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: primary, letterSpacing: 0.5),
      labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: secondary, letterSpacing: 1.0),
    );
  }

  static AppBarTheme _appBarTheme(Color bg, Color fg) {
    return AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: fg, letterSpacing: -0.5),
      iconTheme: IconThemeData(color: fg, size: AppIconSize.lg),
    );
  }

  static CardTheme _cardTheme(Color color) {
    return CardTheme(
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
      hintStyle: GoogleFonts.inter(color: hint, fontSize: 14),
      labelStyle: GoogleFonts.inter(color: hint, fontSize: 14),
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
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
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
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentColor,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
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

  static ChipThemeData _chipTheme(Color bg, Color selected) {
    return ChipThemeData(
      backgroundColor: bg,
      selectedColor: selected,
      secondarySelectedColor: selected,
      labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  AppColors — context-aware semantic colours for dark/light mode
// ═══════════════════════════════════════════════════════════════════════════

extension AppColors on BuildContext {
  bool get _dk => Theme.of(this).brightness == Brightness.dark;

  // ─── Section accent colours (icons, titles, buttons in themed sections) ───
  Color get ticketAccent    => _dk ? const Color(0xFF4DB6AC) : Colors.teal;
  Color get fundingAccent   => _dk ? const Color(0xFFFFB74D) : Colors.orange;
  Color get sponsorAccent   => _dk ? const Color(0xFFB39DDB) : Colors.deepPurple;
  Color get managementAccent => _dk ? const Color(0xFF7986CB) : Colors.indigo;
  Color get photoAccent     => _dk ? const Color(0xFFFFD54F) : Colors.amber.shade700;
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

  // ─── Status colours (pills, badges, lifecycle indicators) ───
  Color get statusDraft      => _dk ? const Color(0xFF9E9E9E) : const Color(0xFF757575);
  Color get statusPending    => _dk ? const Color(0xFFFFB74D) : const Color(0xFFE65100);
  Color get statusApproved   => _dk ? const Color(0xFF66BB6A) : const Color(0xFF05944F);
  Color get statusLive       => _dk ? const Color(0xFF42A5F5) : const Color(0xFF276EF1);
  Color get statusSelling    => _dk ? const Color(0xFF4DB6AC) : const Color(0xFF00838F);
  Color get statusWaiting    => _dk ? const Color(0xFFFFB74D) : const Color(0xFFE65100);
  Color get statusCompleted  => _dk ? const Color(0xFF9E9E9E) : const Color(0xFF424242);
  Color get statusCancelled  => _dk ? const Color(0xFFEF5350) : const Color(0xFF8B0000);

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
