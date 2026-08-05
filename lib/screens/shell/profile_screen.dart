import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/user.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';

/// User profile mirroring the account area of the web app.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.user;

    if (user == null) {
      return AppPage(
        child: Column(
          children: [
            Text(
              'Not signed in.',
              style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
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
          Text('Profile', style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xl),
          // Identity card
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                AppAvatar(name: user.name, size: AppAvatarSize.lg),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.name,
                              style: AppTypography.body(size: AppFontSizes.xl, weight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.isAdmin) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const AppBadge(label: 'Admin', variant: AppBadgeVariant.gold),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(user.email, style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Member of ${app.currentGroup.name}',
                        style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Stats overview
          Row(
            children: [
              Text('Your stats', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go(RoutePaths.stats),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatsGrid(stats: user.stats),
          const SizedBox(height: AppSpacing.xl),
          // Actions
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ProfileRow(
                  icon: '📊',
                  title: 'Statistics',
                  subtitle: 'Win rate, finishes and recent results',
                  onTap: () => context.go(RoutePaths.stats),
                  showDivider: true,
                ),
                _ProfileRow(
                  icon: '⚙️',
                  title: 'Settings',
                  subtitle: 'Voice announcements and preferences',
                  onTap: () => context.go(RoutePaths.settings),
                  showDivider: true,
                ),
                _ProfileRow(
                  icon: '🏠',
                  title: 'Your group',
                  subtitle: app.currentGroup.name,
                  onTap: () => context.go(RoutePaths.group),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            variant: AppButtonVariant.danger,
            onPressed: () => _confirmSignOut(context, app),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AppProvider app) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Sign out?'),
        content: Text(
          'You will need to log in again to see your games.',
          style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              app.logout();
              context.go(RoutePaths.landing);
            },
            child: Text('Sign out', style: AppTypography.bodySm.copyWith(color: AppColors.destructive)),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.showDivider,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          border: showDivider ? const Border(bottom: BorderSide(color: AppColors.border)) : null,
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: AppFontSizes.lg)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.mutedForeground, size: 18),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.1,
      children: [
        _ProfileStat(label: 'Played', value: '${stats.played}'),
        _ProfileStat(label: 'Wins', value: '${stats.wins}'),
        _ProfileStat(label: 'Podium', value: '${stats.podium}'),
        _ProfileStat(label: 'Avg finish', value: '#${stats.avgFinish.toStringAsFixed(1)}'),
        _ProfileStat(label: 'Knockouts', value: '${stats.knockouts}'),
        _ProfileStat(
          label: 'Win rate',
          value: '${stats.played == 0 ? 0 : ((stats.wins / stats.played) * 100).round()}%',
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTypography.mono(size: AppFontSizes.lg, weight: FontWeight.w700, color: AppColors.foreground),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
        ],
      ),
    );
  }
}
