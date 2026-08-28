import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';
import 'glass_styles.dart';

enum AppBadgeVariant { default_, gold, green, red, muted, accent }

/// Badge mirroring the web `Badge` component — upgraded with glassmorphism.
///
/// Each variant uses a frosted background (existing palette color at low
/// opacity), a hairline border at the accent color, and a soft glow shadow.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.default_,
    this.border = false,
  });

  final String label;
  final AppBadgeVariant variant;
  final bool border;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final (background, foreground, tint) = switch (variant) {
      AppBadgeVariant.default_ => (
        AppColors.secondary.withValues(alpha: Glass.badgeOpacity + 0.10),
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
        AppColors.muted.withValues(alpha: Glass.badgeOpacity + 0.10),
        AppColors.mutedForeground,
        AppColors.border,
      ),
      AppBadgeVariant.accent => (
        AppColors.accent.withValues(alpha: Glass.badgeOpacity),
        AppColors.accentForeground,
        AppColors.accent,
      ),
    };

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.xs),
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
        child: Text(
          label,
          style: AppTypography.bodyXs.copyWith(
            color: foreground,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
