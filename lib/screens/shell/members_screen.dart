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
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/page_header.dart';
import '../../widgets/app_text_field.dart';

/// Group members as a full screen (single navigation layer — the Members item
/// lives on the navbar, not duplicated in a hub tab bar).
class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  void _showAddMemberDialog(BuildContext context) {
    final app = context.read<AppProvider>();
    final controller = TextEditingController();
    String? error;
    // Adding a member is a round trip. Without this the button stays live and
    // idle-looking for its whole duration, so an impatient second tap fires a
    // second add for the same address.
    var adding = false;
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
              loading: adding,
              onPressed: () async {
                if (adding) return;
                setState(() {
                  adding = true;
                  error = null;
                });
                final result = await app.addMemberByEmail(controller.text);
                if (!context.mounted) return;
                if (result != null) {
                  setState(() {
                    adding = false;
                    error = result;
                  });
                  return;
                }
                Navigator.of(context).pop();
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
        backgroundColor: AppColors.muted,
        title: Text(
          'Remove Member',
          style: TextStyle(color: AppColors.foreground),
        ),
        content: Text(
          'Remove ${member.name} from this group? '
          'They can rejoin with the group code.',
          style: TextStyle(color: AppColors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.mutedForeground),
            ),
          ),
          TextButton(
            onPressed: () {
              app.removeMember(member.id);
              Navigator.of(ctx).pop();
            },
            child: Text(
              'Remove',
              style: TextStyle(color: AppColors.destructiveText),
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
    final isMe = m.id == app.user?.id;
    final isOwner = group.ownerId == m.id;
    final isAdmin = m.isAdmin || isOwner;
    final isCoAdmin = m.isCoAdmin && !isAdmin;
    final canEditRoles = app.user?.id == group.ownerId && m.id != group.ownerId;

    return AppCard(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        canEditRoles ? AppSpacing.xs : AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          AppAvatar(name: m.name, size: AppAvatarSize.md),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${m.name} · you' : m.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  m.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gold is reserved for Premium and first place, so the admin
              // marker uses the accent rather than the PDF's amber.
              if (isAdmin)
                const AppTag('Admin', tone: AppTagTone.primary)
              else if (isCoAdmin)
                const AppTag('Co-admin'),
              if (isAdmin || isCoAdmin) const SizedBox(height: AppSpacing.xs),
              Text(
                '${m.stats.played}G · ${m.stats.wins}W',
                style: AppTypography.mono(
                  size: AppFontSizes.xs,
                  weight: FontWeight.w500,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          if (canEditRoles)
            PopupMenuButton<GroupRole>(
              tooltip: 'Member options',
              icon: Icon(
                Icons.more_vert,
                size: 18,
                color: AppColors.mutedForeground,
              ),
              color: AppColors.muted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                side: BorderSide(color: AppColors.borderSubtle),
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
                  child: Divider(color: AppColors.borderSubtle, height: 1),
                ),
                PopupMenuItem<GroupRole>(
                  onTap: () => _confirmRemoveMember(context, m),
                  child: Text(
                    'Remove from Group',
                    style: TextStyle(color: AppColors.destructiveText),
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
                const IconTile(
                  icon: Icons.groups_outlined,
                  size: 64,
                  tone: IconTileTone.neutral,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No group selected',
                  style: AppTypography.display(
                    size: AppFontSizes.lg,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Join or create a group to see its members.',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                  ),
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

    return AppPage(
      maxWidth: 960,
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                onBack: () => context.go(RoutePaths.group),
                title: 'Members',
                count: group.members.length,
                actions: [
                  if (app.canManageMembers)
                    AppButton(
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.sm,
                      onPressed: () => _showAddMemberDialog(context),
                      child: const Text('+ Add member'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // Measured here, at the grid itself, so the two-column split
              // uses the page's real content width.
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoCol = constraints.maxWidth >= 640;
                  final width = twoCol
                      ? (constraints.maxWidth - AppSpacing.sm) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final m in group.members)
                        SizedBox(
                          width: width,
                          child: _memberCard(context, app, m, group),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
    );
  }
}
