import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/colors.dart';
import '../app/icons.dart';
import '../app/route_paths.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../providers/app_provider.dart';
import 'create_group_dialog.dart';

/// The selected group in shared app chrome.
///
/// The entire row is one accessible switch action. Its name yields before the
/// icon and dropdown affordance, keeping the target at least 44 px tall even
/// for long group names on a 320 px viewport.
class CurrentGroupChip extends StatelessWidget {
  const CurrentGroupChip({super.key});

  @override
  Widget build(BuildContext context) {
    final group = context.select<AppProvider, ({String name, String icon})>(
      (app) => (name: app.currentGroup.name, icon: app.currentGroup.icon),
    );

    return Semantics(
      label: 'Switch group, ${group.name}',
      button: true,
      container: true,
      child: ExcludeSemantics(
        child: Material(
          color: AppColors.muted.withValues(alpha: 0.72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            side: BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: () => showGroupSwitcher(context),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      groupIconMap[group.icon] ?? Icons.shield_outlined,
                      color: AppColors.icon,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        group.name,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.mutedForeground,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a bottom sheet that lists every group the user belongs to and
/// switches the active group (or creates a new one) on selection.
///
/// This is the single source of truth for group selection across the app so
/// the drawer, sidebar, and every screen header stay consistent.
void showGroupSwitcher(BuildContext context) {
  final app = context.read<AppProvider>();
  final currentId = app.currentGroupId;
  final groups = app.orderedGroups;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'Switch group',
              style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final group in groups)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      groupIconMap[group.icon] ?? Icons.shield_outlined,
                      color: AppColors.icon,
                      size: 20,
                    ),
                    title: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: group.id == currentId
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(
                      '${group.members.length} member${group.members.length == 1 ? '' : 's'}',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    trailing: group.id == currentId
                        ? Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                            size: 20,
                          )
                        : Icon(
                            Icons.chevron_right,
                            color: AppColors.mutedForeground,
                            size: 18,
                          ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      if (group.id != currentId) {
                        app.setCurrentGroup(group);
                      }
                      context.go(RoutePaths.group);
                    },
                  ),
              ],
            ),
          ),
          Divider(color: AppColors.border, height: 1),
          ListTile(
            dense: true,
            leading: Icon(
              Icons.group_add_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            title: Text(
              'New group',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.of(sheetContext).pop();
              openCreateGroupDialog(context);
            },
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    ),
  );
}
