import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Uber-inspired palette ───
  static const Color primaryColor = Color(0xFF000000);       // Uber black
  static const Color accentColor = Color(0xFF276EF1);        // Uber blue
  static const Color secondaryColor = Color(0xFF05944F);     // Uber green
  static const Color errorColor = Color(0xFFE11900);         // Uber red
  static const Color successColor = Color(0xFF05944F);       // Green
  static const Color warningColor = Color(0xFFFFC043);       // Uber amber
  static const Color surfaceColor = Color(0xFFF6F6F6);       // Light grey
  static const Color darkSurface = Color(0xFF141414);        // Near-black
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF141414);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color dividerColor = Color(0xFFE2E2E2);
  static const Color shimmer = Color(0xFFEEEEEE);

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
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
            fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -1),
        displayMedium: GoogleFonts.inter(
            fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5),
        headlineLarge: GoogleFonts.inter(
            fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
        headlineMedium: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
        titleLarge: GoogleFonts.inter(
            fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
        titleMedium: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        titleSmall: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: textPrimary),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: textSecondary),
        labelLarge: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: textPrimary, size: 22),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: dividerColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        selectedColor: primaryColor,
        secondarySelectedColor: primaryColor,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}
