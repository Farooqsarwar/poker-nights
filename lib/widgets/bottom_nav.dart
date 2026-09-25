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

/// Height of one bottom-nav row, excluding the device's bottom safe-area
/// inset.
///
/// Exported so `ScreenShell` can reserve exactly this much clearance for the
/// floating nav instead of repeating the number. Keep it in step with the
/// `SizedBox` each nav item is built inside.
const double kBottomNavHeight = 64;

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
          icon: Icons.person_outline,
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
                // The badge count is announced as part of the tab rather than
                // as a loose number, and `selected` is what tells a screen
                // reader which tab you are on — the active underline and
                // colour say that visually and say nothing otherwise.
                child: Semantics(
                  label: item.badge != null && item.badge! > 0
                      ? '${item.label}, ${item.badge} new'
                      : item.label,
                  selected: _isActive(item, location),
                  button: true,
                  // The label above already folds in the badge count, so the
                  // children's own semantics would only repeat it.
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: item.onTap ?? () => context.go(item.path),
                    child: SizedBox(
                      height: kBottomNavHeight,
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
                              const SizedBox(height: AppSpacing.xxs),
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
      backgroundColor: Glass.solid(AppColors.card, 0.98),
      barrierColor: AppColors.black.withValues(alpha: 0.5),
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
              // A LIST, not a grid.
              //
              // `GridView.count` defaults to square tiles, so on a narrow
              // phone each one became half the screen wide and just as tall —
              // an icon at the top, a label at the bottom and a large empty
              // gap between them, with the whole sheet pushed down the screen.
              // A row per destination is the ordinary pattern for a "more"
              // menu: nothing empty, a bigger tap target, and the sheet only
              // as tall as it needs to be.
              _MoreRow(
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
              _MoreRow(
                icon: Icons.history,
                label: 'History',
                subtitle: 'Past games',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go(RoutePaths.history);
                },
              ),
              _MoreRow(
                icon: Icons.payments_outlined,
                label: 'Cash Game',
                subtitle: 'Live cash play',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go(RoutePaths.cashGame);
                },
              ),
              _MoreRow(
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
        ),
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
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
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Glass.solidTint(AppColors.muted),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: enabled
                        ? AppColors.primary
                        : AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? AppColors.foreground
                              : AppColors.mutedForeground,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                    ],
                  ),
                ),
                if (count != null && count! > 0) ...[
                  _CountChip(count: count!),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
        // AppTypography.mono(size: 9), not monoXs.copyWith(fontSize: 9) —
        // copyWith replaces the value AppScale.sp() computed, so the badge
        // would ignore the text-scale floor and stay 9px on every viewport.
        style: AppTypography.mono(size: 9).copyWith(
          color: AppColors.primaryForeground,
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