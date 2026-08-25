import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';

/// Poker chip mirroring the web `Chip` component.
class ChipToken extends StatelessWidget {
  const ChipToken({
    super.key,
    required this.colorName,
    required this.hex,
    required this.value,
    this.count,
  });

  final String colorName;
  final Color hex;
  final int value;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final label = value >= 1000
        ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K'
        : '$value';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hex,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowDark,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                label,
                style:
                    AppTypography.mono(
                      size: 9,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ).copyWith(
                      shadows: [
                        Shadow(
                          color: AppColors.shadowDeep,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              colorName,
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
        if (count != null)
          Text(
            '×$count',
            style: AppTypography.monoXs.copyWith(color: AppColors.foreground),
          ),
      ],
    );
  }
}
