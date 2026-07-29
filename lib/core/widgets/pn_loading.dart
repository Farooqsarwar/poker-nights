import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PNLoading extends StatelessWidget {
  final String? message;

  const PNLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.accent),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ],
      ),
    );
  }
}

class PNPulseLoading extends StatelessWidget {
  final double size;

  const PNPulseLoading({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(strokeWidth: 3, color: AppColors.accent),
      ),
    );
  }
}
