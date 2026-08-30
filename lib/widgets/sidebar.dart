import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/colors.dart';
import '../app/icons.dart';
import '../app/route_paths.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/group.dart';
import '../providers/app_provider.dart';
import 'app_avatar.dart';
import 'app_button.dart';
import 'app_icon_label.dart';
import 'brand_lockup.dart';
import 'create_group_dialog.dart';
import 'glass_styles.dart';
import 'glass_surface.dart';

/// Desktop left sidebar mirroring the web `Nav` component.
class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final app = context.watch<AppProvider>();
    final user = app.user;
    final location = GoRouterState.of(context).uri.toString();
    final unread = app.unreadCount;

    final navItems = [
      _NavSpec(RoutePaths.home, 'Home', Icons.home_outlined, 0, null),
      _NavSpec(
        '${RoutePaths.group}?tab=chat',
        'Chat',
        Icons.chat_bubble_outline,
        0,
        null,
      ),
      _NavSpec(
        '${RoutePaths.group}?tab=games',
        'Events',
        Icons.sports_esports_outlined,
        0,
        null,
      ),
      _NavSpec(
        '${RoutePaths.group}?tab=polls',
        'Polls',
        Icons.poll_outlined,
        0,
        null,
      ),
      _NavSpec(
        RoutePaths.notifications,
        'Alerts',
        Icons.notifications_none,
        0,
        unread,
      ),
      _NavSpec(RoutePaths.history, 'History', Icons.history, 0, null),
      _NavSpec(
        RoutePaths.settings,
        'Settings',
        Icons.settings_outlined,
        0,
        null,
      ),
    ];

    return GlassSurface(
      blur: Glass.blurHeavy,
      borderRadius: BorderRadius.zero,
      decoration: Glass.glassNav(),
      child: SizedBox(
        width: 264,
        child: Column(
          children: [
            // Logo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.border.withValues(
                      alpha: Glass.borderOpacity,
                    ),
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
                  const PokerNightLogo(size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Poker Night',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.crimsonShimmer(
                        size: AppFontSizes.lg,
                      ),
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
                  for (final item in navItems)
                    _NavTile(item: item, location: location),
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
                  // Every group the user belongs to — pinnable, with an icon
                  // (client feedback: groups, not a single slot).
                  for (final group in app.orderedGroups)
                    _GroupRow(
                      group: group,
                      selected: group.id == app.currentGroupId,
                      onTap: () {
                        app.setCurrentGroup(group);
                        context.go('${RoutePaths.group}?tab=games');
                      },
                      onPin: () => app.togglePinGroup(group),
                    ),
                ],
              ),
            ),
            // Top-level quick actions, pinned above the account section.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.border.withValues(
                      alpha: Glass.borderOpacity,
                    ),
                  ),
                ),
              ),
              child: Column(
                children: [
                  AppButton(
                    fullWidth: true,
                    size: AppButtonSize.sm,
                    onPressed: () => openCreateGroupDialog(context),
                    child: const AppIconLabel(
                      label: 'New Group',
                      icon: Icons.group_add_outlined,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    fullWidth: true,
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.go(RoutePaths.cashGame),
                    child: const AppIconLabel(
                      label: 'Cash Game',
                      icon: Icons.sports_esports_outlined,
                    ),
                  ),
                ],
              ),
            ),
            // User section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.border.withValues(
                      alpha: Glass.borderOpacity,
                    ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => context.go(RoutePaths.profile),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.sm,
                      ),
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
                                  style: AppTypography.bodySm.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  user?.isAdmin == true ? 'Admin' : 'Player',
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
                  const SizedBox(height: AppSpacing.sm),
                  Divider(
                    color: AppColors.border.withValues(
                      alpha: Glass.borderOpacity,
                    ),
                    height: 1,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: app.logout,
                        hoverColor: AppColors.surfaceHover,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 4,
                          ),
                          child: Text(
                            'Sign out',
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.mutedForeground,
                            ),
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
      ),
    );
  }
}

class _NavSpec {
  const _NavSpec(
    this.path,
    this.label,
    this.icon,
    this.badgeOffset,
    this.badge,
  );

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
    Theme.of(context);
    final active = location == item.path;
    return InkWell(
      onTap: () => context.go(item.path),
      hoverColor: AppColors.surfaceHover,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: Glass.glassNavActive().copyWith(
          color: active
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          border: null,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md - 3,
            vertical: 10,
          ),
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
                    color: active
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
    Theme.of(context);
    return InkWell(
      onTap: onTap,
      hoverColor: AppColors.surfaceHover,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 8,
        ),
        decoration: Glass.glassGroupRow(selected: selected),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Client review: the group SYMBOL is the primary identifier in
            // the multi-group list (the name drops to a smaller label).
            //
            // Fixed-size box + FittedBox: whatever `group.icon` contains
            // (single emoji, multi-char initials, etc.) is scaled down to
            // fit on one line inside the 26x26 box instead of wrapping or
            // overflowing into the name/member-count text next to it.
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(top: 1),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: selected ? AppColors.primarySoft : AppColors.secondary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                groupIconMap[group.icon] ?? Icons.shield_outlined,
                size: 16,
                color: selected ? AppColors.primary : AppColors.mutedForeground,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    group.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyXs.copyWith(
                      color: selected
                          ? AppColors.primary
                          : AppColors.foreground,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                  if (group.members.isNotEmpty)
                    Text(
                      '${group.members.length} member'
                      '${group.members.length == 1 ? '' : 's'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: InkWell(
                onTap: onPin,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    group.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 14,
                    color: group.pinned
                        ? AppColors.primary
                        : AppColors.mutedForeground,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
