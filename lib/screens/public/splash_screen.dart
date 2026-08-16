import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../widgets/brand_lockup.dart';

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
        child: const PokerNightLogo(
          size: 160,
          showWordmark: true,
        )
            .animate()
            .scaleXY(begin: 0.8, end: 1, duration: 500.ms, curve: Curves.easeOutBack)
            .fadeIn(duration: 400.ms),
      ),
    );
  }
}
