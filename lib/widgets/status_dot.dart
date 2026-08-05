import 'package:flutter/material.dart';

import '../app/colors.dart';

enum AppStatus { online, offline, warning }

/// Small colored dot mirroring the web `StatusDot` component.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.status, this.size = 8});

  final AppStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AppStatus.online => AppColors.success,
      AppStatus.offline => AppColors.destructive,
      AppStatus.warning => AppColors.warning,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
