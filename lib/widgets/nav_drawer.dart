import 'dart:ui';

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
import 'brand_lockup.dart';
import 'create_group_dialog.dart';
import 'glass_styles.dart';
import 'glass_surface.dart';

/// Mobile slide-in drawer controlled by [AppProvider.isDrawerOpen].
class NavDrawer extends StatelessWidget {
  const NavDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final app = context.watch<AppProvider>();
    final user = app.user;
    final location = GoRouterState.of(context).uri.toString();
    final unread = app.unreadCount;

    final items = [
      _DrawerItem(RoutePaths.home, 'Home', Icons.home_outlined, null),
      _DrawerItem('${RoutePaths.group}?tab=chat', 'Chat', Icons.chat_bubble_outline, null),
      _DrawerItem('${RoutePaths.group}?tab=games', 'Events', Icons.sports_esports_outlined, null),
      _DrawerItem('${RoutePaths.group}?tab=polls', 'Polls', Icons.poll_outlined, null),
      _DrawerItem(RoutePaths.notifications, 'Alerts', Icons.notifications_none, unread),
      _DrawerItem(RoutePaths.history, 'History', Icons.history, null),
      _DrawerItem(RoutePaths.settings, 'Settings', Icons.settings_outlined, null),
    ];

    final groups = app.orderedGroups;

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
            child: Row(
              children: [
                const PokerNightLogo(size: AppFontSizes.xxxl),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Poker Night',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.crimsonShimmer(size: AppFontSizes.lg),
                  ),
                ),
              ],
            ),
          ),
          if (user != null)
            InkWell(
              onTap: () {
                app.closeDrawer();
                context.go(RoutePaths.profile);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  children: [
                    AppAvatar(name: user.name),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: AppTypography.bodySm.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            user.isAdmin ? 'Admin' : 'Player',
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Divider(color: AppColors.border, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.sm),
              children: [
                for (final item in items)
                  InkWell(
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
                        color: location == item.path
                            ? AppColors.primarySoft
                            : Colors.transparent,
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
                                color: location == item.path
                                    ? AppColors.primary
                                    : AppColors.mutedForeground,
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
                  ),
                if (groups.isNotEmpty) ...[
                  Divider(color: AppColors.border, height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      'MY GROUPS',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  for (final group in groups)
                    InkWell(
                      onTap: () {
                        app.setCurrentGroup(group);
                        app.closeDrawer();
                        context.go('${RoutePaths.group}?tab=games');
                      },
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: group.id == app.currentGroup.id
                              ? AppColors.primarySoft
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: group.id == app.currentGroup.id
                                ? AppColors.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              groupIconMap[group.icon] ?? Icons.shield_outlined,
                              size: 18,
                              color: group.id == app.currentGroup.id
                                  ? AppColors.primary
                                  : AppColors.mutedForeground,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                group.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySm.copyWith(
                                  color: group.id == app.currentGroup.id
                                      ? AppColors.primary
                                      : AppColors.foreground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (group.pinned)
                              Icon(
                                Icons.push_pin,
                                size: 14,
                                color: AppColors.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
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
