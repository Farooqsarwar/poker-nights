import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';

enum AppAvatarSize { sm, md, lg }

/// Avatar mirroring the web `Avatar` component.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.size = AppAvatarSize.md,
  });

  final String name;
  final AppAvatarSize size;

  @override
  Widget build(BuildContext context) {
    final (diameter, fontSize) = switch (size) {
      AppAvatarSize.sm => (28.0, AppFontSizes.xs),
      AppAvatarSize.md => (36.0, AppFontSizes.sm),
      AppAvatarSize.lg => (44.0, AppFontSizes.md),
    };
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: AppColors.avatarColorFor(name),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTypography.body(
          size: fontSize,
          weight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
