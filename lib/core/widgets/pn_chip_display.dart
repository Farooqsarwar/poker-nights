import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PNChipDisplay extends StatelessWidget {
  final String colorName;
  final int value;
  final int quantity;
  final bool showValue;
  final double chipSize;

  const PNChipDisplay({
    super.key,
    required this.colorName,
    required this.value,
    required this.quantity,
    this.showValue = true,
    this.chipSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = AppColors.chipColor(colorName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: chipSize,
            height: chipSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: chipColor,
              border: Border.all(color: chipColor == AppColors.chipWhite ? AppColors.textSecondary.withValues(alpha: 0.3) : chipColor.withValues(alpha: 1.5), width: 2),
              boxShadow: [BoxShadow(color: chipColor.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Center(
              child: Text(
                value.toString(),
                style: TextStyle(
                  fontSize: chipSize * 0.35,
                  fontWeight: FontWeight.bold,
                  color: chipColor == AppColors.chipWhite || chipColor == AppColors.chipYellow ? AppColors.textPrimary : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(colorName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              if (showValue)
                Text('x$quantity', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class PNChipSetSummary extends StatelessWidget {
  final List<Map<String, dynamic>> chips;

  const PNChipSetSummary({super.key, required this.chips});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((c) => PNChipDisplay(
        colorName: c['colorName'] as String,
        value: c['value'] as int,
        quantity: c['quantity'] as int,
      )).toList(),
    );
  }
}
