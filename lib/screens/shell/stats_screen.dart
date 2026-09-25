import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_page.dart';
import '../../widgets/back_nav_button.dart';

/// Statistics screen matching F3_Stats mobile-first design.
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

    final winRate = user.stats.played > 0
        ? '${((user.stats.wins / user.stats.played) * 100).toStringAsFixed(0)}%'
        : '0%';

    return AppPage(
      maxWidth: 520,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App bar with squircle back button <
          Row(
            children: [
              BackNavButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(RoutePaths.profile);
                  }
                },
                label: 'Back',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title & Subtitle
          Text(
            'Statistics',
            style: AppTypography.display(
              size: 30,
              weight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${user.name} · all-time results',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),

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
          else ...[
            // 2x3 Grid of Headline Stat Cards
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
              children: [
                _buildStatCard(
                  label: 'Games\nplayed',
                  value: '${user.stats.played}',
                  valueColor: AppColors.foreground,
                ),
                _buildStatCard(
                  label: 'Wins',
                  value: '${user.stats.wins}',
                  valueColor: AppColors.gold,
                ),
                _buildStatCard(
                  label: 'Podium',
                  value: '${user.stats.podium}',
                  valueColor: AppColors.foreground,
                ),
                _buildStatCard(
                  label: 'Avg finish',
                  value: '#${user.stats.avgFinish.toStringAsFixed(1)}',
                  valueColor: AppColors.foreground,
                ),
                _buildStatCard(
                  label: 'Knockouts',
                  value: '${user.stats.knockouts}',
                  valueColor: AppColors.foreground,
                ),
                _buildStatCard(
                  label: 'Win rate',
                  value: winRate,
                  valueColor: AppColors.gold,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Premium blurb card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.workspace_premium_outlined,
                      color: AppColors.destructiveText,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Finishing positions over time, knockout records and exportable history are part of Premium. Your basic stats stay free.',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Widget _buildStatCard({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTypography.display(
                size: 28,
                weight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
          Text(
            label,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
