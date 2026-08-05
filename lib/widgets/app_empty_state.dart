import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';

/// Empty state mirroring the web `EmptyState` component.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    this.icon,
    required this.title,
    this.description,
    this.action,
  });

  final String? icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.huge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null)
            Text(
              icon!,
              style: const TextStyle(fontSize: AppFontSizes.display),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.display(size: AppFontSizes.lg),
          ),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                description!,
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}
