import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'colors.dart';
import 'typography.dart';

/// Centralized application theme — a single dark casino theme.
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final colorScheme = const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      primaryContainer: AppColors.accent,
      onPrimaryContainer: AppColors.primaryForeground,
      secondary: AppColors.secondary,
      onSecondary: AppColors.secondaryForeground,
      secondaryContainer: AppColors.secondary,
      onSecondaryContainer: AppColors.secondaryForeground,
      surface: AppColors.card,
      onSurface: AppColors.cardForeground,
      surfaceContainerHighest: AppColors.muted,
      onSurfaceVariant: AppColors.mutedForeground,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      error: AppColors.destructive,
      onError: AppColors.destructiveForeground,
      errorContainer: AppColors.destructiveSoft,
      onErrorContainer: AppColors.destructive,
    );

    final base = ThemeData(useMaterial3: false, colorScheme: colorScheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTypography.textTheme(),
      canvasColor: AppColors.background,
      dividerColor: AppColors.border,
      splashColor: AppColors.primarySoft,
      highlightColor: AppColors.primarySoft,
      focusColor: AppColors.primarySoft,
      hoverColor: AppColors.primarySoft,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // ── App bar ────────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.foreground,
        centerTitle: false,
      ),
      // ── Bottom navigation ──────────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.card,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.mutedForeground,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      // ── Buttons ────────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryForeground,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          disabledForegroundColor: AppColors.primaryForeground.withValues(alpha: 0.6),
          textStyle: AppTypography.body(size: AppFontSizes.sm, weight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      // ── Inputs ─────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        hintStyle: AppTypography.body(color: AppColors.onSurfaceHint),
        labelStyle: AppTypography.body(color: AppColors.mutedForeground),
        errorStyle: AppTypography.body(color: AppColors.destructive, size: AppFontSizes.xs),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.destructive),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.destructive, width: 1.2),
        ),
      ),
      // ── Dialogs / modals ───────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      // ── Misc ───────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.secondary,
        contentTextStyle: AppTypography.body(),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.muted,
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
        ),
        textStyle: TextStyle(color: AppColors.foreground, fontSize: AppFontSizes.xs),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => AppColors.border),
        radius: const Radius.circular(2),
        thickness: WidgetStateProperty.all(4),
      ),
    );
  }
}
