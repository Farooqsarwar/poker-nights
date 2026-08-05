import 'package:flutter/material.dart';

/// Centralized color palette for the Poker Night app.
///
/// Mirrors the `@theme` block in the original web UI's `index.css`.
/// Do not hardcode colors inside widgets — reference these instead.
class AppColors {
  AppColors._();

  // ── Base tokens ────────────────────────────────────────────────────────────
  static const Color background = Color(0xFF050505);
  static const Color foreground = Color(0xFFF4F4F5);
  static const Color card = Color(0xFF0A0A0A);
  static const Color cardForeground = Color(0xFFF4F4F5);
  static const Color primary = Color(0xFF7F1D1D);
  static const Color primaryForeground = Color(0xFFFFFFFF);
  static const Color primaryHover = Color(0xFF991B1B);
  static const Color secondary = Color(0xFF171717);
  static const Color secondaryForeground = Color(0xFFE4E4E7);
  static const Color muted = Color(0xFF1A1616);
  static const Color mutedForeground = Color(0xFFA1A1AA);
  static const Color accent = Color(0xFF651313);
  static const Color accentForeground = Color(0xFFF4F4F5);
  static const Color border = Color(0xFF27272A);
  static const Color ring = Color(0xFF7F1D1D);
  static const Color destructive = Color(0xFF991B1B);
  static const Color destructiveForeground = Color(0xFFF4F4F5);
  static const Color success = Color(0xFF166534);
  static const Color successForeground = Color(0xFFF4F4F5);
  static const Color warning = Color(0xFF9A3412);
  static const Color warningForeground = Color(0xFFF4F4F5);

  // ── Derived decorative colors used by specific components ─────────────────
  static const Color black = Color(0xFF000000); // TV / code-entry backgrounds
  static const Color onSurfaceHint = Color(0xFF52525B); // input placeholder
  static const Color surfaceHover = Color(0xFF1F1F23); // hover overlay (white 5%)
  static const Color primarySoft = Color(0x1A7F1D1D); // primary / 10
  static const Color primarySoftBorder = Color(0x337F1D1D); // primary / 20
  static const Color primarySoftStrong = Color(0x527F1D1D); // primary / 40
  static const Color destructiveSoft = Color(0x1A991B1B); // destructive / 10
  static const Color successSoft = Color(0x1A166534); // success / 10
  static const Color successSoftBorder = Color(0x33166534); // success / 20
  static const Color warningSoft = Color(0x1A9A3412); // warning / 10
  static const Color warningSoftBorder = Color(0x339A3412); // warning / 30
  static const Color gold = Color(0xFFC9940D); // winner border accent
  static const Color feltGlow = Color(0xFF1E0A0A);
  static const Color glassOverlay = Color(0x990A0A0A); // card / 60

  // ── Low-level alpha variants (avoid raw Color(0x…) literals in widgets) ──
  static const Color hairlineWhite = Color(0x66FFFFFF); // white / 40 section divider
  static const Color hairlineBorder = Color(0x4D27272A); // border / 30 row divider
  static const Color blackGlow = Color(0x66050505); // black / 40 felt vignette
  static const Color feltGlowStrong = Color(0xCC1E0A0A); // feltGlow / 80 TV glow
  static const Color shadowDark = Color(0x66000000); // black / 40 drop shadow
  static const Color shadowDeep = Color(0xCC000000); // black / 80 text shadow
  static const Color shadowSoft = Color(0x33000000); // black / 20 subtle shadow

  /// Avatar background hues — derived deterministically from the name.
  static const List<Color> avatarPalette = [
    Color(0xFF450A0A), // red-950
    Color(0xFF262626), // neutral-800
    Color(0xFF1C1917), // stone-800
    Color(0xFF7F1D1D), // red-900
    Color(0xFF18181B), // zinc-800
    Color(0xFF1F2937), // gray-800
  ];

  static Color avatarColorFor(String name) {
    if (name.isEmpty) return avatarPalette.first;
    return avatarPalette[name.codeUnitAt(0) % avatarPalette.length];
  }

  // ── Gradient helpers ───────────────────────────────────────────────────────
  static const LinearGradient crimsonShimmer = LinearGradient(
    colors: [
      Color(0xFF7F1D1D),
      Color(0xFF991B1B),
      Color(0xFF7F1D1D),
      Color(0xFF651313),
    ],
    stops: [0.0, 0.4, 0.6, 1.0],
  );

  static const RadialGradient luxuryGradient = RadialGradient(
    center: Alignment.topRight,
    radius: 1.6,
    colors: [
      Color(0x267F1D1D),
      Color(0x00000000),
    ],
  );

  static const RadialGradient feltBackground = RadialGradient(
    center: Alignment(0, 0.7),
    radius: 1.4,
    colors: [
      Color(0x66301E1E),
      Color(0xFF050505),
    ],
  );
}
