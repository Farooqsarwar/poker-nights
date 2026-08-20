import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';

/// Back-arrow + title header used at the top of most screens.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    this.onBack,
    this.icon,
    required this.title,
    this.subtitle,
    this.actions,
  });

  /// When set, renders the `←` back button.
  final VoidCallback? onBack;
  final String? icon;
  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null) ...[
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md, top: 4),
              child: Text(
                '←',
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ),
        ],
        if (icon != null) ...[
          Text(icon!, style: AppTypography.display(size: AppFontSizes.xl)),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.display(
                  size: AppFontSizes.xxxl,
                  weight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actions != null && actions!.isNotEmpty)
          Row(mainAxisSize: MainAxisSize.min, children: actions!),
      ],
    );
  }
}
