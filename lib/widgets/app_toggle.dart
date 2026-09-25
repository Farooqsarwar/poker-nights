import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';

/// Toggle switch mirroring the mobile-first redesign.
///
/// Features clean rounded pill track with smooth animated thumb, matching
/// the Figma settings specification.
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
    return Semantics(
      toggled: value,
      label: label ?? 'Toggle',
      button: true,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppDurations.fast,
                curve: Curves.easeInOut,
                width: 48,
                height: 28,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: value ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: value
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: AnimatedAlign(
                  duration: AppDurations.fast,
                  curve: Curves.easeInOut,
                  alignment: value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: value ? AppColors.foreground : AppColors.mutedForeground,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowSoft,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
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
        ),
      ),
    );
  }
}
