import 'package:flutter/material.dart';

import '../app/colors.dart';

/// Squircle icon button matching the mobile-first redesign.
///
/// Features a 44x44 rounded container with subtle border, dark background,
/// and smooth ink response.
class SquircleIconButton extends StatelessWidget {
  const SquircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
    this.tooltip,
    this.size = 44,
    this.iconSize = 22,
    this.borderRadius = 14,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final String? tooltip;
  final double size;
  final double iconSize;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? AppColors.muted;
    final effectiveBorder = borderColor ?? AppColors.borderSubtle;
    final effectiveIconColor = iconColor ?? AppColors.foreground;

    Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: effectiveBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: iconSize, color: effectiveIconColor),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return Semantics(button: true, label: tooltip ?? 'Button', child: button);
  }
}
