import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';

/// Detailed statistics mirroring the account area of the web app.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.user;

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
          // The FIVE basic player statistics only (Tech §15.2 — "no ROI,
          // profit …, graphs, streaks or advanced filters"; no separate
          // personal game-history page). Audit fix C4: win/podium rate bars
          // and the personal "Recent results" list were removed.
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width < 600 ? 3 : 5,
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
          const SizedBox(height: 2),
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
