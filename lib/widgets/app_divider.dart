import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';

/// Divider mirroring the web `Divider` component (optional centered label).
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.label, this.space = AppSpacing.lg});

  final String? label;
  final double space;

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: space / 2),
        child: const Divider(color: AppColors.border, height: 1),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: space / 2),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.border, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              label!,
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.border, height: 1)),
        ],
      ),
    );
  }
}
