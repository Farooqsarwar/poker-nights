import 'package:flutter/material.dart';

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
    context.go(RoutePaths.join);
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
    final isMobile = AppBreakpoints.deviceOf(context).isMobile;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppSpacing.lg : AppSpacing.xxl,
        vertical: AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairlineWhite)),
      ),
      child: Row(
        children: [
          const PokerNightLogo(size: 40),
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
              ),
              Text(
                'poker night',
                textAlign: TextAlign.center,
                style: AppTypography.crimsonShimmer(size: headingSize),
              ),
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
              ),
              const SizedBox(height: AppSpacing.xl),
              // Main CTA
              AppButton(
                variant: AppButtonVariant.primary,
                size: AppButtonSize.xl,
                onPressed: _joinAsGuest,
                child: const Text('Join a game as guest'),
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  AppButton(
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.md,
                    onPressed: () => context.go(RoutePaths.register),
                    child: const Text('Create free account'),
                  ),
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
        ],
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
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
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
