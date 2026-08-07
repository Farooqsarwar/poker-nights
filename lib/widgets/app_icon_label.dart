import 'package:flutter/material.dart';

import '../app/colors.dart';

/// A compact label for buttons, optionally with a leading and/or trailing
/// solid icon in the app's light-red color.
class AppIconLabel extends StatelessWidget {
  const AppIconLabel({
    super.key,
    required this.label,
    this.icon,
    this.trailing,
    this.iconSize = 14,
    this.color = AppColors.icon,
    this.textStyle,
  });

  final String label;
  final IconData? icon;
  final IconData? trailing;
  final double iconSize;
  final Color color;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 6),
        ],
        Text(label, style: textStyle),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          Icon(trailing, size: iconSize, color: color),
        ],
      ],
    );
  }
}
