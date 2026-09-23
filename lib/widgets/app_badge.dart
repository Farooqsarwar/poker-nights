import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';
import '../responsive/responsive.dart';
import 'glass_styles.dart';

enum AppBadgeVariant { default_, gold, green, red, muted, accent }

/// Badge mirroring the web `Badge` component — upgraded with glassmorphism.
///
/// Each variant uses a frosted background (existing palette color at low
/// opacity), a hairline border at the accent color, and a soft glow shadow.
///
/// Shape follows the client's component sheet: status pills are FULLY rounded,
/// while actions (buttons, steppers) stay at [AppRadius.md]. That contrast is
/// the sheet's core shape rule — round means "this is a piece of data", square
/// means "you can press this". This used to be [AppRadius.xs] (6px), which made
/// badges squarer than buttons and inverted the whole language.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.default_,
    this.border = false,
    this.icon,
    this.dotColor,
  });

  final String label;
  final AppBadgeVariant variant;
  final bool border;

  /// Optional leading glyph, e.g. the sheet's `All-in` and `Busted` pills.
  /// Sized off the label so it tracks the text scale rather than fighting it.
  final IconData? icon;

  /// Optional leading dot. Use it for "live" style indicators where a glyph
  /// would be too loud. Takes precedence over [icon] if both are given.
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final (background, foreground, tint) = switch (variant) {
      AppBadgeVariant.default_ => (
        Glass.solidTint(AppColors.secondary),
        AppColors.secondaryForeground,
        AppColors.primary,
      ),
      AppBadgeVariant.gold => (
        AppColors.primary.withValues(alpha: Glass.badgeOpacity),
        AppColors.primary,
        AppColors.primary,
      ),
      AppBadgeVariant.green => (
        AppColors.success.withValues(alpha: Glass.badgeOpacity),
        AppColors.success,
        AppColors.success,
      ),
      AppBadgeVariant.red => (
        AppColors.destructive.withValues(alpha: Glass.badgeOpacity),
        AppColors.destructive,
        AppColors.destructive,
      ),
      AppBadgeVariant.muted => (
        Glass.solidTint(AppColors.muted),
        AppColors.mutedForeground,
        AppColors.border,
      ),
      AppBadgeVariant.accent => (
        AppColors.accent.withValues(alpha: Glass.badgeOpacity),
        AppColors.accentForeground,
        AppColors.accent,
      ),
    };

    final text = Text(
      label,
      style: AppTypography.bodyXs.copyWith(
        color: foreground,
        fontWeight: FontWeight.w500,
      ),
    );

    // A fully-rounded shape eats into the text's optical space at both ends, so
    // a pill needs more horizontal padding than the old 6px-radius box did to
    // read as evenly inset.
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: tint.withValues(
              alpha: border ? Glass.borderActiveOpacity : Glass.borderOpacity,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: 0.08),
              blurRadius: 6,
            ),
          ],
        ),
        child: (icon == null && dotColor == null)
            ? text
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dotColor != null) ...[
                    Container(
                      width: AppScale.sp(6),
                      height: AppScale.sp(6),
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: AppScale.sp(5)),
                  ] else if (icon != null) ...[
                    Icon(icon, size: AppScale.sp(12), color: foreground),
                    SizedBox(width: AppScale.sp(4)),
                  ],
                  text,
                ],
              ),
      ),
    );
  }
}
