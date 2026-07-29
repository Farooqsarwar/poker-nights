import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PNCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;

  const PNCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );

    content = Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderDark,
          width: 1.5,
        ),
      ),
      child: content,
    );

    if (onTap != null) {
      return Padding(
        padding: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: AppColors.accent.withValues(alpha: 0.1),
            highlightColor: AppColors.accent.withValues(alpha: 0.05),
            child: content,
          ),
        ),
      );
    }

    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: content,
    );
  }
}
