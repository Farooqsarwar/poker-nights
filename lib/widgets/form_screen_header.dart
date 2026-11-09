import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import 'app_eyebrow.dart';

/// Title block for full-screen forms and flows: optional eyebrow, optional
/// leading tile, a large title and a muted helper line.
///
/// Left-aligned for the auth screens (A3–A5); [centered] with a leading
/// [IconTile] for the join / guest / invite screens (A6–A8).
class FormScreenHeader extends StatelessWidget {
  const FormScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.leading,
    this.centered = false,
    this.titleSize = 28,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? leading;
  final bool centered;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final align = centered ? TextAlign.center : TextAlign.start;
    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          AppEyebrow(eyebrow!, textAlign: align),
          const SizedBox(height: AppSpacing.md),
        ],
        if (leading != null) ...[
          leading!,
          const SizedBox(height: AppSpacing.lg),
        ],
        Text(
          title,
          textAlign: align,
          style: AppTypography.display(
            size: titleSize,
            weight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -0.6,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle!,
            textAlign: align,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }
}
