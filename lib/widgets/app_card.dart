import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import 'interactive_scale.dart';

/// Card mirroring the web `Card` component with optional glow / tap.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.glow = false,
    this.onTap,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.radius = AppRadius.md,
  });

  final Widget child;
  final bool glow;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return InteractiveScale(
      enabled: onTap != null,
      scaleDown: 0.98,
      child: Material(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          highlightColor: onTap != null ? AppColors.surfaceHover : Colors.transparent,
          splashColor: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              color: color ?? AppColors.card,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor ?? AppColors.border),
              boxShadow: glow ? AppShadows.cardGlowActive : AppShadows.cardGlow,
            ),
            child: margin != null
                ? Padding(padding: margin!, child: padding != null ? Padding(padding: padding!, child: child) : child)
                : padding != null
                    ? Padding(padding: padding!, child: child)
                    : child,
          ),
        ),
      ),
    );
  }
}
