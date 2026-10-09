import 'package:flutter/material.dart';

/// The app's colour tokens.
///
/// **Build Spec v3.1 §B1 — "Exactly one look: black ground, crimson accent,
/// white ink."** There is one palette, and every value below is §B1's own
/// token table pinned as a literal.
///
/// The three alternative palettes (`crimsonGlass`, `cosmicAi`, `darkOrange`)
/// were removed: §B1 does not describe a themeable app, and two of them
/// carried banned hues outright — blue/purple and orange/amber respectively.
///
/// The previous `Color.lerp(base, white, 0.40)` text variants were a reasonable
/// answer to "a fill colour cannot also be a text colour" while four palettes
/// had to share one rule. With a single palette the spec simply states both
/// values (`red` and `redText`), and a derivation can only drift away from
/// them, so the derived getters are now lookups.
///
/// The legacy field names (`primary`, `destructive`, `warning`, …) are kept so
/// the ~175 `AppColors.xxx` call sites keep compiling; each resolves to its
/// §B1 token. New code should prefer the §B1 names, exposed alongside them.
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

  // ── §B1 tokens, by their spec names ─────────────────────────────────────

  /// `bg` `#0A0A0A` — app ground, scoreboard ground, input fill.
  Color get bg => background;

  /// `surface` `#141414` — cards, list rows, tiles.
  Color get surface => card;

  /// `surface2` `#1C1C1C` — secondary buttons, the square back button,
  /// steppers' inner fill, drawer rows on press.
  Color get surface2 => secondary;

  /// `borderStrong` `rgba(255,255,255,0.16)` — focused and secondary outlines,
  /// sheet borders.
  Color get borderStrong => const Color(0x29FFFFFF);

  /// `red` `#D53032` — brand: filled buttons, the active tab pill, progress
  /// bars, big numerals (**≥ 24 px**), the logo.
  Color get red => primary;

  /// `redText` `#F2555A` — red **text below 24 px**. §B1: *"Wherever this
  /// document calls text below 24 px (18.66 px bold) 'red' or 'crimson' —
  /// eyebrows, the LEVEL and ANTE labels, antes in tables, link rows, legal
  /// headings — it means `redText`, never `red`"* (`red` measures 4.05 : 1 on
  /// `bg` and 3.77 : 1 on `surface`, both under the AA floor).
  Color get redText => const Color(0xFFF2555A);

  /// `redDim` `rgba(213,48,50,0.16)` — tinted fills: the selected option,
  /// avatar tints, pill backgrounds, hero cards.
  Color get redDim => const Color(0x29D53032);

  /// `redDanger` `#B23430` — destructive actions (End tournament, Delete
  /// account). **Fill only**, with white text (6.13 : 1); as a text or outline
  /// colour it fails at 3.23 : 1 on `bg`.
  Color get redDanger => const Color(0xFFB23430);

  /// `white` `#FFFFFF` — primary text, clock minutes.
  Color get white => foreground;

  /// `muted2` `#939399` — tertiary text, small uppercase labels
  /// (≥ 4.6 : 1 on every surface).
  Color get muted2 => onSurfaceHint;

  /// `green` `#3FBF6B` — **only** the LIVE dot, GOING / CHECKED IN / ACTIVE
  /// pills, and positive P&L figures (§B4 rule 9).
  Color get green => success;

  /// §B1: disabled controls are 40 % opacity of the control, with the reason
  /// always visible as text beside them — never opacity alone.
  static const double disabledOpacity = 0.40;

  // ── Text-safe semantic colours ──────────────────────────────────────────
  //
  // §B1 splits one job into two tokens — `red` is the fill, `redText` is the
  // text — so these are lookups, not calculations.
  //
  // `warning` has NO §B1 token. The palette is deliberately complete and
  // contains no amber: "There is no gold, yellow, amber or second accent
  // anywhere (a test fails on any yellow pixel colour, T141)." The previous
  // value was `#E65100`, a deep amber, shipping in the DEFAULT palette and
  // used in 42 places — a T141 violation entirely separate from the
  // `darkOrange` palette that was removed alongside it.
  //
  // §B4 rule 9 says what a warning should be instead: money is white, a
  // headline may be crimson, and negative values are `redText`. So the whole
  // `warning*` family resolves to the red tokens. The names are kept only so
  // the existing call sites keep compiling.

  Color get primaryText => redText;
  Color get destructiveText => redText;
  Color get warningText => redText;

  /// Positive results and live status only (§B1, §B4 rule 9).
  Color get successText => green;

  // ── Derived decorative colours ──────────────────────────────────────────
  Color get primarySoft => redDim;
  Color get primarySoftBorder => primary.withValues(alpha: 0.30);
  Color get primarySoftStrong => primary.withValues(alpha: 0.50);
  Color get destructiveSoft => redDim;
  Color get warningSoft => redDim;
  Color get warningSoftBorder => primary.withValues(alpha: 0.30);
  Color get successSoft => Color.alphaBlend(success.withValues(alpha: 0.15), muted);
  Color get successSoftBorder => success.withValues(alpha: 0.30);
  Color get feltGlow => primary.withValues(alpha: 0.04);
  Color get glassOverlay => const Color(0x99000000);
  Color get hairlineWhite => const Color(0x33FFFFFF);
  Color get hairlineBorder => border.withValues(alpha: 0.30);

  /// The redesign's default 1px edge on dark cards, rows and raised controls —
  /// present but quieter than [border].
  Color get borderSubtle => border.withValues(alpha: 0.75);
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
    muted,
  ];

  /// Hues for the redesign's tinted avatars (T140). Drawn from the semantic
  /// colours so everything stays in key. `warning` used to be the fourth tint
  /// and was amber; the list is now red / green / muted, which is §B1's whole
  /// vocabulary.
  List<Color> get avatarTints => [primary, success, mutedForeground];

  Color avatarTintFor(String name) {
    final key = name.trim();
    if (key.isEmpty) return avatarTints.last;
    // Hash the whole name, not the initial: first letters cluster ("A", "M")
    // and gave a whole table the same colour.
    var h = 0;
    for (final c in key.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return avatarTints[h % avatarTints.length];
  }

  Color avatarColorFor(String name) {
    final key = name.trim();
    if (key.isEmpty) return avatarPalette.first;
    var h = 0;
    for (final c in key.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return avatarPalette[h % avatarPalette.length];
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

/// The app's one look (§B1). [all] keeps its list shape so callers that iterate
/// it still compile, but it has exactly one entry and there is no Appearance
/// picker to choose from.
class ThemePalettes {
  ThemePalettes._();

  static const String defaultId = 'red';

  static const List<ThemePalette> all = [red];

  /// Any stored `paletteId` from before the one-look rule was applied —
  /// `crimson-glass`, `cosmic-ai`, `dark-orange` — falls through to [red] via
  /// `orElse`, so no data migration is needed for users who had picked one.
  static ThemePalette forId(String id) {
    return all.firstWhere((p) => p.id == id, orElse: () => red);
  }

  // ── §B1's token table, pinned ───────────────────────────────────────────
  //
  // Where a previous hand-tuned value differed, the delta is noted. In each
  // case the spec states its own contrast measurement and it clears AA.
  static const red = ThemePalette(
    id: 'red',
    name: 'Red',
    // `red` #D53032 — brand fill, big numerals, the logo.
    primary: Color(0xFFD53032),
    onPrimary: Color(0xFFFFFFFF),
    // Not a §B1 token: the hover step. ~7 % lightness above D53032, the
    // smallest lift that reads as a hover rather than no change at all.
    primaryHover: Color(0xFFE24446),
    // `bg` #0A0A0A.
    background: Color(0xFF0A0A0A),
    // `white` #FFFFFF.
    foreground: Color(0xFFFFFFFF),
    // `surface` #141414. Was #141416.
    card: Color(0xFF141414),
    cardForeground: Color(0xFFFFFFFF),
    // `surface2` #1C1C1C. Was #18181A.
    secondary: Color(0xFF1C1C1C),
    secondaryForeground: Color(0xFFEDEDF0),
    muted: Color(0xFF1A1A1A),
    // `muted` #A6A6AA — secondary text, inactive tab labels. Was #B8B8C2,
    // lifted by hand for contrast; §B1's value measures ~7.7 : 1 on `surface`,
    // well over the 4.5 : 1 floor, so the hand-tuning no longer does any work.
    mutedForeground: Color(0xFFA6A6AA),
    accent: Color(0xFFD53032),
    accentForeground: Color(0xFFFFFFFF),
    // `border` rgba(255,255,255,0.08). Was the solid #28282C; §B1 specifies a
    // translucent hairline so an edge reads the same over any surface.
    border: Color(0x14FFFFFF),
    ring: Color(0xFFD53032),
    // `muted2` #939399 — tertiary text, small uppercase labels. Was #9A9AA6.
    onSurfaceHint: Color(0xFF939399),
    surfaceHover: Color(0xFF27272A),
    icon: Color(0xFFA6A6AA),
    iconMuted: Color(0xFF939399),
    // `redDanger` #B23430 — fill only, white text at 6.13 : 1. Was #E53935,
    // which is not a §B1 colour at all.
    destructive: Color(0xFFB23430),
    destructiveForeground: Color(0xFFFFFFFF),
    // `green` #3FBF6B — LIVE dot, GOING / CHECKED IN / ACTIVE pills, positive
    // P&L only. Was #2E7D32.
    success: Color(0xFF3FBF6B),
    successForeground: Color(0xFFFFFFFF),
    // No §B1 warning token exists; see the note on `warningText`. Pointed at
    // the brand red so nothing amber can reach the screen through this field.
    warning: Color(0xFFD53032),
    warningForeground: Color(0xFFFFFFFF),
  );
}
