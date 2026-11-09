import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';

/// The redesign's small tracked-capitals label: a section kicker
/// ("PRIVATE HOME POKER") or a field label ("GAME CODE").
///
/// Crimson by default; [muted] gives the quieter grey used for field labels
/// inside cards. The text is uppercased here so callers pass natural copy.
class AppEyebrow extends StatelessWidget {
  const AppEyebrow(
    this.text, {
    super.key,
    this.muted = false,
    this.color,
    this.textAlign,
    this.size = 11,
  });

  final String text;
  final bool muted;
  final Color? color;
  final TextAlign? textAlign;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: textAlign,
      style: AppTypography.eyebrow(
        size: size,
        color: color ?? (muted ? AppColors.mutedForeground : null),
      ),
    );
  }
}
