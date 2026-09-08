import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/group.dart';
import '../../models/user.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/group_switcher.dart';

/// Group members as a full screen (single navigation layer — the Members item
/// lives on the navbar, not duplicated in a hub tab bar).
class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  void _showAddMemberDialog(BuildContext context) {
    final app = context.read<AppProvider>();
    final controller = TextEditingController();
    String? error;
    showAppModal(
      context: context,
      title: 'Add member',
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add a Registered Group Member directly by their account email — no '
              'invite link, QR, or join code needed.',
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: controller,
              label: 'Email',
              placeholder: 'name@example.com',
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              error: error,
              onChanged: (_) {
                if (error != null) setState(() => error = null);
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              fullWidth: true,
              onPressed: () async {
                final result = await app.addMemberByEmail(controller.text);
                if (result != null) {
                  setState(() => error = result);
                  return;
                }
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Add to group'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveMember(BuildContext context, AppUser member) {
    final app = context.read<AppProvider>();
    final dialogInsets = appDialogInsets(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: dialogInsets,
        backgroundColor: AppColors.card,
        title: const Text('Remove Member'),
        content: Text(
          'Remove ${member.name} from this group? '
          'They can rejoin with the group code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              app.removeMember(member.id);
              Navigator.of(ctx).pop();
            },
            child: Text(
              'Remove',
              style: TextStyle(color: AppColors.destructive),
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberCard(
    BuildContext context,
    AppProvider app,
    AppUser m,
    Group group,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          AppAvatar(name: m.name),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  m.email,
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (m.isAdmin) ...[
            const AppBadge(
              label: 'Admin',
              variant: AppBadgeVariant.gold,
            ),
            const SizedBox(width: AppSpacing.sm),
          ] else if (m.isCoAdmin) ...[
            const AppBadge(
              label: 'Co-Admin',
              variant: AppBadgeVariant.muted,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            '${m.stats.played}G · ${m.stats.wins}W',
            style: AppTypography.mono(
              size: AppFontSizes.xs,
              color: AppColors.mutedForeground,
            ),
          ),
          if (app.user?.id == group.ownerId && m.id != group.ownerId)
            PopupMenuButton<GroupRole>(
              icon: Icon(
                Icons.more_vert,
                size: 18,
                color: AppColors.mutedForeground,
              ),
              onSelected: (role) => app.setGroupRole(m.id, role),
              itemBuilder: (context) => [
                for (final role in GroupRole.values)
                  CheckedPopupMenuItem(
                    value: role,
                    checked: app.roleOf(m) == role,
                    child: Text(role.label),
                  ),
                PopupMenuItem<GroupRole>(
                  enabled: false,
                  height: 8,
                  child: Divider(
                    color: AppColors.border,
                    height: 1,
                  ),
                ),
                PopupMenuItem<GroupRole>(
                  onTap: () => _confirmRemoveMember(context, m),
                  child: Text(
                    'Remove from Group',
                    style: TextStyle(color: AppColors.destructive),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final group = app.currentGroup;

    if (!app.hasCurrentGroup) {
      return AppPage(
        maxWidth: 960,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 96),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.groups_outlined, size: 64, color: AppColors.mutedForeground),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No group selected',
                  style: AppTypography.display(size: AppFontSizes.lg, weight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Join or create a group to see its members.',
                  style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  onPressed: () => context.go(RoutePaths.home),
                  child: const Text('Go to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth >= 640;
        final width = twoCol
            ? (constraints.maxWidth - AppSpacing.sm) / 2
            : constraints.maxWidth;
        return AppPage(
          maxWidth: 960,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GroupContextHeader(title: 'Members'),
              const SizedBox(height: AppSpacing.lg),
              if (app.canManageMembers) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _showAddMemberDialog(context),
                    child: const Text('+ Add member'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final m in group.members)
                    SizedBox(
                      width: width,
                      child: _memberCard(context, app, m, group),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}