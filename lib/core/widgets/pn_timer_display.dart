import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PNTimerDisplay extends StatelessWidget {
  final int seconds;
  final double fontSize;
  final bool showLabel;
  final Color? color;

  const PNTimerDisplay({
    super.key,
    required this.seconds,
    this.fontSize = 48,
    this.showLabel = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final isLow = seconds < 60;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Text('REMAINING', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2, color: color?.withValues(alpha: 0.7) ?? AppColors.textSecondary)),
          const SizedBox(height: 4),
        ],
        Text(
          timeStr,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: color ?? (isLow ? AppColors.red : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class PNBlindsDisplay extends StatelessWidget {
  final int smallBlind;
  final int bigBlind;
  final int ante;
  final double fontSize;

  const PNBlindsDisplay({
    super.key,
    required this.smallBlind,
    required this.bigBlind,
    this.ante = 0,
    this.fontSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$smallBlind/$bigBlind', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: AppColors.accent)),
        if (ante > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('ANTE $ante', style: TextStyle(fontSize: fontSize * 0.5, fontWeight: FontWeight.w600, color: AppColors.gold)),
          ),
        ],
      ],
    );
  }
}
