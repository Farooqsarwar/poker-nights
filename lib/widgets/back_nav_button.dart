import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import 'min_tap_target.dart';

/// The back affordance that sits to the left of a screen's page title.
///
/// Six screens had hand-rolled this as the same `InkWell > Padding > Icon`
/// tree, byte-identical apart from the callback. All six shared the same two
/// defects: a ~30px tap target, and no accessible name at all — a screen
/// reader announced the most-used control on the screen as nothing.
///
/// It is deliberately NOT Flutter's `BackButton`: these screens navigate with
/// `context.go` to a specific destination rather than popping a stack, so the
/// destination is the caller's to decide.
class BackNavButton extends StatelessWidget {
  const BackNavButton({
    super.key,
    required this.onPressed,
    this.label = 'Back',
  });

  final VoidCallback onPressed;

  /// The accessible name and tooltip. Name the DESTINATION where the screen
  /// knows it ('Back to dashboard') — 'Back' alone tells a screen-reader user
  /// nothing they could not already guess.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: MinTapTarget(
            child: Icon(
              Icons.arrow_back,
              size: AppFontSizes.xl,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
