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
  void _openJoin() {
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
      decoration: BoxDecoration(
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
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
                    child: Container(
                      height: 1,
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Text(
                      'PRIVATE HOME POKER',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
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
                  style: AppTypography.bodyStyle.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Feature pills
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: const [
                  _FeaturePill(label: 'Auto blind structure'),
                  _FeaturePill(label: 'Live timer'),
                  _FeaturePill(label: 'Seating & redraws'),
                  _FeaturePill(label: 'TV mode'),
                  _FeaturePill(label: 'Cash game tracker'),
                  _FeaturePill(label: 'Group chat'),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Main CTA (Size decreased to small)
              AppButton(
                variant: AppButtonVariant.primary,
                size: AppButtonSize.sm,
                onPressed: _openJoin,
                child: const Text('Join with a code'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatures(BuildContext context, bool isDesktop) {
    final features = [
      (
        Icons.casino_outlined,
        'Smart tournament engine',
        'Enter your chip set and target duration — Poker Night works out stack sizes, blind levels and payouts that actually fit.',
      ),
      (
        Icons.tv_outlined,
        'TV mode & voice',
        'Open the TV page on any browser. Clean full-screen timer with voice announcements for level changes and eliminations.',
      ),
      (
        Icons.groups_outlined,
        'Group management',
        'Private group with RSVP, chat, polls and game history. Guests join with a code — no account required.',
      ),
    ];

    // Build standard feature cards
    final cards = features
        .map((f) => _FeatureCard(icon: f.$1, title: f.$2, body: f.$3))
        .toList();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? AppSpacing.xxxl : AppSpacing.lg,
        vertical: AppSpacing.huge,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairlineWhite)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1100,
          ), // Prevent stretching on ultra-wide screens
          child: isDesktop
              // Desktop: Row with IntrinsicHeight ensures all cards stretch to match the tallest one
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        Expanded(child: cards[i]),
                        if (i != cards.length - 1)
                          const SizedBox(width: AppSpacing.xxl),
                      ],
                    ],
                  ),
                )
              // Mobile: Standard stacked column
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      cards[i],
                      if (i != cards.length - 1)
                        const SizedBox(height: AppSpacing.xl),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairlineWhite)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        children: [
          Text(
            '© 2026 Poker Night. All rights reserved.',
            style: TextStyle(
              fontSize: AppFontSizes.xs,
              color: AppColors.mutedForeground,
            ),
          ),
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
                      padding: const EdgeInsets.symmetric(
                        vertical: 6.0,
                        horizontal: 8.0,
                      ),
                      child: Text(
                        l,
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
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

// -----------------------------------------------------------------------------
// Helper Widgets
// -----------------------------------------------------------------------------

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            body,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
