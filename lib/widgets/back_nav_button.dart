import 'package:flutter/material.dart';

import '../app/colors.dart';
import 'squircle_icon_button.dart';

/// The mobile-first squircle back affordance matching Figma designs.
///
/// Deliberately NOT Flutter's standard `BackButton`: screens navigate with
/// `context.go` or `context.pop` to a specific destination.
class BackNavButton extends StatelessWidget {
  const BackNavButton({
    super.key,
    required this.onPressed,
    this.label = 'Back',
    this.iconColor,
  });

  final VoidCallback onPressed;

  /// The accessible name and tooltip.
  final String label;

  /// Icon color, defaults to crimson red `AppColors.primary`.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return SquircleIconButton(
      icon: Icons.chevron_left,
      iconSize: 26,
      iconColor: iconColor ?? AppColors.primary,
      tooltip: label,
      onPressed: onPressed,
    );
  }
}
