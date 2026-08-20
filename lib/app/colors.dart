import 'package:flutter/material.dart';

/// Centralized color palette for the Poker Night app.
///
/// Mirrors the `@theme` block in the original web UI's `index.css`.
/// Do not hardcode colors inside widgets — reference these instead.
class AppColors {
  AppColors._();

  // ── Base tokens ────────────────────────────────────────────────────────────
  static const Color background = Color(0xFF000000); // Pure black
  static const Color foreground = Color(0xFFFFFFFF); // Pure white
  static const Color card = Color(0xFF111111);
  static const Color cardForeground = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFFB71C1C); // Dark red
  static const Color primaryForeground = Color(0xFFFFFFFF);
  static const Color primaryHover = Color(0xFFD32F2F);
  static const Color secondary = Color(0xFF222222);
  static const Color secondaryForeground = Color(0xFFE4E4E7);
  static const Color muted = Color(0xFF1A1A1A);
  static const Color mutedForeground = Color(0xFFA1A1AA);
  static const Color accent = Color(0xFFB71C1C);
  static const Color accentForeground = Color(0xFFFFFFFF);
  static const Color border = Color(0xFF333333);
  static const Color ring = Color(0xFFB71C1C);
  static const Color destructive = Color(0xFFE53935);
  static const Color destructiveForeground = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF2E7D32);
  static const Color successForeground = Color(0xFFFFFFFF);
  static const Color warning = Color(0xFFE65100);
  static const Color warningForeground = Color(0xFFFFFFFF);

  // ── Derived decorative colors used by specific components ─────────────────
  static const Color black = Color(0xFF000000);
  static const Color onSurfaceHint = Color(0xFF71717A);
  static const Color surfaceHover = Color(0xFF27272A);
  static const Color primarySoft = Color(0x26B71C1C);
  static const Color primarySoftBorder = Color(0x4DB71C1C);
  static const Color primarySoftStrong = Color(0x80B71C1C);
  static const Color destructiveSoft = Color(0x26E53935);
  static const Color successSoft = Color(0x262E7D32);
  static const Color successSoftBorder = Color(0x4D2E7D32);
  static const Color warningSoft = Color(0x26E65100);
  static const Color warningSoftBorder = Color(0x4DE65100);
  static const Color gold = Color(0xFFFFC107);
  static const Color feltGlow = Color(0xFF220505);
  static const Color glassOverlay = Color(0x99000000);

  // ── Icons ──────────────────────────────────────────────────────────────────
  /// Solid icons rendered across the app use this light red so they stay
  /// legible on the near-black surfaces while keeping the casino theme.
  static const Color icon = Color(0xFFE57373); // Light red (Material Red 300)
  static const Color iconMuted = Color(0xFFEF9A9A); // Softer light red

  // ── Low-level alpha variants ──
  static const Color hairlineWhite = Color(0x33FFFFFF);
  static const Color hairlineBorder = Color(0x4D333333);
  static const Color blackGlow = Color(0x99000000);
  static const Color feltGlowStrong = Color(0xCC220505);
  static const Color shadowDark = Color(0x99000000);
  static const Color shadowDeep = Color(0xFF000000);
  static const Color shadowSoft = Color(0x40000000);

  static const List<Color> avatarPalette = [
    Color(0xFFB71C1C),
    Color(0xFF212121),
    Color(0xFF37474F),
    Color(0xFFC62828),
    Color(0xFF424242),
    Color(0xFF455A64),
  ];

  static Color avatarColorFor(String name) {
    if (name.isEmpty) return avatarPalette.first;
    return avatarPalette[name.codeUnitAt(0) % avatarPalette.length];
  }

  // ── Gradient helpers ───────────────────────────────────────────────────────
  static const LinearGradient crimsonShimmer = LinearGradient(
    colors: [
      Color(0xFFB71C1C),
      Color(0xFFE53935),
      Color(0xFFB71C1C),
      Color(0xFFB71C1C),
    ],
    stops: [0.0, 0.4, 0.6, 1.0],
  );

  static const RadialGradient luxuryGradient = RadialGradient(
    center: Alignment.topRight,
    radius: 1.6,
    colors: [Color(0x33B71C1C), Color(0x00000000)],
  );

  static const RadialGradient feltBackground = RadialGradient(
    center: Alignment(0, 0.7),
    radius: 1.4,
    colors: [Color(0x4D4A0B0B), Color(0xFF000000)],
  );
}
