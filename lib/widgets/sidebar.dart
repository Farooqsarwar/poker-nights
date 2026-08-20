import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/colors.dart';
import '../app/route_paths.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/group.dart';
import '../providers/app_provider.dart';
import 'app_avatar.dart';
import 'brand_lockup.dart';
import 'create_group_dialog.dart';

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
      _NavSpec(RoutePaths.group, 'Group', Icons.groups_outlined, 0, null),
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
                const PokerNightLogo(size: 28),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Poker Night',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.crimsonShimmer(size: AppFontSizes.xl),
                  ),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  child: Text(
                    'MY GROUPS',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                // Every group the user belongs to — pinnable, with an icon
                // (client feedback: groups, not a single slot).
                for (final group in app.orderedGroups)
                  _GroupRow(
                    group: group,
                    selected: group.id == app.currentGroup.id,
                    onTap: () {
                      app.setCurrentGroup(group);
                      context.go(RoutePaths.group);
                    },
                    onPin: () => app.togglePinGroup(group),
                  ),
                // Client review: the funnel is group-first. Events ("New
                // Game") are created INSIDE a group (admin only) — the
                // global quick action for games was removed; "+ New Group"
                // is the top-level action.
                _QuickAction(
                  icon: Icons.group_add_outlined,
                  label: 'New Group',
                  onTap: () => openCreateGroupDialog(context),
                ),
                _QuickAction(
                  icon: Icons.add,
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
                const SizedBox(height: AppSpacing.sm),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () => context.go(RoutePaths.settings),
                      hoverColor: AppColors.surfaceHover,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                        child: Text(
                          'Settings',
                          style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    InkWell(
                      onTap: app.logout,
                      hoverColor: AppColors.surfaceHover,
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
      hoverColor: AppColors.surfaceHover,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: active ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md - 3, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: active ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
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
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.selected,
    required this.onTap,
    required this.onPin,
  });

  final Group group;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onPin;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: AppColors.surfaceHover,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            // Client review: the group SYMBOL is the primary identifier in
            // the multi-group list (the name drops to a smaller label).
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? AppColors.primarySoft : AppColors.secondary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                group.icon,
                style: const TextStyle(
                  fontSize: 15,
                  fontFamilyFallback: ['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji'],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm.copyWith(
                      color: selected ? AppColors.primary : AppColors.foreground,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  Text(
                    '${group.members.length} members',
                    maxLines: 1,
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onPin,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  group.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 14,
                  color: group.pinned ? AppColors.primary : AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the "create group" dialog: name + icon, then switches to it.
class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          hoverColor: AppColors.surfaceHover,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.foreground),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
