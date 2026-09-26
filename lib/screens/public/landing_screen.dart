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
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.only(
        left: isMobile ? AppSpacing.lg : AppSpacing.xxl,
        right: isMobile ? AppSpacing.lg : AppSpacing.xxl,
        // Absorb the status-bar inset so content sits below it,
        // while the background bleeds all the way to the top edge.
        top: statusBarHeight + (isMobile ? AppSpacing.sm : AppSpacing.lg),
        bottom: isMobile ? AppSpacing.sm : AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairlineWhite)),
      ),
      child: Row(
        children: [
<<<<<<< Updated upstream
          const PokerNightLogo(size: 40),
          const Spacer(),
          AppButton(
            variant: AppButtonVariant.secondary,
=======
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD53032),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55D53032),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    '♠',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
                // A hard-coded font size on the wordmark did not shrink with
                // a scaled-up device text setting the way the rest of the
                // header (buttons, spacing) implicitly does via AppScale.sp,
                // so a larger text-scale factor could make this the widest
                // element in the row while everything else stayed put. Below
                // this app's 390px design floor, `AppScale.sp` never shrinks
                // text further (by design — see AppScale.minSizeScale's
                // doc), so at a 320px phone the two auth buttons alone
                // already claim nearly the whole header width; the wordmark
                // is decorative branding text, not a control, so it is the
                // one thing safe to drop rather than force a RenderFlex
                // overflow nothing can actually see anyway.
                if (!isMobile) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Poker Night',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: AppTypography.display(
                        size: 17,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF161618),
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF28282C)),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 14,
                vertical: 8,
              ),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
>>>>>>> Stashed changes
            onPressed: () => context.go(RoutePaths.login),
            child: const Text('Sign in'),
          ),
<<<<<<< Updated upstream
          const SizedBox(width: AppSpacing.md),
          AppButton(
            variant: AppButtonVariant.primary,
            size: AppButtonSize.sm,
=======
          SizedBox(width: isMobile ? 4 : 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD53032),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 14,
                vertical: 8,
              ),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
>>>>>>> Stashed changes
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
            vertical: isDesktop ? AppSpacing.huge : AppSpacing.xl,
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
                  'One admin, one app. Tournament structure generated from your real chips. Timer, blinds, seating and prizes — handled.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyStyle.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
<<<<<<< Updated upstream
              const SizedBox(height: AppSpacing.xl),

              // Feature pills
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
=======
              const SizedBox(height: 20),
              // Feature pills. A fixed two-per-row Row (not a Wrap) forced
              // every pill to keep its natural, unshrinkable text width even
              // when the hero's own padding left under 300px to work with at
              // a phone width — the pair simply didn't fit and overflowed.
              // Wrap reflows to one per row on its own with no breakpoint
              // logic needed.
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FeaturePill(label: 'AUTO BLIND STRUCTURE'),
                  _FeaturePill(label: 'LIVE TIMER'),
                  _FeaturePill(label: 'SEATING & REDRAWS'),
                  _FeaturePill(label: 'TV MODE'),
                  _FeaturePill(label: 'CASH GAME TRACKER'),
                  _FeaturePill(label: 'GROUP CHAT'),
                ],
              ),
              const SizedBox(height: 24),
              // Two buttons side by side in a row!
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66D53032),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD53032),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => context.go(RoutePaths.register),
                        child: const Text(
                          'Create account',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFF161618),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF28282C)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _openJoin,
                        child: const Text(
                          'Join with a code',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Free for up to 9 players. No card, nothing to install.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9A9AA6), fontSize: 11),
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: const Color(0xFF1E1E22)),
              const SizedBox(height: 20),
              const Text(
                'Runs in any browser today',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Host, player and TV views all open from a link — nothing to download.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9A9AA6), fontSize: 11),
              ),
              const SizedBox(height: 16),
              Row(
>>>>>>> Stashed changes
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
        vertical: isDesktop ? AppSpacing.huge : AppSpacing.xl,
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
              for (final l in [
                'Free Tools',
                'Privacy Policy',
                'Terms of Service',
                'Support',
              ])
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.lg),
                  child: InkWell(
                    onTap: () {
                      if (l == 'Free Tools') {
                        context.go(RoutePaths.tools);
                      } else if (l == 'Privacy Policy') {
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
                        vertical: 12.0,
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
<<<<<<< Updated upstream
        label,
        style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
=======
        label.toUpperCase(),
        style: AppTypography.bodyXs.copyWith(
          color: AppColors.mutedForeground,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.body,
  });

  final String step;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            step,
            style: AppTypography.display(
              size: AppFontSizes.xxl,
              weight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTypography.bodyStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
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

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    required this.phase,
    required this.headline,
    required this.items,
  });

  final String phase;
  final String headline;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.primarySoftBorder),
            ),
            child: Text(
              phase.toUpperCase(),
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.primaryText,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            headline,
            style: AppTypography.bodyStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.check,
                      size: 14,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: AppColors.primaryText),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Open →',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsed by default: a wall of open answers buries the questions, and the
/// point of an FAQ is that somebody can find THEIR question quickly.
class _FaqItem extends StatefulWidget {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: () => setState(() => _open = !_open),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  _open ? Icons.remove : Icons.add,
                  size: 18,
                  color: AppColors.mutedForeground,
                ),
              ],
            ),
            if (_open) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.answer,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A store badge for an app that does not exist yet.
///
/// Shaped like the real thing — platform mark, small line over a larger
/// wordmark — so the section reads as a proper download row rather than an
/// apology. But it is deliberately INERT and says "Coming soon" where the
/// real badge says "Download on the": a badge that goes nowhere, or implies a
/// store listing that is not there, is the one landing-page claim that costs
/// real trust rather than just polish.
///
/// NOTE FOR LAUNCH: Apple's and Google's official badges are trademarked
/// artwork governed by their brand guidelines (fixed proportions, clear
/// space, approved wording). These are Material's platform glyphs standing in
/// for them. Replace with the official assets when the apps actually ship.
class _StoreBadge extends StatelessWidget {
  const _StoreBadge({required this.icon, required this.store});

  final IconData icon;
  final String store;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.75,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        // This half of the hero's two-badge row is only ~180px wide (two
        // Expanded children splitting a 520px-capped hero minus the gap and
        // padding), and the icon + label column previously had nothing
        // shrinkable in it — `mainAxisSize: min` only stops the Row from
        // growing past its content, it does not let content shrink to fit a
        // tighter parent. `Flexible` + ellipsis on the label column gives it
        // somewhere to give before the Row overflows.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: AppColors.foreground),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Coming soon',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.onSurfaceHint,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    store,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
>>>>>>> Stashed changes
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
