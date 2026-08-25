import 'package:flutter/material.dart';

/// Defines a complete color palette for a single theme variant.
///
/// Every visual token the app needs lives here. Derived (alpha-blended)
/// colours are computed as getters so palettes stay compact.
class ThemePalette {
  const ThemePalette({
    required this.id,
    required this.name,
    required this.primary,
    required this.onPrimary,
    required this.primaryHover,
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.border,
    required this.ring,
    required this.onSurfaceHint,
    required this.surfaceHover,
    required this.icon,
    required this.iconMuted,
    required this.destructive,
    required this.destructiveForeground,
    required this.success,
    required this.successForeground,
    required this.warning,
    required this.warningForeground,
  });

  final String id;
  final String name;
  final Color primary;
  final Color onPrimary;
  final Color primaryHover;
  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color border;
  final Color ring;
  final Color onSurfaceHint;
  final Color surfaceHover;
  final Color icon;
  final Color iconMuted;
  final Color destructive;
  final Color destructiveForeground;
  final Color success;
  final Color successForeground;
  final Color warning;
  final Color warningForeground;

  // ── Derived decorative colours ──────────────────────────────────────────
  Color get primarySoft => primary.withValues(alpha: 0.15);
  Color get primarySoftBorder => primary.withValues(alpha: 0.30);
  Color get primarySoftStrong => primary.withValues(alpha: 0.50);
  Color get destructiveSoft => destructive.withValues(alpha: 0.15);
  Color get successSoft => success.withValues(alpha: 0.15);
  Color get successSoftBorder => success.withValues(alpha: 0.30);
  Color get warningSoft => warning.withValues(alpha: 0.15);
  Color get warningSoftBorder => warning.withValues(alpha: 0.30);
  Color get gold => const Color(0xFFFFC107);
  Color get feltGlow => primary.withValues(alpha: 0.04);
  Color get glassOverlay => const Color(0x99000000);
  Color get hairlineWhite => const Color(0x33FFFFFF);
  Color get hairlineBorder => border.withValues(alpha: 0.30);
  Color get blackGlow => const Color(0x99000000);
  Color get feltGlowStrong => primary.withValues(alpha: 0.20);
  Color get shadowDark => const Color(0x99000000);
  Color get shadowDeep => Colors.black;
  Color get shadowSoft => const Color(0x40000000);
  Color get black => Colors.black;

  // ── Avatar palette ──────────────────────────────────────────────────────
  List<Color> get avatarPalette => [
    primary,
    card,
    secondary,
    primary.withValues(alpha: 0.7),
    const Color(0xFF424242),
    const Color(0xFF455A64),
  ];

  Color avatarColorFor(String name) {
    if (name.isEmpty) return avatarPalette.first;
    return avatarPalette[name.codeUnitAt(0) % avatarPalette.length];
  }

  // ── Gradient helpers ────────────────────────────────────────────────────
  LinearGradient get shimmerGradient => LinearGradient(
    colors: [primary, primaryHover, primary, primary],
    stops: const [0.0, 0.4, 0.6, 1.0],
  );

  RadialGradient get luxuryGradient => RadialGradient(
    center: Alignment.topRight,
    radius: 1.6,
    colors: [primary.withValues(alpha: 0.20), Colors.transparent],
  );

  RadialGradient get feltBackground => RadialGradient(
    center: const Alignment(0, 0.7),
    radius: 1.4,
    colors: [primary.withValues(alpha: 0.30), background],
  );
}

/// Provides the six available theme palettes and a lookup helper.
class ThemePalettes {
  ThemePalettes._();

  static const String defaultId = 'red';

  static const List<ThemePalette> all = [
    red,
    crimsonGlass,
    darkYellow,
    cosmicAi,
    darkOrange,
  ];

  static ThemePalette forId(String id) {
    return all.firstWhere((p) => p.id == id, orElse: () => red);
  }

  // ── 1. Red (default) ────────────────────────────────────────────────────
  static const red = ThemePalette(
    id: 'red',
    name: 'Red',
    primary: Color(0xFFB71C1C),
    onPrimary: Color(0xFFFFFFFF),
    primaryHover: Color(0xFFD32F2F),
    background: Color(0xFF000000),
    foreground: Color(0xFFFFFFFF),
    card: Color(0xFF111111),
    cardForeground: Color(0xFFFFFFFF),
    secondary: Color(0xFF222222),
    secondaryForeground: Color(0xFFE4E4E7),
    muted: Color(0xFF1A1A1A),
    mutedForeground: Color(0xFFA1A1AA),
    accent: Color(0xFFB71C1C),
    accentForeground: Color(0xFFFFFFFF),
    border: Color(0xFF333333),
    ring: Color(0xFFB71C1C),
    onSurfaceHint: Color(0xFF71717A),
    surfaceHover: Color(0xFF27272A),
    icon: Color(0xFFE57373),
    iconMuted: Color(0xFFEF9A9A),
    destructive: Color(0xFFE53935),
    destructiveForeground: Color(0xFFFFFFFF),
    success: Color(0xFF2E7D32),
    successForeground: Color(0xFFFFFFFF),
    warning: Color(0xFFE65100),
    warningForeground: Color(0xFFFFFFFF),
  );

  // ── 2. Crimson Glass — Luxury / Gaming ────────────────────────────────
  static const crimsonGlass = ThemePalette(
    id: 'crimson-glass',
    name: 'Crimson Glass',
    primary: Color(0xFFDC143C),
    onPrimary: Color(0xFFFFFFFF),
    primaryHover: Color(0xFFFF1744),
    background: Color(0xFF050505),
    foreground: Color(0xFFFFFFFF),
    card: Color(0xBF1E1E1E),        // rgba(30,30,30,0.75) — glassmorphism
    cardForeground: Color(0xFFFFFFFF),
    secondary: Color(0x0DFFFFFF),    // rgba(255,255,255,0.05) — frosted surface
    secondaryForeground: Color(0xFFA1A1AA),
    muted: Color(0x0DFFFFFF),       // rgba(255,255,255,0.05)
    mutedForeground: Color(0xFFA1A1AA),
    accent: Color(0xFFFF1744),
    accentForeground: Color(0xFFFFFFFF),
    border: Color(0x1AFFFFFF),      // rgba(255,255,255,0.10) — glass edge
    ring: Color(0xFFDC143C),
    onSurfaceHint: Color(0xFF71717A),
    surfaceHover: Color(0x14FFFFFF), // rgba(255,255,255,0.08)
    icon: Color(0xFFFF6B6B),
    iconMuted: Color(0xFFFF9999),
    destructive: Color(0xFFE53935),
    destructiveForeground: Color(0xFFFFFFFF),
    success: Color(0xFF2E7D32),
    successForeground: Color(0xFFFFFFFF),
    warning: Color(0xFFE65100),
    warningForeground: Color(0xFFFFFFFF),
  );

  // ── 3. Dark Yellow ──────────────────────────────────────────────────────
  static const darkYellow = ThemePalette(
    id: 'dark-yellow',
    name: 'Dark Yellow',
    primary: Color(0xFFF9A825),
    onPrimary: Color(0xFF1A1400),
    primaryHover: Color(0xFFFFC107),
    background: Color(0xFF080600),
    foreground: Color(0xFFEFEEE8),
    card: Color(0xFF161200),
    cardForeground: Color(0xFFEFEEE8),
    secondary: Color(0xFF242000),
    secondaryForeground: Color(0xFFD4D0C8),
    muted: Color(0xFF120F00),
    mutedForeground: Color(0xFF9E9480),
    accent: Color(0xFFF9A825),
    accentForeground: Color(0xFF1A1400),
    border: Color(0xFF383000),
    ring: Color(0xFFF9A825),
    onSurfaceHint: Color(0xFF6B6350),
    surfaceHover: Color(0xFF2A2400),
    icon: Color(0xFFFFD54F),
    iconMuted: Color(0xFFFFE082),
    destructive: Color(0xFFE53935),
    destructiveForeground: Color(0xFFFFFFFF),
    success: Color(0xFF2E7D32),
    successForeground: Color(0xFFFFFFFF),
    warning: Color(0xFFE65100),
    warningForeground: Color(0xFFFFFFFF),
  );

  // ── 4. Cosmic AI — Blue + Cyan + Purple ───────────────────────────────
  static const cosmicAi = ThemePalette(
    id: 'cosmic-ai',
    name: 'Cosmic AI',
    primary: Color(0xFF3B82F6),       // blue
    onPrimary: Color(0xFFFFFFFF),
    primaryHover: Color(0xFF60A5FA),
    background: Color(0xFF030712),    // near-black
    foreground: Color(0xFFF9FAFB),
    card: Color(0xFF0F172A),          // slate-900
    cardForeground: Color(0xFFF9FAFB),
    secondary: Color(0xFF0F172A),     // slate-900
    secondaryForeground: Color(0xFFCBD5E1),
    muted: Color(0xFF1E293B),         // slate-800
    mutedForeground: Color(0xFF94A3B8),
    accent: Color(0xFF8B5CF6),        // purple
    accentForeground: Color(0xFFFFFFFF),
    border: Color(0xFF1E293B),        // slate-800
    ring: Color(0xFF3B82F6),
    onSurfaceHint: Color(0xFF64748B),
    surfaceHover: Color(0xFF1E293B),
    icon: Color(0xFF06B6D4),          // cyan
    iconMuted: Color(0xFF22D3EE),
    destructive: Color(0xFFE53935),
    destructiveForeground: Color(0xFFFFFFFF),
    success: Color(0xFF2E7D32),
    successForeground: Color(0xFFFFFFFF),
    warning: Color(0xFFE65100),
    warningForeground: Color(0xFFFFFFFF),
  );

  // ── 5. Dark Orange ──────────────────────────────────────────────────────
  static const darkOrange = ThemePalette(
    id: 'dark-orange',
    name: 'Dark Orange',
    primary: Color(0xFFFF6D00),
    onPrimary: Color(0xFFFFFFFF),
    primaryHover: Color(0xFFFF9100),
    background: Color(0xFF080300),
    foreground: Color(0xFFF0ECEA),
    card: Color(0xFF180E04),
    cardForeground: Color(0xFFF0ECEA),
    secondary: Color(0xFF281A08),
    secondaryForeground: Color(0xFFD8C8B0),
    muted: Color(0xFF120A02),
    mutedForeground: Color(0xFFA0886E),
    accent: Color(0xFFFF6D00),
    accentForeground: Color(0xFFFFFFFF),
    border: Color(0xFF3C2810),
    ring: Color(0xFFFF6D00),
    onSurfaceHint: Color(0xFF6E5A42),
    surfaceHover: Color(0xFF301E0A),
    icon: Color(0xFFFFAB40),
    iconMuted: Color(0xFFFFCC80),
    destructive: Color(0xFFE53935),
    destructiveForeground: Color(0xFFFFFFFF),
    success: Color(0xFF2E7D32),
    successForeground: Color(0xFFFFFFFF),
    warning: Color(0xFFE65100),
    warningForeground: Color(0xFFFFFFFF),
  );
}
