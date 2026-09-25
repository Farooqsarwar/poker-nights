import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';

enum AppTagTone { neutral, primary, success, warning, danger, gold }

/// Small uppercase, tracked tag — the redesign's feature chips
/// ("AUTO BLIND STRUCTURE"), status markers ("LIVE", "ADMIN", "OPEN") and
/// parameter chips ("15 MIN LEVELS").
///
/// Distinct from [AppBadge], which is a sentence-case, fully rounded status
/// pill. A tag is squarer and set in the eyebrow type.
///
/// [AppTagTone.gold] is reserved for Premium/value and first place.
class AppTag extends StatelessWidget {
  const AppTag(
    this.label, {
    super.key,
    this.tone = AppTagTone.neutral,
    this.icon,
    this.dot = false,
  });

  final String label;
  final AppTagTone tone;
  final IconData? icon;

  /// Leading status dot in the tag's colour, e.g. for "LIVE".
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final (fill, border, fg) = switch (tone) {
      AppTagTone.neutral => (
        AppColors.muted,
        AppColors.border.withValues(alpha: 0.75),
        AppColors.mutedForeground,
      ),
      AppTagTone.primary => (
        AppColors.primarySoft,
        AppColors.primarySoftBorder,
        AppColors.primaryText,
      ),
      AppTagTone.success => (
        AppColors.successSoft,
        AppColors.successSoftBorder,
        AppColors.successText,
      ),
      AppTagTone.warning => (
        AppColors.warningSoft,
        AppColors.warningSoftBorder,
        AppColors.warningText,
      ),
      AppTagTone.danger => (
        AppColors.destructiveSoft,
        AppColors.destructive.withValues(alpha: 0.30),
        AppColors.destructiveText,
      ),
      AppTagTone.gold => (
        AppColors.gold.withValues(alpha: 0.14),
        AppColors.gold.withValues(alpha: 0.35),
        AppColors.gold,
      ),
    };

    final text = Text(
      label.toUpperCase(),
      style: AppTypography.eyebrow(size: 10, color: fg),
    );

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(color: border),
        ),
        child: (icon == null && !dot)
            ? text
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dot)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: fg,
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    Icon(icon, size: 11, color: fg),
                  const SizedBox(width: 5),
                  text,
                ],
              ),
      ),
    );
  }
}
