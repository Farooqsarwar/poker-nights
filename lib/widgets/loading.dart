import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';

enum AppLoaderSize { sm, md, lg }

/// Spinner mirroring the web `LoadingSpinner` component.
class LoadingSpinner extends StatelessWidget {
  const LoadingSpinner({super.key, this.size = AppLoaderSize.md});

  final AppLoaderSize size;

  @override
  Widget build(BuildContext context) {
    final value = switch (size) {
      AppLoaderSize.sm => 16.0,
      AppLoaderSize.md => 24.0,
      AppLoaderSize.lg => 40.0,
    };
    return SizedBox(
      width: value,
      height: value,
      child: const CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.primary,
        backgroundColor: AppColors.border,
      ),
    );
  }
}

/// Full-viewport loading state used during async transitions.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LoadingSpinner(size: AppLoaderSize.lg),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(message!, style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
          ],
        ],
      ),
    );
  }
}
