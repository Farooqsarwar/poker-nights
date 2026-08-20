import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';

enum AppBadgeVariant { default_, gold, green, red, muted, accent }

/// Badge mirroring the web `Badge` component.
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
    final (background, foreground, edge) = switch (variant) {
      AppBadgeVariant.default_ => (
        AppColors.secondary,
        AppColors.secondaryForeground,
        _borderFor(AppColors.primarySoftBorder, border),
      ),
      AppBadgeVariant.gold => (
        AppColors.primarySoft,
        AppColors.primary,
        _borderFor(AppColors.primarySoftBorder, border),
      ),
      AppBadgeVariant.green => (
        AppColors.successSoft,
        AppColors.success,
        _borderFor(AppColors.successSoftBorder, border),
      ),
      AppBadgeVariant.red => (
        AppColors.destructiveSoft,
        AppColors.destructive,
        _borderFor(AppColors.destructive.withValues(alpha: 0.3), border),
      ),
      AppBadgeVariant.muted => (
        AppColors.muted,
        AppColors.mutedForeground,
        _borderFor(AppColors.border, border),
      ),
      AppBadgeVariant.accent => (
        AppColors.primarySoft,
        AppColors.primary,
        _borderFor(AppColors.primarySoftBorder, border),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: edge,
      ),
      child: Text(
        label,
        style: AppTypography.bodyXs.copyWith(
          color: foreground,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Border? _borderFor(Color color, bool show) {
    if (!show) return null;
    return Border.all(color: color, width: 1);
  }
}
