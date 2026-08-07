import 'package:flutter/material.dart';

import '../app/colors.dart';

/// Solid trophy/medal icon for a placement, using the app's light-red icon
/// color so no emoji are needed in results.
class MedalIcon extends StatelessWidget {
  const MedalIcon(
    this.place, {
    super.key,
    this.size = 24,
    this.color = AppColors.icon,
  });

  final int place;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (place) {
      1 => Icons.emoji_events,
      2 => Icons.military_tech,
      _ => Icons.workspace_premium,
    };
    return Icon(icon, size: size, color: color);
  }
}
