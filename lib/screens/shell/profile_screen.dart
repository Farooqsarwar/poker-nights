import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/user.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_modal.dart';
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
            'Profile',
            style: AppTypography.display(
              size: AppFontSizes.xxxl,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Identity card
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor:
                          AppColors.avatarPalette[app.avatarColorIndex %
                              AppColors.avatarPalette.length],
                      child: Text(
                        user.initials,
                        style: AppTypography.body(
                          size: AppFontSizes.xl,
                          weight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: InkWell(
                        onTap: () => _chooseAvatarColor(context, app),
                        customBorder: const CircleBorder(),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
                              style: AppTypography.body(
                                size: AppFontSizes.xl,
                                weight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (app.isAdmin) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const AppBadge(
                              label: 'Admin',
                              variant: AppBadgeVariant.gold,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Member of ${app.currentGroup.name}',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _editProfile(context, app),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Stats overview
          Row(
            children: [
              Text(
                'Your stats',
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                  icon: Icons.bar_chart_outlined,
                  title: 'Statistics',
                  subtitle: 'Win rate, finishes and recent results',
                  onTap: () => context.go(RoutePaths.stats),
                  showDivider: true,
                ),
                _ProfileRow(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  subtitle: 'Voice announcements and preferences',
                  onTap: () => context.go(RoutePaths.settings),
                  showDivider: true,
                ),
                _ProfileRow(
                  icon: Icons.home_outlined,
                  title: 'Your group',
                  subtitle: app.currentGroup.name,
                  onTap: () => context.go(RoutePaths.group),
                  showDivider: true,
                ),
                _ProfileRow(
                  icon: Icons.delete_outline,
                  title: 'Delete account',
                  subtitle: 'Permanently remove your account and all sessions',
                  onTap: () => _confirmDeleteAccount(context, app),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            variant: AppButtonVariant.secondary,
            onPressed: () => _confirmSignOut(context, app),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  void _chooseAvatarColor(BuildContext context, AppProvider app) {
    showAppModal(
      context: context,
      title: 'Choose avatar colour',
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (var i = 0; i < AppColors.avatarPalette.length; i++)
            GestureDetector(
              onTap: () {
                app.setAvatarColor(i);
                Navigator.of(context).pop();
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.avatarPalette[i],
                  border: Border.all(
                    color: i == app.avatarColorIndex
                        ? AppColors.foreground
                        : AppColors.border,
                    width: i == app.avatarColorIndex ? 3 : 1,
                  ),
                ),
                child: i == app.avatarColorIndex
                    ? Icon(Icons.check, color: AppColors.foreground)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  void _editProfile(BuildContext context, AppProvider app) {
    final user = app.user;
    if (user == null) return;
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              app.updateProfile(
                name: nameController.text,
                email: emailController.text,
              );
              Navigator.of(dialogContext).pop();
            },
            child: Text(
              'Save',
              style: AppTypography.bodySm.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, AppProvider app) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete account?'),
        content: Text(
          'This permanently removes your account and invalidates any live session. This cannot be undone.',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              app.deleteAccount();
              context.go(RoutePaths.landing);
            },
            child: Text(
              'Delete',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.destructive,
              ),
            ),
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
          style: AppTypography.bodySm.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              app.logout();
              context.go(RoutePaths.landing);
            },
            child: Text(
              'Sign out',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.destructive,
              ),
            ),
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

  final IconData icon;
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
          border: showDivider
              ? Border(bottom: BorderSide(color: AppColors.border))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.icon),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.mutedForeground,
              size: 18,
            ),
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
      crossAxisCount: MediaQuery.of(context).size.width < 600 ? 3 : 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.1,
      children: [
        _ProfileStat(label: 'Played', value: '${stats.played}'),
        _ProfileStat(label: 'Wins', value: '${stats.wins}'),
        _ProfileStat(label: 'Podium', value: '${stats.podium}'),
        _ProfileStat(
          label: 'Avg finish',
          value: '#${stats.avgFinish.toStringAsFixed(1)}',
        ),
        _ProfileStat(label: 'Knockouts', value: '${stats.knockouts}'),
        _ProfileStat(
          label: 'Win rate',
          value:
              '${stats.played == 0 ? 0 : ((stats.wins / stats.played) * 100).round()}%',
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
                color: AppColors.foreground,
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
