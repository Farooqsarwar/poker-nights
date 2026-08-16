import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../utils/formatters.dart';

/// The SB / ANTE / BB trio shown under the live timer (mirrors the TV
/// dashboard). The middle value (ANTE) is drawn in the accent color.
class BlindsTrio extends StatelessWidget {
  const BlindsTrio({
    super.key,
    required this.sb,
    required this.bb,
    this.ante,
    this.valueSize = AppFontSizes.display,
  });

  final int? sb;
  final int? bb;
  final int? ante;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          _TrioStat(
            label: 'SB',
            value: sb == null ? '—' : Formatters.chips(sb!),
            emphasized: false,
            valueSize: valueSize,
          ),
          const SizedBox(width: AppSpacing.xxxl * 2),
          _TrioStat(
            label: 'ANTE',
            value: ante == null ? '—' : Formatters.chips(ante!),
            emphasized: true,
            valueSize: valueSize,
          ),
          const SizedBox(width: AppSpacing.xxxl * 2),
          _TrioStat(
            label: 'BB',
            value: bb == null ? '—' : Formatters.chips(bb!),
            emphasized: false,
            valueSize: valueSize,
          ),
        ],
      ),
    );
  }
}

class _TrioStat extends StatelessWidget {
  const _TrioStat({
    required this.label,
    required this.value,
    required this.emphasized,
    required this.valueSize,
  });

  final String label;
  final String value;
  final bool emphasized;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.mono(
            size: AppFontSizes.sm,
            weight: FontWeight.w600,
            color: emphasized ? AppColors.primary : AppColors.mutedForeground,
          ).copyWith(letterSpacing: 2),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          value,
          style: AppTypography.mono(
            size: valueSize,
            weight: FontWeight.w700,
            color: emphasized ? AppColors.primary : AppColors.foreground,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
