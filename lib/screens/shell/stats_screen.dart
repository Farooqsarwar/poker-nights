import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../models/user.dart';
import '../../providers/app_provider.dart';
import '../../services/payment_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/app_back_button.dart';

/// Statistics screen matching F3_Stats mobile-first design.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select<AppProvider, AppUser?>((a) => a.user);

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
              AppBackButton(
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
              // Taller than square: 28px value + two-line label + padding
              // must fit at 320px without a bottom overflow.
              childAspectRatio: 0.85,
              children: [
                _buildStatCard(
                  label: 'Games\nplayed',
                  value: '${user.stats.played}',
                  valueColor: AppColors.foreground,
                ),
                _buildStatCard(
                  label: 'Wins',
                  value: '${user.stats.wins}',
                  valueColor: AppColors.foreground,
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
                  valueColor: AppColors.foreground,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.workspace_premium_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Advanced Graphs & History',
                          style: AppTypography.bodySm.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      AppTag(
                        context.watch<AppProvider>().premiumTier ==
                                PremiumTier.premium
                            ? 'UNLOCKED'
                            : 'PREMIUM',
                        tone: context.watch<AppProvider>().premiumTier ==
                                PremiumTier.premium
                            ? AppTagTone.success
                            : AppTagTone.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Finishing positions over time, knockout records and exportable history are part of Premium. Your basic stats stay free.',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                      height: 1.4,
                    ),
                  ),
                  if (context.watch<AppProvider>().premiumTier !=
                      PremiumTier.premium) ...[
                    const SizedBox(height: 12),
                    AppButton(
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => context.push(RoutePaths.upgrade),
                      child: const Text('See Premium Details'),
                    ),
                  ],
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
