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
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
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
        backgroundColor: const Color(0xFF18181A),
        title: const Text(
          'Remove Member',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Remove ${member.name} from this group? '
          'They can rejoin with the group code.',
          style: const TextStyle(color: Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              app.removeMember(member.id);
              Navigator.of(ctx).pop();
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Color(0xFFE53935)),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF242428)),
      ),
      child: Row(
        children: [
          AppAvatar(name: m.name, size: AppAvatarSize.md),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isMe ? '${m.name} (You)' : m.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x26F59E0B),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ] else if (isCoAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2024),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'CO-ADMIN',
                          style: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  m.email,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${m.stats.played}G · ${m.stats.wins}W',
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 13,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
          if (app.user?.id == group.ownerId && m.id != group.ownerId) ...[
            const SizedBox(width: 4),
            PopupMenuButton<GroupRole>(
              icon: const Icon(
                Icons.more_vert,
                size: 18,
                color: Color(0xFF8E8E93),
              ),
              color: const Color(0xFF18181A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF242428)),
              ),
              onSelected: (role) => app.setGroupRole(m.id, role),
              itemBuilder: (context) => [
                for (final role in GroupRole.values)
                  CheckedPopupMenuItem(
                    value: role,
                    checked: app.roleOf(m) == role,
                    child: Text(role.label),
                  ),
                const PopupMenuItem<GroupRole>(
                  enabled: false,
                  height: 8,
                  child: Divider(color: Color(0xFF242428), height: 1),
                ),
                PopupMenuItem<GroupRole>(
                  onTap: () => _confirmRemoveMember(context, m),
                  child: const Text(
                    'Remove from Group',
                    style: TextStyle(color: Color(0xFFE53935)),
                  ),
                ),
              ],
            ),
          ],
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
                Icon(
                  Icons.groups_outlined,
                  size: 64,
                  color: AppColors.mutedForeground,
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
              // Top bar: Squircle back button <, Title with count, + Add member button
              Row(
                children: [
                  InkWell(
                    onTap: () => context.go(RoutePaths.group),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141416),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF242428)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Members',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2024),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${group.members.length}',
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (app.canManageMembers)
                    InkWell(
                      onTap: () => _showAddMemberDialog(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD53032),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33D53032),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '+ Add member',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
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
