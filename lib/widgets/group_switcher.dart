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
              style: AppTypography.bodyLg.copyWith(
                fontWeight: FontWeight.w600,
              ),
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
                        fontWeight:
                            group.id == currentId
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
                    trailing:
                        group.id == currentId
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