import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_constants.dart';
import '../responsive/responsive.dart';
import 'colors.dart';

/// Centralized typography for the Poker Night app.
///
/// Three families (mirroring the web app):
///  - Display: Space Grotesk (sans)  — headings & brand
///  - Body:    Space Grotesk (sans)  — general UI
///  - Mono:    Space Mono (mono)     — numbers, codes, timers
class AppTypography {
  AppTypography._();

  // ── Font family names ──────────────────────────────────────────────────────
  static const String displayFamily = 'Space Grotesk';
  static const String bodyFamily = 'Space Grotesk';
  static const String monoFamily = 'Space Mono';

  static TextStyle display({
    double size = AppFontSizes.lg,
    FontWeight weight = FontWeight.w600,
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
    return GoogleFonts.spaceMono(
      fontSize: AppScale.sp(size),
      fontWeight: weight,
      color: color ?? AppColors.foreground,
      height: height,
      letterSpacing: letterSpacing,
    ).copyWith(
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
    return GoogleFonts.spaceMono(
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
            fontFamilyFallback: ['Space Mono', 'monospace'],
          ),
        );
  }
}
