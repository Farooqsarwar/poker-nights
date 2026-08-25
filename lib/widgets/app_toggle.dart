import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../app/typography.dart';
import 'glass_styles.dart';

/// Toggle switch mirroring the web `Toggle` component with glassmorphism.
///
/// Glass track with frosted thumb, ambient glow when active, and subtle
/// neumorphic shadows.
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
            duration: AppDurations.normal,
            curve: Curves.easeInOut,
            width: 44,
            height: 24,
            padding: const EdgeInsets.all(2),
            decoration: Glass.glassToggle(active: value),
            child: AnimatedAlign(
              duration: AppDurations.normal,
              curve: Curves.easeInOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: Glass.glassToggleThumb(),
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
