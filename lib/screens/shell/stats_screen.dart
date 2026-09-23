import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_page.dart';
import '../../services/entitlements.dart';
import '../../widgets/premium_gate.dart';

/// Detailed statistics mirroring the account area of the web app.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.user;

    // Addendum §3: "Advanced statistics, analytics, history and exports" are
    // Premium. Basic group history (games played, wins, podiums) stays free
    // and lives on the history screen -- this is the analytics view.
    if (user != null &&
        !Entitlements.allows(app.premiumTier, PremiumFeature.advancedStats)) {
      return AppPage(
        maxWidth: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xxl),
            PremiumGate(
              tier: app.premiumTier,
              feature: PremiumFeature.advancedStats,
              blurb: 'Finishing positions over time, knockout records and '
                  'exportable history. Your basic group history stays free.',
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    if (user == null) {
      return AppPage(
        child: Column(
          children: [
            Text(
              'Sign in to see your statistics.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }

    return AppPage(
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Statistics',
            style: AppTypography.display(
              size: AppFontSizes.xxxl,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${user.name} · all-time results',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Before the first game the grid is six zeros and an "Avg finish"
          // of #0.0, which reads as a broken screen rather than a new one.
          if (user.stats.played == 0)
            AppEmptyState(
              icon: Icons.insights_outlined,
              title: 'No results yet',
              description:
                  'Your stats fill in automatically once you finish your '
                  'first game.',
              action: AppButton(
                onPressed: () => context.go(RoutePaths.group),
                child: const Text('Go to your group'),
              ),
            )
          else
          // The SIX basic player statistics (Tech §15.2 — "no ROI,
          // profit …, graphs, streaks or advanced filters"; no separate
          // personal game-history page).
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width < 600 ? 3 : 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.1,
            children: [
              _HeadlineStat(
                label: 'Games played',
                value: '${user.stats.played}',
              ),
              _HeadlineStat(
                label: 'Wins',
                value: '${user.stats.wins}',
                accent: AppColors.gold,
              ),
              _HeadlineStat(
                label: 'Podium finishes',
                value: '${user.stats.podium}',
              ),
              _HeadlineStat(
                label: 'Avg finish',
                value: '#${user.stats.avgFinish.toStringAsFixed(1)}',
              ),
              _HeadlineStat(
                label: 'Knockouts',
                value: '${user.stats.knockouts}',
              ),
              _HeadlineStat(
                label: 'Win rate',
                value: user.stats.played > 0
                    ? '${((user.stats.wins / user.stats.played) * 100).toStringAsFixed(0)}%'
                    : '—',
                accent: AppColors.gold,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _HeadlineStat extends StatelessWidget {
  const _HeadlineStat({required this.label, required this.value, this.accent});

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTypography.mono(
                size: AppFontSizes.lg,
                weight: FontWeight.w700,
                color: accent ?? AppColors.foreground,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
