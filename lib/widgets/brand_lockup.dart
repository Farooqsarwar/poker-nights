import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';

/// Brand block used across public screens.
///
/// Two variants:
///  - Horizontal (default): ♠ + shimmering "Poker Night" in a [Row].
///  - Vertical ([vertical] = true): a dark circular badge with a red card
///    glyph above a bold, widely-spaced white "POKER NIGHT" wordmark, matching
///    the client's reference design.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.suitSize = AppFontSizes.xxl,
    this.textSize = AppFontSizes.xl,
    this.vertical = false,
    this.iconCircleSize,
  });

  final double suitSize;
  final double textSize;

  /// When true, renders the stacked (vertical) brand lockup.
  final bool vertical;

  /// Diameter of the circular badge in the vertical variant. Defaults to 120.
  final double? iconCircleSize;

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return _buildVertical();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.style, size: suitSize * 1.3, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Poker Night',
          style: AppTypography.crimsonShimmer(size: textSize),
        ),
      ],
    );
  }

  Widget _buildVertical() {
    final double circleSize = iconCircleSize ?? 120;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: circleSize,
          height: circleSize,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.card,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.style,
            size: circleSize * 0.65,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'POKER NIGHT',
          style: AppTypography.display(size: textSize).copyWith(
            letterSpacing: textSize * 0.35,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
      ],
    );
  }
}
