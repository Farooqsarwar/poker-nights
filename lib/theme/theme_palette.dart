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

  // ── Text-safe variants of the semantic colours ──────────────────────────
  //
  // The base semantic colours are tuned as FILLS, and they are correct for
  // that: white on `primary` measures 6.6:1, exactly what a button wants.
  // Used as TEXT on a dark surface the same colour measures 2.6:1 — far under
  // the 4.5:1 AA floor — which is why links ("Forgot Password?", "Back to
  // Sign In"), status lines and coloured labels were hard to read against the
  // card. A fill colour and a text colour are different jobs; these are the
  // text job.
  //
  // Lifting toward white rather than hardcoding per palette means every
  // theme — red, crimson, yellow, cosmic, orange — gets a correct variant
  // from its own hue instead of five hand-tuned constants that drift apart.
  // 0.40 is the point the default red clears AA on both card and background
  // (5.4:1 and 6.7:1) while still reading as red rather than pink.
  static const double _textLift = 0.40;
  Color get primaryText => Color.lerp(primary, Colors.white, _textLift)!;
  Color get destructiveText =>
      Color.lerp(destructive, Colors.white, _textLift)!;
  Color get successText => Color.lerp(success, Colors.white, _textLift)!;
  Color get warningText => Color.lerp(warning, Colors.white, _textLift)!;

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

  /// The redesign's soft accent bloom falling from the top edge of a
  /// full-screen page (onboarding, join and guest screens).
  RadialGradient get topGlow => RadialGradient(
    center: const Alignment(0, -1.15),
    radius: 1.1,
    colors: [primary.withValues(alpha: 0.14), primary.withValues(alpha: 0.0)],
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
    // The three hexes below are the only colours the client's product system
    // ("PokerNightTools — Product System") actually declares: ground #0A0A0A,
    // accent/action #D53032, ink #FFFFFF. They were previously B71C1C on pure
    // black — eyeballed, and noticeably darker and more muted than the spec.
    // Everything else in this palette is ours and stays as tuned below.
    primary: Color(0xFFD53032),
    onPrimary: Color(0xFFFFFFFF),
    // Not in the spec. The old D32F2F is now within a hair of the accent
    // itself, so hover would read as no change at all; this is a ~7% lightness
    // step up from D53032, the smallest lift that is visibly a hover state.
    primaryHover: Color(0xFFE24446),
    background: Color(0xFF0A0A0A),
    foreground: Color(0xFFFFFFFF),
    // Surfaces and borders are deliberately left exactly as they were. The
    // near-black card on a black page IS the look; an earlier attempt to lift
    // it — and then the border — to force separation made the whole UI read
    // grey and flat, which was worse than the problem it solved.
    //
    // The contrast the screens genuinely needed goes entirely into the TEXT
    // tokens below. Note that what actually made buttons look washed out was
    // never the surfaces at all: BoxDecoration silently drops `color` when a
    // `gradient` is present, so every filled button was painting only its
    // sheen (fixed in widgets/app_button.dart).
    card: Color(0xFF111111),
    cardForeground: Color(0xFFFFFFFF),
    secondary: Color(0xFF222222),
    secondaryForeground: Color(0xFFEDEDF0),
    muted: Color(0xFF1A1A1A),
    // Was A1A1AA (7.4:1 on card). Lifted to B8B8C2 — 9.6:1 — because this is
    // the workhorse for secondary copy on every screen.
    mutedForeground: Color(0xFFB8B8C2),
    accent: Color(0xFFD53032),
    accentForeground: Color(0xFFFFFFFF),
    border: Color(0xFF333333),
    ring: Color(0xFFD53032),
    // Was 71717A, which measured 3.9:1 on a card — under the 4.5:1 WCAG AA
    // floor for body text, and this token is used for input hints, dropdown
    // placeholders and chat metadata, i.e. text people actually need to read.
    // 9A9AA6 measures 6.8:1 on card.
    onSurfaceHint: Color(0xFF9A9AA6),
    surfaceHover: Color(0xFF27272A),
    icon: Color(0xFFA1A1AA),
    iconMuted: Color(0xFF71717A),
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
    secondaryForeground: Color(0xFFB8B8C2),
    muted: Color(0x0DFFFFFF),       // rgba(255,255,255,0.05)
    mutedForeground: Color(0xFFB8B8C2),
    accent: Color(0xFFFF1744),
    accentForeground: Color(0xFFFFFFFF),
    border: Color(0x1AFFFFFF),      // rgba(255,255,255,0.10) — glass edge
    ring: Color(0xFFDC143C),
    onSurfaceHint: Color(0xFF9A9AA6),
    surfaceHover: Color(0x14FFFFFF), // rgba(255,255,255,0.08)
    icon: Color(0xFFA1A1AA),
    iconMuted: Color(0xFF71717A),
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
    secondaryForeground: Color(0xFFE6E2D8),
    muted: Color(0xFF120F00),
    mutedForeground: Color(0xFFBEB49C),
    accent: Color(0xFFF9A825),
    accentForeground: Color(0xFF1A1400),
    border: Color(0xFF383000),
    ring: Color(0xFFF9A825),
    onSurfaceHint: Color(0xFFA2977E),
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
    secondaryForeground: Color(0xFFDDE5EE),
    muted: Color(0xFF1E293B),         // slate-800
    mutedForeground: Color(0xFFAEBDCE),
    accent: Color(0xFF8B5CF6),        // purple
    accentForeground: Color(0xFFFFFFFF),
    border: Color(0xFF1E293B),        // slate-800
    ring: Color(0xFF3B82F6),
    // Was 64748B (slate-500), 3.75:1 on card — under the AA floor.
    onSurfaceHint: Color(0xFF94A5BB),
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
    secondaryForeground: Color(0xFFE8DCC8),
    muted: Color(0xFF120A02),
    mutedForeground: Color(0xFFC0A98E),
    accent: Color(0xFFFF6D00),
    accentForeground: Color(0xFFFFFFFF),
    border: Color(0xFF3C2810),
    ring: Color(0xFFFF6D00),
    onSurfaceHint: Color(0xFFA68D6E),
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
