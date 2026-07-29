import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PNAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;

  const PNAvatar({super.key, required this.name, this.imageUrl, this.size = 40});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(imageUrl!),
        onBackgroundImageError: (_, _) {},
      );
    }
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final colors = [AppColors.accent, AppColors.blue, AppColors.green, AppColors.gold, AppColors.purple];
    final color = colors[name.length % colors.length];

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Text(initials, style: TextStyle(fontSize: size * 0.45, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
