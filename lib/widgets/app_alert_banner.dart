import 'package:flutter/material.dart';

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
        const Color(0x4D262626),
        const Color(0x4D525252),
        const Color(0xFFE4E4E7),
      ),
      AppAlertType.warning => (
        const Color(0x4D7F1D1D),
        const Color(0x4D7F1D1D),
        const Color(0xFFFECACA),
      ),
      AppAlertType.success => (
        const Color(0x4D262626),
        const Color(0x4D525252),
        const Color(0xFFE4E4E7),
      ),
      AppAlertType.error => (
        const Color(0x4D450A0A),
        const Color(0x4D991B1B),
        const Color(0xFFFECACA),
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
