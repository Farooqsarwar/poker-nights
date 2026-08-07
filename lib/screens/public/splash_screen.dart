import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';

/// Splash shown on cold start (mirrors web splash overlay, ~2s).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) context.go(RoutePaths.landing);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                boxShadow: AppShadows.cardGlowActive,
              ),
              child: const Icon(
                Icons.style,
                size: 56,
                color: AppColors.primary,
              ),
            )
                .animate()
                .scaleXY(begin: 0.6, end: 1, duration: 500.ms, curve: Curves.easeOutBack)
                .fadeIn(duration: 400.ms),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'POKER NIGHT',
              style: AppTypography.crimsonShimmer(
                size: AppFontSizes.xxxl,
                weight: FontWeight.w700,
              ).copyWith(letterSpacing: 3),
            )
                .animate()
                .fadeIn(delay: 250.ms, duration: 500.ms)
                .slideY(begin: 0.4, end: 0, curve: Curves.easeOut),
          ],
        ),
      ),
    );
  }
}
