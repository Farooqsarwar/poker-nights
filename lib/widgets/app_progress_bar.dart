import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';

enum AppProgressColor { primary, success, destructive }

/// Progress bar mirroring the web `ProgressBar` component.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    required this.max,
    this.color = AppProgressColor.primary,
    this.height = 6,
  });

  final double value;
  final double max;
  final AppProgressColor color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pct = (value / max).clamp(0.0, 1.0);
    final fillColor = switch (color) {
      AppProgressColor.primary => AppColors.primary,
      AppProgressColor.success => AppColors.success,
      AppProgressColor.destructive => AppColors.destructive,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(width: double.infinity, color: AppColors.muted),
            TweenAnimationBuilder<double>(
              duration: AppDurations.normal,
              tween: Tween(begin: 0, end: pct),
              builder: (context, factor, _) => Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: factor,
                  heightFactor: 1,
                  child: ColoredBox(color: fillColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
