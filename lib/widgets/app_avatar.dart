import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';

enum AppAvatarSize { sm, md, lg }

/// Member initial in the redesign's tinted style: a soft disc of the member's
/// hue with the initial in a lifted tone of the same hue. The hue is picked
/// from the name, so a member keeps their colour on every screen.
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
    final tint = AppColors.avatarTintFor(name);

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: Color.lerp(AppColors.card, tint, 0.22),
        shape: BoxShape.circle,
        border: Border.all(color: tint.withValues(alpha: 0.30)),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTypography.body(
          size: fontSize,
          weight: FontWeight.w700,
          color: Color.lerp(tint, AppColors.foreground, 0.35),
          height: 1.0,
        ),
      ),
    );
  }
}
