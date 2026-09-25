import 'package:flutter/material.dart';

import 'app_back_button.dart';

/// The mobile-first back affordance.
///
/// Deliberately NOT Flutter's standard `BackButton`: screens navigate with
/// `context.go` or `context.pop` to a specific destination.
///
/// Renders the shared [AppBackButton] tile so every screen's back control
/// looks the same, as the redesign draws it. Kept as its own widget so its
/// existing call sites need no change.
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

  /// No longer applied: the shared tile always uses the foreground colour.
  /// Kept so existing callers still compile.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return AppBackButton(onTap: onPressed, tooltip: label);
  }
}
