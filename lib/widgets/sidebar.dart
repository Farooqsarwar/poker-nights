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
import 'app_icon_label.dart';
import 'app_tag.dart';
import 'brand_lockup.dart';
import '../services/payment_service.dart';
import 'create_group_dialog.dart';
import 'glass_styles.dart';
import 'glass_surface.dart';
import 'group_switcher.dart';

/// Desktop left sidebar mirroring the web `Nav` component.
/// Width of the desktop sidebar. Dialogs offset by this so they centre over
/// the content area instead of the window (see [ShellInsets]).
const double kSidebarWidth = 264;

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final app = context.watch<AppProvider>();
    final user = app.user;
    final location = GoRouterState.of(context).uri.toString();
    final group = app.currentGroup;

    final primaryNavItems = [
      _NavSpec(RoutePaths.home, 'Home', Icons.home_outlined, 0, null),
      if (app.hasCurrentGroup && !app.isGuest) ...[
        _NavSpec(RoutePaths.group, 'Games', Icons.sports_esports_outlined, 0, null),
        _NavSpec(RoutePaths.chat, 'Chat', Icons.chat_bubble_outline, 0, app.unreadGroupChatCount(group.id)),
        _NavSpec(RoutePaths.members, 'Members', Icons.groups_outlined, 0, group.members.length),
      ],
    ];
    final secondaryNavItems = [
      _NavSpec(RoutePaths.standings, 'Standings & Seasons', Icons.leaderboard_outlined, 0, null),
      _NavSpec(RoutePaths.presets, 'Presets', Icons.list_alt_outlined, 0, null),
      _NavSpec(RoutePaths.polls, 'Polls', Icons.poll_outlined, 0, null),
      _NavSpec(RoutePaths.history, 'History', Icons.history, 0, null),
      _NavSpec(RoutePaths.cashGame, 'Cash Game', Icons.payments_outlined, 0, null),
      _NavSpec(RoutePaths.tools, 'Public Tools', Icons.build_outlined, 0, null),
      _NavSpec(RoutePaths.upgrade, 'Premium', Icons.workspace_premium_outlined, 0, null),
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
        width: kSidebarWidth,
        child: Column(
          children: [
            // Logo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
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
              child: const PokerNightBrand(
                logoSize: 26,
                fontSize: 18,
              ),
            ),
            // Nav items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.sm),
                children: [
                  // Current group — the single group selector (IA §10).
                  InkWell(
                    onTap: () {
                      if (!app.isGuest && app.hasCurrentGroup) {
                        showGroupSwitcher(context);
                      } else {
                        openCreateGroupDialog(context);
                      }
                    },
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Container(
                      margin: const EdgeInsets.only(
                        bottom: AppSpacing.sm,
                        top: AppSpacing.xs,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 8,
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
                            groupIconMap[app.currentGroup.icon] ??
                                Icons.shield_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app.hasCurrentGroup
                                      ? app.currentGroup.name
                                      : 'No group',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySm.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  app.hasCurrentGroup
                                      ? '${app.currentGroup.members.length} members'
                                      : 'Join or create a group',
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
                  for (final item in primaryNavItems)
                    _NavTile(item: item, location: location),
                  Divider(color: AppColors.border, height: 16),
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
                  for (final item in secondaryNavItems)
                    _NavTile(item: item, location: location),
                ],
              ),
            ),
            // Pinned footer: New Group button + Compact User Profile row
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
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
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: AppSpacing.xs),
                  InkWell(
                    onTap: () => context.go(RoutePaths.profile),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          if (user != null)
                            AppAvatar(
                              name: user.name,
                              size: AppAvatarSize.sm,
                            ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  user?.name ?? '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySm.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      app.isAdmin ? 'Host' : 'Player',
                                      style: AppTypography.bodyXs.copyWith(
                                        color: AppColors.mutedForeground,
                                        fontSize: 11,
                                      ),
                                    ),
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
                                ),
                              ],
                            ),
                          ),
                          Tooltip(
                            message: 'Sign out',
                            child: IconButton(
                              icon: const Icon(Icons.logout, size: 16),
                              color: AppColors.mutedForeground,
                              hoverColor: AppColors.surfaceHover,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              onPressed: app.logout,
                            ),
                          ),
                        ],
                      ),
                    ),
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
            vertical: 8,
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
              if (item.path == RoutePaths.upgrade)
                const AppTag('PREMIUM', tone: AppTagTone.primary),
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

