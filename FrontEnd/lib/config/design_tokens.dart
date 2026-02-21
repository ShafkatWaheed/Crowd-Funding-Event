import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  SPACING — 4px base unit, 8px grid
// ═══════════════════════════════════════════════════════════════════════════

class AppSpacing {
  AppSpacing._();

  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double xxl  = 24;
  static const double xxxl = 32;
  static const double huge = 40;

  static const EdgeInsets paddingSm  = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd  = EdgeInsets.all(md);
  static const EdgeInsets paddingLg  = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl  = EdgeInsets.all(xl);
  static const EdgeInsets paddingXxl = EdgeInsets.all(xxl);

  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: xl);

  static const SizedBox vXs   = SizedBox(height: xs);
  static const SizedBox vSm   = SizedBox(height: sm);
  static const SizedBox vMd   = SizedBox(height: md);
  static const SizedBox vLg   = SizedBox(height: lg);
  static const SizedBox vXl   = SizedBox(height: xl);
  static const SizedBox vXxl  = SizedBox(height: xxl);
  static const SizedBox vXxxl = SizedBox(height: xxxl);

  static const SizedBox hXs   = SizedBox(width: xs);
  static const SizedBox hSm   = SizedBox(width: sm);
  static const SizedBox hMd   = SizedBox(width: md);
  static const SizedBox hLg   = SizedBox(width: lg);
  static const SizedBox hXl   = SizedBox(width: xl);
}

// ═══════════════════════════════════════════════════════════════════════════
//  BORDER RADIUS — standardised across the app
// ═══════════════════════════════════════════════════════════════════════════

class AppRadius {
  AppRadius._();

  static const double smValue   = 8;
  static const double mdValue   = 12;
  static const double lgValue   = 16;
  static const double xlValue   = 20;
  static const double xxlValue  = 24;
  static const double pillValue = 100;

  static final BorderRadius sm   = BorderRadius.circular(smValue);
  static final BorderRadius md   = BorderRadius.circular(mdValue);
  static final BorderRadius lg   = BorderRadius.circular(lgValue);
  static final BorderRadius xl   = BorderRadius.circular(xlValue);
  static final BorderRadius xxl  = BorderRadius.circular(xxlValue);
  static final BorderRadius pill = BorderRadius.circular(pillValue);

  static final BorderRadius topLg  = BorderRadius.only(
    topLeft: Radius.circular(lgValue),
    topRight: Radius.circular(lgValue),
  );
  static final BorderRadius topXl  = BorderRadius.only(
    topLeft: Radius.circular(xlValue),
    topRight: Radius.circular(xlValue),
  );
  static final BorderRadius topXxl = BorderRadius.only(
    topLeft: Radius.circular(xxlValue),
    topRight: Radius.circular(xxlValue),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHADOWS — two tiers, dark-mode aware
// ═══════════════════════════════════════════════════════════════════════════

class AppShadow {
  AppShadow._();

  static List<BoxShadow> card(bool isDark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> cardHover(bool isDark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.07),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> elevated(bool isDark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> bottomBar(bool isDark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
      blurRadius: 20,
      offset: const Offset(0, -4),
    ),
  ];

  static List<BoxShadow> soft(bool isDark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
      blurRadius: 8,
      offset: const Offset(0, 1),
    ),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════
//  ANIMATION DURATIONS & CURVES
// ═══════════════════════════════════════════════════════════════════════════

class AppDuration {
  AppDuration._();

  static const Duration fast   = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow   = Duration(milliseconds: 500);
  static const Duration splash = Duration(milliseconds: 800);
}

class AppCurve {
  AppCurve._();

  static const Curve standard   = Curves.easeInOut;
  static const Curve decelerate = Curves.decelerate;
  static const Curve spring     = Curves.elasticOut;
  static const Curve overshoot  = Curves.easeOutBack;
  static const Curve enter      = Curves.easeOutCubic;
  static const Curve exit       = Curves.easeInCubic;
}

// ═══════════════════════════════════════════════════════════════════════════
//  ICON SIZES — consistent across the app
// ═══════════════════════════════════════════════════════════════════════════

class AppIconSize {
  AppIconSize._();

  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 28;
  static const double xxl = 32;
}
