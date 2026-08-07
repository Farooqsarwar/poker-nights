import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/colors.dart';
import '../app/route_paths.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../providers/app_provider.dart';
import 'app_avatar.dart';

/// Mobile slide-in drawer controlled by [AppProvider.isDrawerOpen].
class NavDrawer extends StatelessWidget {
  const NavDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.user;
    final location = GoRouterState.of(context).uri.path;
    final unread = app.unreadCount;

    final items = [
      _DrawerItem(RoutePaths.home, 'Home', Icons.home_outlined, null),
      _DrawerItem(RoutePaths.group, app.currentGroup.name, Icons.groups_outlined, null),
      _DrawerItem(RoutePaths.notifications, 'Alerts', Icons.notifications_outlined, unread),
      _DrawerItem(RoutePaths.history, 'History', Icons.bar_chart_outlined, null),
      _DrawerItem(RoutePaths.profile, 'Profile', Icons.person_outline, null),
      _DrawerItem(RoutePaths.settings, 'Settings', Icons.settings_outlined, null),
    ];

    final panel = Container(
      width: 280,
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text(AppAssets.spade, style: AppTypography.body(size: AppFontSizes.xxl)),
                const SizedBox(width: AppSpacing.sm),
                Text('Poker Night', style: AppTypography.crimsonShimmer(size: AppFontSizes.lg)),
              ],
            ),
          ),
          if (user != null)
            Container(
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
                        Text(user.name, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                        Text(
                          user.isAdmin ? 'Admin' : 'Player',
                          style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Divider(color: AppColors.border, height: 1),
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
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 11),
                      decoration: BoxDecoration(
                        color: location == item.path ? AppColors.primarySoft : Colors.transparent,
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
                                color: location == item.path ? AppColors.primary : AppColors.mutedForeground,
                              ),
                            ),
                          ),
                          if (item.badge != null && item.badge! > 0)
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: Text(
                                item.badge! > 9 ? '9+' : '${item.badge}',
                                style: AppTypography.monoXs.copyWith(color: AppColors.primaryForeground),
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
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
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
                    style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: app.closeDrawer,
                  icon: const Icon(Icons.close, color: AppColors.mutedForeground, size: 20),
                ),
              ],
            ),
          ),
        ],
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
