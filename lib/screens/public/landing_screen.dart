import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../responsive/responsive.dart';
import '../../widgets/app_button.dart';
import '../../widgets/backgrounds.dart';
import '../../widgets/brand_lockup.dart';

/// Public landing page mirroring the web `LandingPage`.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  void _joinAsGuest() {
    context.go('/join');
  }

  @override
  Widget build(BuildContext context) {
    final device = AppBreakpoints.deviceOf(context);
    final isDesktop = device.isDesktop || device.isLargeDesktop;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FeltBackground(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              _buildHero(context, isDesktop),
              _buildFeatures(context, isDesktop),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairlineWhite)),
      ),
      child: Row(
        children: [
          const BrandLockup(),
          const Spacer(),
          AppButton(
            variant: AppButtonVariant.secondary,
            onPressed: () => context.go(RoutePaths.login),
            child: const Text('Sign in'),
          ),
          const SizedBox(width: AppSpacing.md),
          AppButton(
            variant: AppButtonVariant.primary,
            size: AppButtonSize.sm,
            onPressed: () => context.go(RoutePaths.register),
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, bool isDesktop) {
    final headingSize = isDesktop ? 48.0 : 32.0;
    return Stack(
      children: [
        // Decorative suits
        Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              children: [
                // Pulsing Background Glow
                Positioned(
                  top: -200,
                  right: -150,
                  child: Container(
                    width: 700,
                    height: 700,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [AppColors.primary.withValues(alpha: 0.15), Colors.transparent],
                      ),
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .scaleXY(begin: 1.0, end: 1.15, duration: 4.seconds, curve: Curves.easeInOut),
                ),
                // Spinning Wheel / Rays effect
                Positioned(
                  top: -150,
                  right: -150,
                  child: _SpinningRays(),
                ),
                _AnimatedSuit('♠', const Alignment(0, 0), 0.1, 0),
                _AnimatedSuit('♥', const Alignment(1, -0.8), 0.25, 200),
                _AnimatedSuit('♦', const Alignment(-1, 0.2), 0.15, 400),
                _AnimatedSuit('♣', const Alignment(-0.4, 1.1), 0.2, 600),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? AppSpacing.xxxl : AppSpacing.lg,
            vertical: AppSpacing.huge,
          ),
          child: Column(
            children: [
              // Eyebrow
              Row(
                children: [
                  Expanded(
                    child: Container(height: 1, color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Text(
                      'PRIVATE HOME POKER',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(height: 1, color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // Heading
              Text(
                'Run your best',
                textAlign: TextAlign.center,
                style: AppTypography.display(
                  size: headingSize,
                  weight: FontWeight.w700,
                  height: 1.15,
                ),
              ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.2, curve: Curves.easeOutBack),
              Text(
                'poker night',
                textAlign: TextAlign.center,
                style: AppTypography.crimsonShimmer(size: headingSize),
              ).animate().fadeIn(delay: 200.ms, duration: 800.ms).scale(begin: const Offset(0.9, 0.9)),
              const SizedBox(height: AppSpacing.lg),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Text(
                  'One host, one app. Tournament structure generated from your real chips. Timer, blinds, seating and prizes — handled.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyStyle.copyWith(color: AppColors.mutedForeground),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Feature pills
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: const [
                  'Auto blind structure',
                  'Live timer',
                  'Seating & redraws',
                  'TV mode',
                  'Cash game tracker',
                  'Group chat',
                ].map((f) => _FeaturePill(label: f)).toList(),
              ).animate().fadeIn(delay: 200.ms, duration: 800.ms).slideY(begin: 0.2),
              const SizedBox(height: AppSpacing.xl),
              // Main CTA
              AppButton(
                variant: AppButtonVariant.primary,
                size: AppButtonSize.xl,
                onPressed: _joinAsGuest,
                child: const Text('Join a game as guest'),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppButton(
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.md,
                    onPressed: () => context.go(RoutePaths.register),
                    child: const Text('Create free account'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppButton(
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.md,
                    onPressed: () => context.go(RoutePaths.login),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatures(BuildContext context, bool isDesktop) {
    final features = [
      (Icons.casino_outlined, 'Smart tournament engine',
          'Enter your chip set and target duration — Poker Night works out stack sizes, blind levels and payouts that actually fit.'),
      (Icons.tv_outlined, 'TV mode & voice',
          'Open the TV page on any browser. Clean full-screen timer with voice announcements for level changes and eliminations.'),
      (Icons.groups_outlined, 'Group management',
          'Private group with RSVP, chat, polls and game history. Guests join with a code — no account required.'),
    ];
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? AppSpacing.xxxl : AppSpacing.lg,
        vertical: AppSpacing.huge,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairlineWhite)),
      ),
      child: Wrap(
        spacing: AppSpacing.xxl,
        runSpacing: AppSpacing.xxl,
        alignment: WrapAlignment.center,
        children: [
          for (final (icon, title, body) in features)
            SizedBox(
              width: isDesktop ? 360 : double.infinity,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: AppFontSizes.xxxl, color: AppColors.icon),
                    const SizedBox(height: AppSpacing.md),
                    Text(title, style: AppTypography.display(size: AppFontSizes.lg)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(body, style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
                  ],
                ),
              ),
            ),
        ].animate(interval: 100.ms).fadeIn(duration: 600.ms).slideY(begin: 0.1),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairlineWhite)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        children: [
          const Text('© 2026 Poker Night. All rights reserved.',
              style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.mutedForeground)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final l in ['Privacy Policy', 'Terms of Service', 'Support'])
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.lg),
                  child: InkWell(
                    onTap: () {
                      if (l == 'Privacy Policy') {
                        context.go(RoutePaths.privacy);
                      } else if (l == 'Terms of Service') {
                        context.go(RoutePaths.terms);
                      } else {
                        context.go(RoutePaths.support);
                      }
                    },
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                      child: Text(
                        l,
                        style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedSuit extends StatefulWidget {
  const _AnimatedSuit(this.suit, this.alignment, this.opacity, this.delayMs);

  final String suit;
  final Alignment alignment;
  final double opacity;
  final int delayMs;

  @override
  State<_AnimatedSuit> createState() => _AnimatedSuitState();
}

class _AnimatedSuitState extends State<_AnimatedSuit> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _controller.repeat();
      });
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.alignment,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: FadeTransition(
          opacity: TweenSequence<double>([
            TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 20),
            TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
            TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 20),
          ]).animate(_controller),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.4), end: const Offset(0, -0.4)).animate(
              CurvedAnimation(parent: _controller, curve: Curves.linear),
            ),
            child: RotationTransition(
              turns: Tween(begin: 0.0, end: 0.2).animate(
                CurvedAnimation(parent: _controller, curve: Curves.linear),
              ),
              child: Text(
                widget.suit,
                style: AppTypography.display(
                  size: 120,
                  weight: FontWeight.w700,
                  color: AppColors.foreground.withValues(alpha: widget.opacity * 0.4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpinningRays extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 700,
      height: 700,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(12, (index) {
          return Transform.rotate(
            angle: (index * 3.14159) / 6,
            child: Container(
              height: 700,
              width: 12,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.0),
                    AppColors.primary.withValues(alpha: 0.06),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .rotate(duration: 40.seconds, curve: Curves.linear);
  }
}

class _FeaturePill extends StatefulWidget {
  const _FeaturePill({required this.label});

  final String label;

  @override
  State<_FeaturePill> createState() => _FeaturePillState();
}

class _FeaturePillState extends State<_FeaturePill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.identity()
          ..scaleByDouble(_hover ? 1.03 : 1.0, _hover ? 1.03 : 1.0, _hover ? 1.03 : 1.0, 1.0),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: _hover ? 0.7 : 0.5),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.border),
          boxShadow: _hover
              ? [BoxShadow(color: AppColors.shadowSoft, blurRadius: 10, offset: Offset(0, 4))]
              : null,
        ),
        child: Text(
          widget.label,
          style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
        ),
      ),
    );
  }
}
