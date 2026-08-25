import 'package:flutter/material.dart';

import '../app/colors.dart';

/// Felt background mirroring `.felt-bg` from the web app — with richer ambient glow.
///
/// Three layered gradients create depth:
/// 1. Base background color.
/// 2. Dark vignette from edges (black glow).
/// 3. Warm primary-tinted radial from top-left for premium ambience.
/// 4. Subtle center felt glow.
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
            center: const Alignment(-0.85, -0.85),
            radius: 1.4,
            colors: [
              AppColors.primary.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, 0),
              radius: 1.6,
              colors: [AppColors.feltGlow, Colors.transparent],
            ),
          ),
          child: child,
        ),
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
          center: const Alignment(0, -0.9),
          radius: 1.4,
          colors: [
            AppColors.feltGlowStrong,
            AppColors.primary.withValues(alpha: 0.04),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}
