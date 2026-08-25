import 'package:flutter/material.dart';

import '../app/colors.dart';

/// Felt background mirroring `.felt-bg` from the web app.
class FeltBackground extends StatelessWidget {
  const FeltBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        gradient: RadialGradient(
          radius: 1.2,
          colors: [AppColors.blackGlow, AppColors.background],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, 0),
            radius: 1.6,
            colors: [AppColors.feltGlow, Colors.transparent],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// TV display background mirroring `.tv-bg` (pure black + top crimson glow).
class TVBackground extends StatelessWidget {
  const TVBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.black,
        gradient: RadialGradient(
          center: Alignment(0, -0.9),
          radius: 1.4,
          colors: [AppColors.feltGlowStrong, Colors.transparent],
        ),
      ),
      child: child,
    );
  }
}
