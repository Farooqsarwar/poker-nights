import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';

/// Standard design-system slider component with 44px touch target
/// and Poker Night branding (crimson active track and custom thumb).
class AppSlider extends StatelessWidget {
  const AppSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.label,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.title,
    this.valueLabel,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final String? title;
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveActive = activeColor ?? AppColors.primary;
    final effectiveInactive =
        inactiveColor ?? AppColors.borderSubtle;
    final effectiveThumb = thumbColor ?? AppColors.foreground;

    final sliderWidget = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        activeTrackColor: effectiveActive,
        inactiveTrackColor: effectiveInactive,
        thumbColor: effectiveThumb,
        overlayColor: effectiveActive.withValues(alpha: 0.16),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
        valueIndicatorColor: AppColors.card,
        valueIndicatorTextStyle: AppTypography.monoXs.copyWith(
          color: AppColors.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: SizedBox(
        height: 44, // Enforce 44px touch target
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: label,
          onChanged: onChanged,
        ),
      ),
    );

    if (title == null && valueLabel == null) {
      return sliderWidget;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null || valueLabel != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (title != null)
                Text(
                  title!,
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
              if (valueLabel != null)
                Text(
                  valueLabel!,
                  style: AppTypography.monoSm.copyWith(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.xxs),
        sliderWidget,
      ],
    );
  }
}
