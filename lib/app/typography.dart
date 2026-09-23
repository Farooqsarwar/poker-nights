import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_constants.dart';
import '../responsive/responsive.dart';
import 'colors.dart';

/// Centralized typography for the Poker Night app.
///
/// ONE family everywhere — Space Grotesk — for headings, brand, body, labels
/// and numerals alike. The client's product system states it flatly: "one
/// typeface everywhere — numerals, wordmark, labels, and body copy. No second
/// typeface."
///
/// [mono] used to be Space Mono, a genuinely different face. What a second
/// family was buying us was column alignment on the timer and the chip counts,
/// and that is what [numericFeatures] does instead: `tnum` gives every digit
/// the same advance width, so a clock ticking 19:59 -> 20:00 does not shuffle
/// sideways, and `zero` slashes the zero so it cannot be misread as an O. Both
/// are named in the product system. Keep calling [mono] for numbers, codes and
/// timers — it is still the right style, it is just no longer a second face.
class AppTypography {
  AppTypography._();

  // ── Font family names ──────────────────────────────────────────────────────
  static const String displayFamily = 'Space Grotesk';
  static const String bodyFamily = 'Space Grotesk';
  static const String monoFamily = 'Space Grotesk';

  /// Tabular (fixed-advance) figures plus a slashed zero — the product
  /// system's stated substitute for a monospaced face. A font that lacks
  /// either feature simply ignores it, so this is safe on the fallbacks too.
  static const List<FontFeature> numericFeatures = [
    FontFeature.tabularFigures(),
    FontFeature.slashedZero(),
  ];

  static TextStyle display({
    double size = AppFontSizes.lg,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double? height = 1.1,
    double? letterSpacing,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: AppScale.sp(size),
      fontWeight: weight,
      color: color ?? AppColors.foreground,
      height: height,
      // Space Grotesk display headers look premium with tighter tracking
      letterSpacing: letterSpacing ?? (size >= AppFontSizes.xl ? -0.8 : -0.3),
    ).copyWith(
      fontFamilyFallback: const [
        'Noto Color Emoji',
        'Apple Color Emoji',
        'Segoe UI Emoji',
      ],
    );
  }

  static TextStyle body({
    double size = AppFontSizes.md,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height = 1.5,
    double? letterSpacing,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: AppScale.sp(size),
      fontWeight: weight,
      color: color ?? AppColors.foreground,
      height: height,
      // Slight positive tracking for body text improves legibility
      letterSpacing: letterSpacing ?? 0.2,
    ).copyWith(
      fontFamilyFallback: const [
        'Noto Color Emoji',
        'Apple Color Emoji',
        'Segoe UI Emoji',
      ],
    );
  }

  static TextStyle mono({
    double size = AppFontSizes.md,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: AppScale.sp(size),
      fontWeight: weight,
      color: color ?? AppColors.foreground,
      height: height,
      letterSpacing: letterSpacing,
    ).copyWith(
      fontFeatures: numericFeatures,
      fontFamilyFallback: const [
        'Noto Color Emoji',
        'Apple Color Emoji',
        'Segoe UI Emoji',
      ],
    );
  }

  // ── Convenience getters ───────────────────────────────────────────────────
  static TextStyle get bodyStyle => body(size: AppFontSizes.md);
  static TextStyle get bodySm => body(size: AppFontSizes.sm);
  static TextStyle get bodyXs => body(size: AppFontSizes.xs);
  static TextStyle get bodyLg => body(size: AppFontSizes.lg);
  static TextStyle get bodyBold =>
      body(size: AppFontSizes.md, weight: FontWeight.w600);
  static TextStyle get buttonStyle =>
      body(size: AppFontSizes.sm, weight: FontWeight.w500);
  static TextStyle get monoStyle => mono();
  static TextStyle get monoXs => mono(size: AppFontSizes.xs);
  static TextStyle get monoSm => mono(size: AppFontSizes.sm);
  static TextStyle get monoLg => mono(size: AppFontSizes.lg);
  static TextStyle get monoXl =>
      mono(size: AppFontSizes.xl, weight: FontWeight.w700);
  static TextStyle get displayStyle => display();
  static TextStyle get displaySm => display(size: AppFontSizes.lg);
  static TextStyle get displayMd => display(size: AppFontSizes.xl);

  /// The shimmer effect used on brand words (Poker Night, Dashboard, …).
  static TextStyle crimsonShimmer({
    double size = AppFontSizes.lg,
    FontWeight weight = FontWeight.w700,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: AppScale.sp(size),
      fontWeight: weight,
      foreground: Paint()
        ..shader = AppColors.crimsonShimmer.createShader(
          const Rect.fromLTWH(0, 0, 240, 48),
        ),
    );
  }

  /// Builds the full [TextTheme] wired to Google Fonts.
  static TextTheme textTheme() {
    final base = TextTheme(
      // Display styles
      displayLarge: display(
        size: AppFontSizes.displayHero,
        weight: FontWeight.w700,
      ),
      displayMedium: display(
        size: AppFontSizes.displayLg,
        weight: FontWeight.w700,
      ),
      displaySmall: display(
        size: AppFontSizes.display,
        weight: FontWeight.w700,
      ),
      headlineMedium: display(size: AppFontSizes.xxl, weight: FontWeight.w700),
      headlineSmall: display(size: AppFontSizes.xl, weight: FontWeight.w600),
      titleLarge: display(size: AppFontSizes.lg, weight: FontWeight.w600),
      titleMedium: body(size: AppFontSizes.md, weight: FontWeight.w600),
      titleSmall: body(size: AppFontSizes.sm, weight: FontWeight.w500),
      bodyLarge: body(size: AppFontSizes.md),
      bodyMedium: body(size: AppFontSizes.sm),
      bodySmall: body(
        size: AppFontSizes.xs,
        color: AppColors.mutedForeground,
      ),
      labelLarge: body(size: AppFontSizes.sm, weight: FontWeight.w600),
      labelMedium: body(size: AppFontSizes.xs, weight: FontWeight.w500),
      labelSmall: body(size: AppFontSizes.xs),
    );

    return base
        .apply(
          bodyColor: AppColors.foreground,
          displayColor: AppColors.foreground,
        )
        .copyWith(
          bodyLarge: base.bodyLarge!.copyWith(
            fontFamily: bodyFamily,
          ),
        );
  }
}
