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
  ///
  /// Currently only dark variants are used (the light variant is kept for
  /// future use but shares the same palette).
  static ThemeData forPalette(ThemePalette palette, {Brightness brightness = Brightness.dark}) {
    final colorScheme = ColorScheme(
      brightness: brightness,
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

    final base = ThemeData(useMaterial3: false, colorScheme: colorScheme);

    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      textTheme: AppTypography.textTheme(),
      canvasColor: palette.background,
      dividerColor: palette.border,
      splashColor: palette.primarySoft,
      highlightColor: palette.primarySoft,
      focusColor: palette.primarySoft,
      hoverColor: palette.primarySoft,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: palette.foreground,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.card,
        selectedItemColor: palette.primary,
        unselectedItemColor: palette.mutedForeground,
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
        fillColor: palette.card,
        hintStyle: AppTypography.body(color: palette.onSurfaceHint),
        labelStyle: AppTypography.body(color: palette.mutedForeground),
        errorStyle: AppTypography.body(
          color: palette.destructive,
          size: AppFontSizes.xs,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: palette.border),
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
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: palette.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: palette.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.secondary,
        contentTextStyle: AppTypography.body(),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: palette.border),
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
        textStyle: TextStyle(
          color: palette.foreground,
          fontSize: AppFontSizes.xs,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => palette.border,
        ),
        radius: const Radius.circular(2),
        thickness: WidgetStateProperty.all(4),
      ),
    );
  }

  /// Convenience: builds the dark [ThemeData] from the current [AppColors]
  /// palette.  Used by [PokerNightApp].
  static ThemeData dark() {
    return forPalette(AppColors.currentPalette);
  }

  /// Light variant – reuses the same palette with a paper-toned surface.
  /// Kept for the ThemeMode.light / system toggle.
  static ThemeData light() {
    const paper = Color(0xFFF6F4EF);
    const paperCard = Colors.white;
    const ink = Color(0xFF1C1B18);
    const inkMuted = Color(0xFF6B675F);
    const line = Color(0xFFE4E1DA);

    final p = AppColors.currentPalette;

    final colorScheme = ColorScheme.light(
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.secondary,
      surface: paperCard,
      onSurface: ink,
      error: p.destructive,
      onError: Colors.white,
    );

    final base = ThemeData(useMaterial3: false, colorScheme: colorScheme);

    return base.copyWith(
      scaffoldBackgroundColor: paper,
      textTheme: AppTypography.textTheme(),
      canvasColor: paper,
      dividerColor: line,
      splashColor: p.primarySoft,
      highlightColor: p.primarySoft,
      focusColor: p.primarySoft,
      hoverColor: p.primarySoft,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: paperCard,
        selectedItemColor: p.primary,
        unselectedItemColor: inkMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paperCard,
        hintStyle: AppTypography.body(color: inkMuted),
        labelStyle: AppTypography.body(color: inkMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.primary, width: 1.2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paperCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: line),
        ),
      ),
      cardTheme: CardThemeData(
        color: paperCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: AppTypography.body(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
