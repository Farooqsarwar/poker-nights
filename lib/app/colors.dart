import 'package:flutter/material.dart';

import '../theme/theme_palette.dart';

/// Centralized colour accessors for the Poker Night app.
///
/// All colours are derived from the active [ThemePalette]. The palette is
/// swapped by [AppProvider] on theme change; every widget that reads
/// `AppColors.xxx` gets the correct themed value automatically after the
/// framework rebuilds the tree.
class AppColors {
  AppColors._();

  /// Replaces the active palette.  Called by [PokerNightApp] before building
  /// the [MaterialApp] so the new values are in place before any descendant
  /// reads them.
  static ThemePalette currentPalette = ThemePalettes.red;

  // ── Base tokens ────────────────────────────────────────────────────────────
  static Color get background => currentPalette.background;
  static Color get foreground => currentPalette.foreground;
  static Color get card => currentPalette.card;
  static Color get cardForeground => currentPalette.cardForeground;
  static Color get primary => currentPalette.primary;
  static Color get primaryForeground => currentPalette.onPrimary;
  static Color get primaryHover => currentPalette.primaryHover;
  static Color get secondary => currentPalette.secondary;
  static Color get secondaryForeground => currentPalette.secondaryForeground;
  static Color get muted => currentPalette.muted;
  static Color get mutedForeground => currentPalette.mutedForeground;
  static Color get accent => currentPalette.accent;
  static Color get accentForeground => currentPalette.accentForeground;
  static Color get border => currentPalette.border;
  static Color get ring => currentPalette.ring;
  static Color get destructive => currentPalette.destructive;
  static Color get destructiveForeground => currentPalette.destructiveForeground;
  static Color get success => currentPalette.success;
  static Color get successForeground => currentPalette.successForeground;
  static Color get warning => currentPalette.warning;
  static Color get warningForeground => currentPalette.warningForeground;

  // ── Derived decorative colours ─────────────────────────────────────────────
  static Color get black => Colors.black;
  static Color get onSurfaceHint => currentPalette.onSurfaceHint;
  static Color get surfaceHover => currentPalette.surfaceHover;
  static Color get primarySoft => currentPalette.primarySoft;
  static Color get primarySoftBorder => currentPalette.primarySoftBorder;
  static Color get primarySoftStrong => currentPalette.primarySoftStrong;
  static Color get destructiveSoft => currentPalette.destructiveSoft;
  static Color get successSoft => currentPalette.successSoft;
  static Color get successSoftBorder => currentPalette.successSoftBorder;
  static Color get warningSoft => currentPalette.warningSoft;
  static Color get warningSoftBorder => currentPalette.warningSoftBorder;
  static Color get gold => currentPalette.gold;
  static Color get feltGlow => currentPalette.feltGlow;
  static Color get glassOverlay => currentPalette.glassOverlay;
  static Color get hairlineWhite => currentPalette.hairlineWhite;
  static Color get hairlineBorder => currentPalette.hairlineBorder;
  static Color get blackGlow => currentPalette.blackGlow;
  static Color get feltGlowStrong => currentPalette.feltGlowStrong;
  static Color get shadowDark => currentPalette.shadowDark;
  static Color get shadowDeep => currentPalette.shadowDeep;
  static Color get shadowSoft => currentPalette.shadowSoft;

  // ── Icons ──────────────────────────────────────────────────────────────────
  static Color get icon => currentPalette.icon;
  static Color get iconMuted => currentPalette.iconMuted;

  // ── Avatar ─────────────────────────────────────────────────────────────────
  static List<Color> get avatarPalette => currentPalette.avatarPalette;
  static Color avatarColorFor(String name) => currentPalette.avatarColorFor(name);

  // ── Gradient helpers ───────────────────────────────────────────────────────
  static LinearGradient get crimsonShimmer => currentPalette.shimmerGradient;
  static RadialGradient get luxuryGradient => currentPalette.luxuryGradient;
  static RadialGradient get feltBackground => currentPalette.feltBackground;
}
