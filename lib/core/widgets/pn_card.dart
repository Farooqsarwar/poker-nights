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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 451;
    final defaultPadding = isMobile ? 16.0 : 20.0;
    final defaultHMargin = isMobile ? 8.0 : 16.0;
    final defaultVMargin = isMobile ? 6.0 : 8.0;

    Widget content = Padding(
      padding: padding ?? EdgeInsets.all(defaultPadding),
      child: child,
    );

    content = Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.cardDark,
        borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
        border: Border.all(
          color: AppColors.borderDark,
          width: 1.5,
        ),
      ),
      child: content,
    );

    if (onTap != null) {
      return Padding(
        padding: margin ?? EdgeInsets.symmetric(horizontal: defaultHMargin, vertical: defaultVMargin),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
            splashColor: AppColors.accent.withValues(alpha: 0.1),
            highlightColor: AppColors.accent.withValues(alpha: 0.05),
            child: content,
          ),
        ),
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.symmetric(horizontal: defaultHMargin, vertical: defaultVMargin),
      child: content,
    );
  }
}
