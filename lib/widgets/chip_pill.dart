import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../responsive/responsive.dart';
import 'glass_styles.dart';

/// The compact chip denomination pill from the client's component sheet:
/// a fully-rounded capsule holding `● Red · 20`.
///
/// This is deliberately NOT a replacement for [ChipToken]. They look similar on
/// paper and are different components:
///
///  - [ChipToken] is a full-width list ROW — a 32px filled circle with the
///    denomination written inside it, the colour name beside it, and an
///    optional `×count` pushed to the far edge. It is the right thing in the
///    chip-set editor, where each row is an editable line item.
///  - [ChipPill] is an inline TAG. It has no intrinsic width beyond its
///    content, so it wraps in a `Wrap`, sits in a summary line, or trails a
///    heading. Use it wherever the sheet shows chips as metadata rather than as
///    a list.
///
/// Shape follows the same rule as [AppBadge]: data is fully rounded, actions
/// are [AppRadius.md].
class ChipPill extends StatelessWidget {
  const ChipPill({
    super.key,
    required this.colorName,
    required this.hex,
    required this.value,
    this.count,
  });

  /// e.g. "Red". Rendered before the denomination.
  final String colorName;

  /// The chip's own colour — shown as the leading dot.
  final Color hex;

  /// The denomination. Abbreviated over 1000, matching [ChipToken].
  final int value;

  /// Optional multiplier, rendered as `×N` after the denomination.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final denomination = value >= 1000
        ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K'
        : '$value';
    final label = count == null
        ? '$colorName · $denomination'
        : '$colorName · $denomination ×$count';

    final dot = AppScale.sp(8);

    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Glass.solidTint(AppColors.secondary),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: hex,
                shape: BoxShape.circle,
                // The dark chip colours (blue, black) would otherwise vanish
                // against the pill's own dark fill.
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.30),
                  width: 1,
                ),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Text(
              colorName,
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            Text(
              '·',
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.border,
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            Text(
              denomination,
              style: AppTypography.monoXs.copyWith(
                color: AppColors.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (count != null) ...[
              SizedBox(width: AppSpacing.xs),
              Text(
                '×$count',
                style: AppTypography.monoXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
