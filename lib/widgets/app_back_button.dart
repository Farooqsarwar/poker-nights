import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';

/// Standard back arrow with a 44px tap target, tooltip and screen-reader
/// label. Replaces the duplicated inline back arrows across detail screens.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    required this.onTap,
    this.tooltip = 'Go back',
  });

  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tooltip,
      button: true,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Text(
                '←',
                style: AppTypography.body(
                  size: AppFontSizes.xl,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
