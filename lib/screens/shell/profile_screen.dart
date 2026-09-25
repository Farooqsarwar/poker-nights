import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/squircle_icon_button.dart';

/// User profile redesign matching F1_Profile mobile-first design.
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
    final groupName = app.hasCurrentGroup
        ? app.currentGroup.name
        : 'Poker Club';

    return AppPage(
      maxWidth: 520,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top action row (Squircle edit button on top right)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SquircleIconButton(
                icon: Icons.edit_outlined,
                iconSize: 20,
                iconColor: Colors.white,
                tooltip: 'Edit profile',
                onPressed: () => _editProfile(context, app),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Centered Big Avatar with red glow shadow
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Subtle radial glow behind avatar
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x55D53032),
                        blurRadius: 36,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _chooseAvatarColor(context, app),
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD53032),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66D53032),
                          blurRadius: 20,
                          offset: Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      user.initials.isNotEmpty
                          ? user.initials[0].toUpperCase()
                          : 'A',
                      style: AppTypography.display(
                        size: 38,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // User Name & Subtitle
          Center(
            child: Text(
              user.name,
              style: AppTypography.display(
                size: 26,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Member since 2023 · $groupName',
              style: AppTypography.bodySm.copyWith(
                color: const Color(0xFF8E8E93),
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // LIFETIME P&L Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF121417),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF22262B), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LIFETIME P&L',
                      style: AppTypography.bodyXs.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: lifetime.totalPnl >= 0
                            ? const Color(0xFF132A1C)
                            : const Color(0xFF2D1517),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: lifetime.totalPnl >= 0
                              ? const Color(0x3322C55E)
                              : const Color(0x33EF4444),
                        ),
                      ),
                      child: Text(
                        lifetime.totalPnl >= 0 ? '↑ UP' : '↓ DOWN',
                        style: AppTypography.bodyXs.copyWith(
                          color: lifetime.totalPnl >= 0
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFF87171),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  lifetime.totalPnl >= 0
                      ? '+${Formatters.money(app.cashSession?.settings.currency ?? '', lifetime.totalPnl)}'
                      : Formatters.signedMoney(
                          app.cashSession?.settings.currency ?? '',
                          lifetime.totalPnl,
                        ),
                  style: AppTypography.display(
                    size: 38,
                    weight: FontWeight.w700,
                    color: lifetime.totalPnl >= 0
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFF87171),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3 Metric Cards Row (games, wins, ITM)
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  value: '${lifetime.played}',
                  label: 'games',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  value: '${lifetime.wins}',
                  label: 'wins',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  value: '${lifetime.itmPercent}%',
                  label: 'ITM',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ACHIEVEMENTS Section
          Text(
            'ACHIEVEMENTS',
            style: AppTypography.bodyXs.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF71767B),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildAchievementPill(
                emoji: '🏆',
                title: 'FIRST WIN',
                bgColor: const Color(0xFF262010),
                borderColor: const Color(0x55EAB308),
                textColor: const Color(0xFFFACC15),
                active: lifetime.wins >= 1,
              ),
              _buildAchievementPill(
                emoji: '🔥',
                title: '3 IN A ROW',
                bgColor: const Color(0xFF2A1417),
                borderColor: const Color(0x55EF4444),
                textColor: const Color(0xFFF87171),
                active: achievements.any((a) => a.contains('3 IN A ROW')),
              ),
              _buildAchievementPill(
                emoji: '💰',
                title: '\$1K NIGHT',
                bgColor: const Color(0xFF16231E),
                borderColor: const Color(0x5510B981),
                textColor: const Color(0xFF6EE7B7),
                active: achievements.any((a) => a.contains('\$1K NIGHT')),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Profile navigation actions
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF121417),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF22262B)),
            ),
            child: Column(
              children: [
                _buildActionRow(
                  icon: Icons.bar_chart_outlined,
                  title: 'Statistics',
                  subtitle: 'Win rate, finishes and detailed results',
                  onTap: () => context.go(RoutePaths.stats),
                  showDivider: true,
                ),
                _buildActionRow(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  subtitle: 'Gameplay preferences and game assets',
                  onTap: () => context.go(RoutePaths.settings),
                  showDivider: true,
                ),
                _buildActionRow(
                  icon: Icons.people_outline,
                  title: 'Your group',
                  subtitle: groupName,
                  onTap: () => context.go(RoutePaths.group),
                  showDivider: true,
                ),
                _buildActionRow(
                  icon: Icons.delete_outline,
                  title: 'Delete account',
                  subtitle: 'Permanently remove your account and all data',
                  textColor: AppColors.destructiveText,
                  iconColor: AppColors.destructiveText,
                  onTap: () => _confirmDeleteAccount(context, app),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            variant: AppButtonVariant.secondary,
            onPressed: () => _confirmSignOut(context, app),
            child: const Text('Sign out'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Widget _buildMetricCard({
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF121417),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF22262B), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTypography.display(
              size: 26,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.bodySm.copyWith(
              color: const Color(0xFF8E8E93),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildAchievementPill({
    required String emoji,
    required String title,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    required bool active,
  }) {
    return Opacity(
      opacity: active ? 1.0 : 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              title,
              style: AppTypography.bodyXs.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildActionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool showDivider,
    Color? textColor,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  bottom: BorderSide(color: Color(0xFF22262B), width: 1),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppColors.icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textColor ?? AppColors.foreground,
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
        final cost =
            game.settings.buyIn +
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

    String? password;
    if (app.deleteNeedsPassword) {
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
