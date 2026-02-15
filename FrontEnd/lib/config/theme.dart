import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Shared brand colours (constant, mode-agnostic) ───
  static const Color accentColor = Color(0xFF276EF1);        // Uber blue
  static const Color secondaryColor = Color(0xFF05944F);     // Uber green
  static const Color errorColor = Color(0xFFE11900);         // Uber red
  static const Color successColor = Color(0xFF05944F);       // Green
  static const Color warningColor = Color(0xFFFFC043);       // Uber amber

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
  // Use these inside build() methods so colours adapt automatically.
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _dkCard,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  // ─── Shared builders (avoid duplication) ───

  static TextTheme _textTheme(ThemeData base, Color primary, Color secondary) {
    return GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: primary, letterSpacing: -1),
      displayMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: primary, letterSpacing: -0.5),
      headlineLarge: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: primary),
      headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: primary),
      titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: primary),
      titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
      titleSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      bodyLarge: GoogleFonts.inter(fontSize: 16, color: primary),
      bodyMedium: GoogleFonts.inter(fontSize: 14, color: primary),
      bodySmall: GoogleFonts.inter(fontSize: 12, color: secondary),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
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
      iconTheme: IconThemeData(color: fg, size: 22),
    );
  }

  static CardTheme _cardTheme(Color color) {
    return CardTheme(
      elevation: 0,
      color: color,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    );
  }

  static InputDecorationTheme _inputTheme(Color fill, Color border, Color focus, Color hint) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: focus, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: GoogleFonts.inter(color: hint, fontSize: 14),
      labelStyle: GoogleFonts.inter(color: hint, fontSize: 14),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(Color bg) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: bg == accentColor ? Colors.white : Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(Color fg, Color border) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }
}
