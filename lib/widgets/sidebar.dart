import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/colors.dart';
import '../app/route_paths.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../providers/app_provider.dart';
import 'app_avatar.dart';

/// Desktop left sidebar mirroring the web `Nav` component.
class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.user;
    final location = GoRouterState.of(context).uri.path;
    final unread = app.unreadCount;

    final navItems = [
      _NavSpec(RoutePaths.home, 'Home', Icons.home_outlined, 0, null),
      _NavSpec(RoutePaths.group, app.currentGroup.name, Icons.groups_outlined, 0, null),
      _NavSpec(RoutePaths.notifications, 'Alerts', Icons.notifications_none, 0, unread),
      _NavSpec(RoutePaths.history, 'History', Icons.history, 0, null),
    ];

    return Container(
      width: 224,
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xl),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.style_outlined, color: AppColors.primary, size: 28),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Poker Night',
                  style: AppTypography.crimsonShimmer(size: AppFontSizes.lg),
                ),
              ],
            ),
          ),
          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.sm),
              children: [
                for (final item in navItems) _NavTile(item: item, location: location),
                const Divider(color: AppColors.border, height: 24),
                if (user?.isAdmin == true && app.currentGroup.id.isNotEmpty)
                  _QuickAction(
                    icon: Icons.add_circle_outline,
                    label: 'New Tournament',
                    onTap: () => context.go(RoutePaths.createTournament),
                  ),
                _QuickAction(
                  icon: Icons.attach_money_outlined,
                  label: 'Cash Game',
                  onTap: () => context.go(RoutePaths.cashGame),
                ),
              ],
            ),
          ),
          // User section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => context.go(RoutePaths.profile),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                    child: Row(
                      children: [
                        if (user != null) AppAvatar(name: user.name),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                user?.isAdmin == true ? 'Admin' : 'Player',
                                style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => context.go(RoutePaths.settings),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
                    child: Text(
                      'Settings',
                      style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.mutedForeground),
                    ),
                  ),
                ),
                InkWell(
                  onTap: app.logout,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                    child: Text(
                      'Sign out',
                      style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavSpec {
  const _NavSpec(this.path, this.label, this.icon, this.badgeOffset, this.badge);

  final String path;
  final String label;
  final IconData icon;
  final double badgeOffset;
  final int? badge;
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.location});

  final _NavSpec item;
  final String location;

  @override
  Widget build(BuildContext context) {
    final active = location == item.path;
    return InkWell(
      onTap: () => context.go(item.path),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: active ? AppColors.primarySoftBorder : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 20,
              color: active ? AppColors.primary : AppColors.mutedForeground,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  item.badge! > 9 ? '9+' : '${item.badge}',
                  style: AppTypography.monoXs.copyWith(color: AppColors.primaryForeground),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.mutedForeground),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}
