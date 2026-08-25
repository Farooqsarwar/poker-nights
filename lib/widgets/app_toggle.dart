import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';

/// Toggle switch mirroring the web `Toggle` component.
class AppToggle extends StatelessWidget {
  const AppToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: AppDurations.fast,
            width: 40,
            height: 20,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: value ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: AnimatedAlign(
              duration: AppDurations.fast,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.foreground,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppColors.shadowSoft, blurRadius: 2),
                  ],
                ),
              ),
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: AppSpacing.md),
            Text(label!, style: AppTypography.bodySm),
          ],
        ],
      ),
    );
  }
}
