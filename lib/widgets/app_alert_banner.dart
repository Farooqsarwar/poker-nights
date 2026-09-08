import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';

enum AppAlertType { info, warning, success, error }

/// Alert banner mirroring the web `AlertBanner` component.
class AppAlertBanner extends StatelessWidget {
  const AppAlertBanner({
    super.key,
    this.type = AppAlertType.info,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final AppAlertType type;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final (background, border, foreground) = switch (type) {
      AppAlertType.info => (
        AppColors.muted,
        AppColors.border,
        AppColors.foreground,
      ),
      AppAlertType.warning => (
        AppColors.warningSoft,
        AppColors.warning,
        AppColors.warningForeground,
      ),
      AppAlertType.success => (
        AppColors.muted,
        AppColors.border,
        AppColors.foreground,
      ),
      AppAlertType.error => (
        AppColors.destructiveSoft,
        AppColors.destructive,
        AppColors.destructiveForeground,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySm.copyWith(color: foreground),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: AppSpacing.sm),
            InkWell(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: AppTypography.bodyXs.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: foreground,
                ),
              ),
            ),
          ],
          if (onDismiss != null) ...[
            const SizedBox(width: AppSpacing.sm),
            InkWell(
              onTap: onDismiss,
              child: Text(
                '×',
                style: AppTypography.bodyLg.copyWith(
                  color: foreground.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
