import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';

/// "Have an account? **Sign in**" — a muted prompt followed by a crimson
/// text action, as used at the foot of every onboarding screen.
///
/// A [Wrap], not a Row: both halves are unbounded text and the pair is wider
/// than a 320px phone's content width, so the action drops to its own line
/// there instead of overflowing. The action keeps a 44px-tall tap target.
class PromptLink extends StatelessWidget {
  const PromptLink({
    super.key,
    this.prompt,
    required this.action,
    required this.onTap,
    this.bold = true,
  });

  final String? prompt;
  final String action;
  final VoidCallback onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (prompt != null)
          Text(
            prompt!,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Text(
              action,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.primaryText,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
