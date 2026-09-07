import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/colors.dart';
import '../app/route_paths.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../providers/app_provider.dart';
import 'create_group_dialog.dart';
import 'glass_styles.dart';
import 'glass_surface.dart';

/// Mobile bottom navigation — the single primary navigation model.
///
/// Items: Home · Games · Chat · Members · More. Secondary destinations
/// (Polls, History, Cash Game, Settings) live in the More sheet's grid so
/// every option stays one tap away (IA §2).
class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    final app = context.watch<AppProvider>();
    final group = app.currentGroup;
    final items = <_BottomItem>[
      _BottomItem(
        path: RoutePaths.home,
        label: 'Home',
        icon: Icons.home_outlined,
        activeColor: AppColors.primary,
      ),
      if (app.hasCurrentGroup) ...[
        _BottomItem(
          path: RoutePaths.group,
          label: 'Games',
          icon: Icons.sports_esports_outlined,
          activeColor: AppColors.primary,
        ),
        _BottomItem(
          path: RoutePaths.chat,
          label: 'Chat',
          icon: Icons.chat_bubble_outline,
          activeColor: AppColors.primary,
          badge: app.unreadGroupChatCount(group.id),
        ),
        _BottomItem(
          path: RoutePaths.members,
          label: 'Members',
          icon: Icons.groups_outlined,
          activeColor: AppColors.primary,
          badge: group.members.length,
        ),
        _BottomItem(
          path: '#more',
          label: 'More',
          icon: Icons.more_horiz,
          activeColor: AppColors.primary,
          activePaths: const [
            RoutePaths.polls,
            RoutePaths.history,
            RoutePaths.cashGame,
            RoutePaths.settings,
          ],
          onTap: () => _openMore(context),
        ),
      ] else ...[
        _BottomItem(
          path: '#new-group',
          label: 'New Group',
          icon: Icons.group_add_outlined,
          activeColor: AppColors.primary,
          onTap: () => openCreateGroupDialog(context),
        ),
        _BottomItem(
          path: '#more',
          label: 'More',
          icon: Icons.more_horiz,
          activeColor: AppColors.primary,
          activePaths: const [
            RoutePaths.history,
            RoutePaths.cashGame,
            RoutePaths.settings,
          ],
          onTap: () => _openMore(context),
        ),
      ],
    ];

    return GlassSurface(
      blur: Glass.blurMedium,
      borderRadius: BorderRadius.zero,
      decoration: Glass.glassBottomNav(),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: InkWell(
                  onTap: item.onTap ?? () => context.go(item.path),
                  child: SizedBox(
                    height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isActive(item, location))
                              Container(
                                width: 24,
                                height: 2,
                                margin: const EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(
                                  color: item.activeColor,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: item.activeColor.withValues(
                                        alpha: 0.50,
                                      ),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              )
                            else
                              const SizedBox(height: 6),
                            Icon(
                              item.icon,
                              size: 24,
                              color: _isActive(item, location)
                                  ? item.activeColor
                                  : AppColors.mutedForeground,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyXs.copyWith(
                                color: _isActive(item, location)
                                    ? item.activeColor
                                    : AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                        if (item.badge != null && item.badge! > 0)
                          Positioned(
                            top: 4,
                            right: 24,
                            child: _BadgeCount(count: item.badge!),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isActive(_BottomItem item, String location) {
    if (location == item.path) return true;
    return item.activePaths?.contains(location) ?? false;
  }

  void _openMore(BuildContext context) {
    final app = context.read<AppProvider>();
    final hasGroup = app.hasCurrentGroup;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Explore',
                style: AppTypography.display(
                  size: AppFontSizes.lg,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Everything else, one tap away',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                children: [
                  _MoreTile(
                    icon: Icons.poll_outlined,
                    label: 'Polls',
                    subtitle: 'Vote & plan',
                    count: hasGroup ? app.currentGroup.polls.length : 0,
                    onTap: hasGroup
                        ? () {
                            Navigator.of(sheetContext).pop();
                            context.go(RoutePaths.polls);
                          }
                        : null,
                  ),
                  _MoreTile(
                    icon: Icons.history,
                    label: 'History',
                    subtitle: 'Past games',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.go(RoutePaths.history);
                    },
                  ),
                  _MoreTile(
                    icon: Icons.payments_outlined,
                    label: 'Cash Game',
                    subtitle: 'Live cash play',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.go(RoutePaths.cashGame);
                    },
                  ),
                  _MoreTile(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    subtitle: 'Account & group',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.go(RoutePaths.settings);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.count,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.transparent
              : AppColors.muted.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: AppColors.primary,
                  size: 22,
                ),
                const Spacer(),
                if (count != null)
                  _CountChip(count: count!)
                else
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.mutedForeground,
                    size: 18,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact primary pill with a count, used for the Chat unread badge.
class _BadgeCount extends StatelessWidget {
  const _BadgeCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.50),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: AppTypography.monoXs.copyWith(
          color: AppColors.primaryForeground,
          fontSize: 9,
        ),
      ),
    );
  }
}

/// Neutral secondary chip showing a count (e.g. members on the More sheet).
class _CountChip extends StatelessWidget {
  const _CountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count',
        style: AppTypography.monoSm.copyWith(
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }
}

class _BottomItem {
  const _BottomItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.activeColor,
    this.badge,
    this.onTap,
    this.activePaths,
  });

  final String path;
  final String label;
  final IconData icon;
  final Color activeColor;
  final int? badge;
  final VoidCallback? onTap;

  /// Additional locations that should light this item up as active.
  final List<String>? activePaths;
}