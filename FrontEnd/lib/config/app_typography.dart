import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  AppTypography — single source of truth for all text styles
//
//  Two-font pairing:
//    • Plus Jakarta Sans — display, headline, title, app bar
//      Expressive geometric with strong personality at large sizes
//    • Inter — body, labels, buttons, inputs, nav, chips
//      Neutral, highly legible at small sizes
//
//  Every style is color-neutral; apply color with .copyWith(color: ...).
//  Only this file imports google_fonts.
//
//  Usage:
//    AppTypography.titleMedium.copyWith(color: AppTheme.textPrimaryOf(ctx))
//    AppTypography.bodySmall    ← use directly when color doesn't matter
// ═══════════════════════════════════════════════════════════════════════════

abstract class AppTypography {
  /// Display/heading font — expressive, premium feel at large sizes
  static const String displayFontFamily = 'Plus Jakarta Sans';

  /// Body/UI font — neutral, highly legible at small sizes
  static const String bodyFontFamily = 'Inter';

  // ─── Display  (Plus Jakarta Sans) ─────────────────────────────────────────

  static TextStyle get displayLarge =>
      GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.5, height: 1.12);

  static TextStyle get displayMedium =>
      GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1.0, height: 1.18);

  static TextStyle get displaySmall =>
      GoogleFonts.plusJakartaSans(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -2.0, height: 1.08);

  // ─── Headline  (Plus Jakarta Sans) ────────────────────────────────────────

  static TextStyle get headlineLarge =>
      GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.25);

  static TextStyle get headlineMedium =>
      GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.30);

  static TextStyle get headlineSmall =>
      GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, height: 1.30);

  // ─── Title  (Plus Jakarta Sans) ───────────────────────────────────────────

  static TextStyle get titleLarge =>
      GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700);

  static TextStyle get titleMedium =>
      GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600);

  static TextStyle get titleSmall =>
      GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600);

  // ─── Body  (Inter) ────────────────────────────────────────────────────────

  static TextStyle get bodyLarge =>
      GoogleFonts.inter(fontSize: 16, height: 1.6);

  static TextStyle get bodyMedium =>
      GoogleFonts.inter(fontSize: 14, height: 1.6);

  static TextStyle get bodySmall =>
      GoogleFonts.inter(fontSize: 12, height: 1.5);

  // ─── Label  (Inter) ───────────────────────────────────────────────────────

  static TextStyle get labelLarge =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600);

  static TextStyle get labelMedium =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5);

  static TextStyle get labelSmall =>
      GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0);

  /// 13px Inter medium — detail labels, chip text, secondary metadata
  static TextStyle get caption =>
      GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4);

  /// 10px Inter bold — status badges and tight pill labels
  static TextStyle get badge =>
      GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5);

  // ─── Component overrides  (Inter) ─────────────────────────────────────────
  // App bar, buttons, input fields, navigation rail, chips

  static TextStyle get appBarTitle =>
      GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5);

  static TextStyle get buttonLarge =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600);

  static TextStyle get buttonMedium =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600);

  static TextStyle get inputHint =>
      GoogleFonts.inter(fontSize: 14);

  static TextStyle get navRailSelected =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600);

  static TextStyle get navRailDefault =>
      GoogleFonts.inter(fontSize: 12);

  static TextStyle get chip =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500);

  static TextStyle get segmentedButton =>
      GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600);
}
