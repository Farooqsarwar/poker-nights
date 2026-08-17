import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../widgets/brand_lockup.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Controls the complete splash animation.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000), // Very slow and smooth
    );

    // Smoothly grows the logo from completely small to full size.
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.0,
          0.85,
          curve: Curves.easeOutBack,
        ),
      ),
    );

    // Smooth fade-in.
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.0,
          0.60,
          curve: Curves.easeOut,
        ),
      ),
    );

    _controller.forward();

    // Navigate after animation completes.
    _timer = Timer(const Duration(milliseconds: 5500), () {
      if (mounted) {
        context.go(RoutePaths.landing);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SizedBox.expand(
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              child: const PokerNightLogo(
                size: 160,
              ),
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    alignment: Alignment.center,
                    child: child,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}