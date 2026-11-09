import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/theme_palette.dart';
import 'colors.dart';
import 'typography.dart';

/// Centralized application theme – generates a full [ThemeData] from any
/// [ThemePalette].
class AppTheme {
  AppTheme._();

  /// Builds the [ThemeData] for the given [palette].
  static ThemeData forPalette(
    ThemePalette palette, {
    Brightness brightness = Brightness.dark,
  }) {
    // Spec B1: One-look black application aesthetic. Dark-only palette.
    final bg = palette.background;
    final cardBg = palette.card;
    final fg = palette.foreground;
    final mutedFg = palette.mutedForeground;
    final borderColor = palette.border;
    final selectedNavColor = palette.redText;

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      primaryContainer: palette.accent,
      onPrimaryContainer: palette.accentForeground,
      secondary: palette.secondary,
      onSecondary: palette.secondaryForeground,
      secondaryContainer: palette.secondary,
      onSecondaryContainer: palette.secondaryForeground,
      surface: palette.card,
      onSurface: palette.cardForeground,
      surfaceContainerHighest: palette.muted,
      onSurfaceVariant: palette.mutedForeground,
      outline: palette.border,
      outlineVariant: palette.border,
      error: palette.destructive,
      onError: palette.destructiveForeground,
      errorContainer: palette.destructiveSoft,
      onErrorContainer: palette.destructive,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      textTheme: AppTypography.textTheme(),
      canvasColor: bg,
      dividerColor: borderColor,
      splashColor: palette.primarySoft,
      highlightColor: palette.primarySoft,
      focusColor: palette.primarySoft,
      hoverColor: palette.primarySoft,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: fg,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardBg,
        selectedItemColor: selectedNavColor,
        unselectedItemColor: mutedFg,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          disabledBackgroundColor: palette.primary.withValues(alpha: 0.4),
          disabledForegroundColor: palette.onPrimary.withValues(alpha: 0.6),
          textStyle: AppTypography.body(
            size: AppFontSizes.sm,
            weight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        hintStyle: AppTypography.body(color: mutedFg),
        labelStyle: AppTypography.body(color: mutedFg),
        errorStyle: AppTypography.body(
          color: AppColors.redText,
          size: AppFontSizes.xs,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: palette.primary, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: palette.destructive),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: palette.destructive,
            width: 1.2,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: borderColor),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: borderColor),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.secondary,
        contentTextStyle: AppTypography.body(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: borderColor),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
        linearTrackColor: palette.muted,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.secondary,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
        ),
        textStyle: AppTypography.body(
          size: AppFontSizes.xs,
          color: Colors.white,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => borderColor,
        ),
        radius: const Radius.circular(2),
        thickness: WidgetStateProperty.all(4),
      ),
    );
  }
}