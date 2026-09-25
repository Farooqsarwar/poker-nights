import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/user.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/min_tap_target.dart';

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

    final lifetime = _lifetime(app, user.id);
    final achievements = _achievements(app, user.id, lifetime.wins);

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
                      child: Tooltip(
                        message: 'Change avatar colour',
                        child: Semantics(
                        button: true,
                        label: 'Change avatar colour',
                        child: InkWell(
                        onTap: () => _chooseAvatarColor(context, app),
                        customBorder: const CircleBorder(),
                        child: Container(
                          // 17, not 14: 17 + 14 + 17 is exactly the 48px
                          // minimum touch target. The badge is a visible
                          // circle, so it grows to the floor rather than
                          // hiding a transparent margin behind the avatar.
                          padding: const EdgeInsets.all(17),
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
                      const SizedBox(height: AppSpacing.xxs),
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
                Semantics(
                  button: true,
                  label: 'Edit your profile',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => _editProfile(context, app),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: MinTapTarget(
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
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Edit',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.primaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Lifetime P&L — the user's own money across every group. This is
          // personal data (their prize won minus what they paid in), never
          // another player's result.
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            borderColor: AppColors.primary.withValues(alpha: 0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'LIFETIME P&L',
                      style: AppTypography.bodyXs.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    if (lifetime.totalPnl > 0) ...[
                      Icon(
                        Icons.arrow_upward,
                        size: 14,
                        color: AppColors.successText,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                    ] else if (lifetime.totalPnl < 0) ...[
                      Icon(
                        Icons.arrow_downward,
                        size: 14,
                        color: AppColors.destructiveText,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                    ],
                    Text(
                      Formatters.signedMoney('', lifetime.totalPnl),
                      style: AppTypography.monoSm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: lifetime.totalPnl >= 0
                            ? AppColors.successText
                            : AppColors.destructiveText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Divider(color: AppColors.border, height: 1),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _LifetimeStat(
                      label: 'games',
                      value: '${lifetime.played}',
                    ),
                    _LifetimeStat(label: 'wins', value: '${lifetime.wins}'),
                    _LifetimeStat(
                      label: 'ITM',
                      value: '${lifetime.itmPercent}%',
                    ),
                  ],
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
          if (achievements.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(
              'ACHIEVEMENTS',
              style: AppTypography.bodyXs.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final a in achievements)
                  AppBadge(
                    label: a,
                    variant: AppBadgeVariant.muted,
                    border: true,
                  ),
              ],
            ),
          ],
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

  /// The user's own results across every group's completed games, rolled up
  /// the same way the history screen sums them — their P&L, wins and
  /// in-the-money rate. These are the user's own numbers, never another
  /// player's prize.
  ({int played, int wins, double totalPnl, int itmPercent}) _lifetime(
    AppProvider app,
    String? userId,
  ) {
    var played = 0, wins = 0, itm = 0;
    double totalPnl = 0;
    for (final g in app.groups) {
      for (final game in g.pastGames) {
        if (!game.players.any((p) => p.id == userId)) continue;
        played++;
        final pos = game.finishOrder.indexOf(userId ?? '');
        final placement = pos >= 0 ? game.finishOrder.length - pos : 0;
        if (placement == 1) wins++;
        if (placement > 0 && placement <= game.structure.prizes.length) {
          itm++;
        }
        final prize = game.structure.prizes
            .where((pr) => pr.place == placement)
            .fold<int>(0, (s, pr) => s + pr.amount);
        final me = game.players.where((p) => p.id == userId).firstOrNull;
        final cost = game.settings.buyIn +
            (game.settings.rebuyCost ?? game.settings.buyIn) *
                (me?.rebuys ?? 0) +
            (game.settings.addOnCost ?? game.settings.buyIn) *
                ((me?.hasAddOn ?? false) ? 1 : 0);
        totalPnl += prize - cost;
      }
    }
    final itmPercent = played == 0 ? 0 : (itm * 100 / played).round();
    return (
      played: played,
      wins: wins,
      totalPnl: totalPnl,
      itmPercent: itmPercent,
    );
  }

  /// Achievements earned so far, computed strictly from facts the model
  /// already holds — nothing is invented, and a badge is simply absent until
  /// its condition is real.
  List<String> _achievements(AppProvider app, String? userId, int wins) {
    final earned = <String>[];
    if (wins >= 1) earned.add('🏆  FIRST WIN');

    var streak = 0, best = 0;
    for (final g in app.groups) {
      for (final game in g.pastGames) {
        if (!game.players.any((p) => p.id == userId)) continue;
        if (game.finishOrder.firstOrNull == userId) {
          streak++;
          if (streak > best) best = streak;
        } else {
          streak = 0;
        }
      }
    }
    if (best >= 3) earned.add('🔥  3 IN A ROW');

    var biggestPrize = 0;
    for (final g in app.groups) {
      for (final game in g.pastGames) {
        if (!game.players.any((p) => p.id == userId)) continue;
        final pos = game.finishOrder.indexOf(userId ?? '');
        final placement = pos >= 0 ? game.finishOrder.length - pos : 0;
        final prize = game.structure.prizes
            .where((pr) => pr.place == placement)
            .fold<int>(0, (s, pr) => s + pr.amount);
        if (prize > biggestPrize) biggestPrize = prize;
      }
    }
    if (biggestPrize >= 1000) earned.add('💰  \$1K NIGHT');
    return earned;
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

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    AppProvider app,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete account?'),
        content: Text(
          'This permanently removes your account and invalidates any live '
          'session. This cannot be undone.',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Yes, delete my account',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.destructiveText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Firebase refuses `user.delete()` unless the sign-in is minutes old, so an
    // email/password account has to re-present its password. Google and guest
    // accounts re-authenticate without one (popup / no credential), so they
    // skip straight through.
    String? password;
    if (app.deleteNeedsPassword) {
      // The confirm dialog above was awaited, so this context may have gone
      // away while it was open.
      if (!context.mounted) return;
      password = await _askPassword(context);
      if (password == null) return;
    }

    final error = await app.deleteAccount(password: password);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    router.go(RoutePaths.landing);
  }

  /// Second step of deletion for password accounts. Returns null if dismissed.
  Future<String?> _askPassword(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Confirm your password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'For security, please re-enter your password to delete your '
              'account.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Password'),
              onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
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
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(
              'Delete account',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.destructiveText,
                fontWeight: FontWeight.w600,
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
                color: AppColors.destructiveText,
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
                  const SizedBox(height: AppSpacing.xxs),
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

class _LifetimeStat extends StatelessWidget {
  const _LifetimeStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
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
