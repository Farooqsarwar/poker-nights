import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/colors.dart';
import '../app/icons.dart';
import '../app/route_paths.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../providers/app_provider.dart';
import 'app_avatar.dart';
import 'app_button.dart';
import 'app_tag.dart';
import 'brand_lockup.dart';
import '../services/payment_service.dart';
import 'create_group_dialog.dart';
import 'glass_styles.dart';
import 'glass_surface.dart';
import 'group_switcher.dart';

/// Mobile slide-in drawer controlled by [AppProvider.isDrawerOpen].
class NavDrawer extends StatelessWidget {
  const NavDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final app = context.watch<AppProvider>();
    final user = app.user;
    final location = GoRouterState.of(context).uri.toString();

    final group = app.currentGroup;
    final groupSection = <_DrawerItem>[
      _DrawerItem(RoutePaths.home, 'Home', Icons.home_outlined, null),
      if (app.hasCurrentGroup && !app.isGuest) ...[
        _DrawerItem(RoutePaths.group, 'Games', Icons.sports_esports_outlined, null),
        _DrawerItem(RoutePaths.chat, 'Chat', Icons.chat_bubble_outline, app.unreadGroupChatCount(group.id)),
        _DrawerItem(RoutePaths.members, 'Members', Icons.groups_outlined, group.members.length),
      ],
    ];
    // N1/T134: "MORE label; Polls (badge), History, Cash Game, Tools,
    // Standings, Settings" - and T135 has the drawer and the Explore sheet
    // agree, so the same six rows appear in both.
    final moreSection = <_DrawerItem>[
      _DrawerItem(RoutePaths.standings, 'Standings & Seasons', Icons.leaderboard_outlined, null),
      _DrawerItem(RoutePaths.presets, 'Presets', Icons.list_alt_outlined, null),
      _DrawerItem(RoutePaths.polls, 'Polls', Icons.poll_outlined, null),
      _DrawerItem(RoutePaths.history, 'History', Icons.history, null),
      _DrawerItem(RoutePaths.cashGame, 'Cash Game', Icons.payments_outlined, null),
      _DrawerItem(RoutePaths.tools, 'Tools', Icons.build_outlined, null),
      _DrawerItem(RoutePaths.upgrade, 'Premium Features', Icons.workspace_premium_outlined, null),
      _DrawerItem(RoutePaths.settings, 'Settings', Icons.settings_outlined, null),
    ];

    final panel = GlassSurface(
      blur: Glass.blurHeavy,
      borderRadius: BorderRadius.zero,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.card.withValues(alpha: Glass.navOpacity + 0.05),
            AppColors.card.withValues(alpha: Glass.navOpacity - 0.05),
          ],
        ),
        border: Border(
          right: BorderSide(
            color: AppColors.border.withValues(alpha: Glass.borderOpacity),
          ),
        ),
        boxShadow: Glass.navShadow,
      ),
      child: SizedBox(
        width: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.border.withValues(alpha: Glass.borderOpacity),
                ),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
              ),
            ),
            child: const PokerNightBrand(
              logoSize: 32,
              fontSize: 22,
            ),
          ),
          if (user != null)
            InkWell(
              onTap: () {
                app.closeDrawer();
                if (app.isGuest) {
                  context.go(RoutePaths.register);
                } else {
                  context.go(RoutePaths.profile);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  children: [
                    AppAvatar(name: app.isGuest ? 'Guest' : user.name),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.isGuest ? 'Guest Host' : user.name,
                            style: AppTypography.bodySm.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                app.isGuest
                                    ? 'No account · Tap to register'
                                    : (app.isAdmin ? 'Host' : 'Player'),
                                style: AppTypography.bodyXs.copyWith(
                                  color: app.isGuest
                                      ? AppColors.primary
                                      : AppColors.mutedForeground,
                                ),
                              ),
                              if (!app.isGuest) ...[
                                const SizedBox(width: AppSpacing.xs),
                                AppTag(
                                  app.premiumTier == PremiumTier.premium
                                      ? 'PREMIUM'
                                      : 'FREE',
                                  tone: app.premiumTier == PremiumTier.premium
                                      ? AppTagTone.primary
                                      : AppTagTone.neutral,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (app.isGuest)
            Container(
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Keep tonight\'s results',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Create an account to save your games permanently and start a recurring group.',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    size: AppButtonSize.sm,
                    onPressed: () {
                      app.closeDrawer();
                      context.go(RoutePaths.register);
                    },
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ),
          Divider(color: AppColors.border, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.sm),
              children: [
                // Current group — the single group selector (IA §10).
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs,
                    AppSpacing.xs,
                    AppSpacing.xs,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    // Spec 3: users may belong to multiple groups, so the
                    // navigation is plural. The heading names the section, not
                    // the single group currently selected.
                    'GROUPS',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    app.closeDrawer();
                    if (!app.isGuest && app.hasCurrentGroup) {
                      showGroupSwitcher(context);
                    } else {
                      openCreateGroupDialog(context);
                    }
                  },
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: app.hasCurrentGroup
                          ? AppColors.primarySoft
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: app.hasCurrentGroup
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          groupIconMap[group.icon] ?? Icons.shield_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.hasCurrentGroup ? group.name : 'No group',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySm.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (app.hasCurrentGroup)
                                Text(
                                  '${group.members.length} members · Tap to switch',
                                  style: AppTypography.bodyXs.copyWith(
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 20,
                          color: AppColors.mutedForeground,
                        ),
                      ],
                    ),
                  ),
                ),
                // Primary navigation.
                for (final item in groupSection)
                  _DrawerTile(item: item, location: location, app: app),
                Divider(color: AppColors.border, height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    'MORE',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                for (final item in moreSection)
                  _DrawerTile(item: item, location: location, app: app),
                Divider(color: AppColors.border, height: 24),
                InkWell(
                  onTap: () {
                    app.closeDrawer();
                    openCreateGroupDialog(context);
                  },
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.group_add_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          'New Group',
                          style: AppTypography.bodySm.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.border.withValues(alpha: Glass.borderOpacity),
                ),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.primary.withValues(alpha: 0.03),
                ],
              ),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    app.closeDrawer();
                    app.logout();
                  },
                  child: Text(
                    'Sign out',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close menu',
                  onPressed: app.closeDrawer,
                  icon: Icon(
                    Icons.close,
                    color: AppColors.mutedForeground,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );

    return Stack(
      children: [
        if (app.isDrawerOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: app.closeDrawer,
              child: Container(color: Colors.black.withValues(alpha: 0.6)),
            ),
          ),
        AnimatedPositioned(
          duration: AppDurations.normal,
          curve: Curves.easeOutCubic,
          left: app.isDrawerOpen ? 0 : -280,
          top: 0,
          bottom: 0,
          child: panel,
        ),
      ],
    );
  }
}

class _DrawerItem {
  const _DrawerItem(this.path, this.label, this.icon, this.badge);

  final String path;
  final String label;
  final IconData icon;
  final int? badge;
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.item,
    required this.location,
    required this.app,
  });

  final _DrawerItem item;
  final String location;
  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final active = location == item.path;
    return InkWell(
      onTap: () {
        app.closeDrawer();
        context.go(item.path);
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: active ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 20, color: AppColors.icon),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                item.label,
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w500,
                  color: active ? AppColors.primary : AppColors.mutedForeground,
                ),
              ),
            ),
            if (item.badge != null && item.badge! > 0)
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  item.badge! > 9 ? '9+' : '${item.badge}',
                  style: AppTypography.monoXs.copyWith(
                    color: AppColors.primaryForeground,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
