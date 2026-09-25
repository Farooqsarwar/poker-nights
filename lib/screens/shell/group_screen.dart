import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:qr_flutter/qr_flutter.dart';

import '../../app/Icons.dart';
import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/group.dart';
import '../../models/live_game.dart';
import '../../models/table_settings.dart';
import '../../models/user.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/code_display.dart';
import '../../widgets/rsvp_badge.dart';

/// Group games hub. Games is the group's landing screen; chat, members, polls
/// and history are dedicated top-level screens (single navigation layer).
class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  void _confirmLeaveGroup(BuildContext context) {
    final app = context.read<AppProvider>();
    final dialogInsets = appDialogInsets(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: dialogInsets,
        title: const Text('Leave Group'),
        content: const Text(
          'Leave this group? You can rejoin with the group code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              app.leaveGroup();
              Navigator.of(ctx).pop();
              if (context.mounted) context.go(RoutePaths.home);
            },
            child: Text(
              'Leave',
              style: TextStyle(color: AppColors.destructive),
            ),
          ),
        ],
      ),
    );
  }

  void _showTransferOwnershipDialog(BuildContext context) {
    final app = context.read<AppProvider>();
    final members = app.currentGroup.members
        .where((m) => m.id != app.user?.id)
        .toList();
    if (members.isEmpty) return;
    String? selectedId;
    final dialogInsets = appDialogInsets(context);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          insetPadding: dialogInsets,
          backgroundColor: AppColors.card,
          title: const Text('Transfer Ownership'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a member to become the new group owner. This cannot be undone.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // The selection now lives on the RadioGroup ancestor rather than
              // on each tile: `RadioListTile.groupValue`/`onChanged` are
              // deprecated.
              RadioGroup<String>(
                groupValue: selectedId,
                onChanged: (v) => setState(() => selectedId = v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...members.map(
                      (m) => RadioListTile<String>(
                        value: m.id,
                        title: Text(m.name, style: AppTypography.bodySm),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: selectedId == null
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      await app.transferGroupOwnership(selectedId!);
                    },
              child: const Text('Transfer'),
            ),
          ],
        ),
      ),
    );
  }

  void _openGame(BuildContext context, AppProvider app, LiveGame game) {
    // Always set the current game first so destination screens
    // have the correct game in the provider.
    app.setCurrentGame(game);
    final isAdmin = app.isAdmin;
    if (game.status == LiveGameStatus.completed) {
      context.go(RoutePaths.resultPodium);
    } else if (game.status == LiveGameStatus.cancelled) {
      showAppModal(
        context: context,
        title: 'Tournament Cancelled',
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'This event has been cancelled and is no longer active.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    } else if (isAdmin && game.status.isActiveLive) {
      context.go(RoutePaths.adminDashboard);
    } else if (game.status == LiveGameStatus.checkin && isAdmin) {
      context.go(RoutePaths.checkIn);
    } else if (isAdmin) {
      context.go(RoutePaths.invitation);
    } else {
      if (game.status.isActiveLive) {
        context.go(RoutePaths.playerLive);
      } else {
        context.go(RoutePaths.invitation);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    // Freshly selected / just-joined group whose live bundle is still loading.
    if (app.groupBundleLoading) {
      return AppPage(
        maxWidth: 960,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 96),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  app.currentGroup.name.isEmpty
                      ? 'Loading group…'
                      : 'Loading ${app.currentGroup.name}…',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                  Icons.handshake_outlined,
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
                  'Join a group or create your own to see events and members.',
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

    final group = app.currentGroup;
    final user = app.user;
    final isAdmin = app.isAdmin;
    // Draft games are only visible to admins (spec §3, §25).
    final upcomingGames = group.upcomingGames
        .where((g) => isAdmin || g.status != LiveGameStatus.draft)
        .toList();

    return AppPage(
      maxWidth: 960,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App bar: Squircle back button < on left, squircle more ⋮ button on right.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Transform.translate(
                offset: const Offset(-4, 0),
                child: AppBackButton(
                  onTap: () => context.go(RoutePaths.home),
                ),
              ),
              PopupMenuButton<String>(
                icon: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: AppColors.foreground,
                  ),
                ),
                padding: EdgeInsets.zero,
                color: AppColors.muted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.borderSubtle),
                ),
                onSelected: (val) {
                  if (val == 'leave') {
                    _confirmLeaveGroup(context);
                  } else if (val == 'transfer') {
                    _showTransferOwnershipDialog(context);
                  }
                },
                itemBuilder: (context) => [
                  if (isAdmin)
                    const PopupMenuItem(
                      value: 'transfer',
                      child: Text('Transfer Ownership'),
                    ),
                  PopupMenuItem(
                    value: 'leave',
                    child: Text(
                      'Leave Group',
                      style: TextStyle(color: AppColors.destructiveText),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Group identity card
          _GroupCardIdentity(group: group),
          const SizedBox(height: AppSpacing.md),
          // Action chips row: GROUP CODE · FP2608, Invite link / QR, Table settings
          _GroupActionChips(
            group: group,
            isAdmin: isAdmin,
            onInvite: () => _showInviteModal(context, group),
            onTableSettings: () => _showTableSettingsModal(context, app, group),
          ),
          const SizedBox(height: AppSpacing.md),
          // Secondary button row: Presets, Pin, + New game
          Row(
            children: [
              _SecondaryChip(
                label: 'Presets',
                onTap: () => context.go(RoutePaths.presets),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SecondaryChip(
                label: group.pinned ? 'Unpin' : 'Pin',
                onTap: () => app.togglePinGroup(group),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                size: AppButtonSize.sm,
                onPressed: () => context.go(RoutePaths.createTournament),
                child: const Text('+ New game'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Games Section with count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Games',
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${upcomingGames.length} upcoming',
                style: TextStyle(color: AppColors.mutedForeground, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildGames(app, group, upcomingGames, isAdmin, user),
        ],
      ),
    );
  }

  Widget _buildGames(
    AppProvider app,
    Group group,
    List<LiveGame> games,
    bool isAdmin,
    AppUser? user,
  ) {
    if (games.isEmpty) {
      return AppEmptyState(
        icon: Icons.sports_esports_outlined,
        title: 'No upcoming games',
        description: isAdmin
            ? 'No upcoming games — create the first one!'
            : 'No upcoming game — wait for the first game to be created.',
        action: isAdmin
            ? AppButton(
                onPressed: () => context.go(RoutePaths.createTournament),
                child: const Text('Create tournament'),
              )
            : null,
      );
    }
    return Column(
      children: [
        for (final game in games)
          _PremiumGameCard(
            game: game,
            app: app,
            user: user,
            onTap: () => _openGame(context, app, game),
          ),
      ],
    );
  }

  void _showInviteModal(BuildContext context, Group group) {
    final link =
        'https://poker-night-tools.web.app/join-group?code=${group.joinCode}';
    final messenger = ScaffoldMessenger.of(context);
    var copiedLink = false;
    showAppModal(
      context: context,
      maxWidth: 400,
      title: 'Invite people',
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Anyone with this link or code can join in one tap.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  // Literal white, deliberately: a QR code needs a light quiet
                  // zone and maximum contrast to scan. Theming this card would
                  // make the code unreadable on the dark palettes.
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: link,
                  size: 140,
                  backgroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            // The one-lined small copy link field
            Container(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.xs,
                top: AppSpacing.xs,
                bottom: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, size: 16, color: AppColors.mutedForeground),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'poker-night-tools.web.app/...',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.foreground,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    size: AppButtonSize.sm,
                    variant: copiedLink
                        ? AppButtonVariant.secondary
                        : AppButtonVariant.primary,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (!mounted) return;
                      setState(() => copiedLink = true);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Invite link copied'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) setState(() => copiedLink = false);
                      });
                    },
                    child: Text(copiedLink ? 'Copied' : 'Copy link'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            CodeDisplay(code: group.joinCode, label: 'Or enter code'),
          ],
        ),
      ),
    );
  }

  void _showTableSettingsModal(
    BuildContext context,
    AppProvider app,
    Group group,
  ) {
    var maxPerTable = group.tableSettings.maxPerTable;
    var randomize = group.tableSettings.randomizeByDefault;
    showAppModal(
      context: context,
      title: 'Table settings',
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Default for every tournament this group runs. An admin can '
              'still override these during game creation.',
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Players per table before splitting',
                    style: AppTypography.bodySm,
                  ),
                ),
                IconButton(
                  tooltip: 'Fewer players per table',
                  onPressed: maxPerTable <= 6
                      ? null
                      : () => setState(() => maxPerTable--),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                // The bare number means nothing out of context to a screen
                // reader sitting between two steppers.
                Semantics(
                  label: '$maxPerTable players per table',
                  excludeSemantics: true,
                  child: Text('$maxPerTable', style: AppTypography.bodySm),
                ),
                IconButton(
                  tooltip: 'More players per table',
                  onPressed: maxPerTable >= 12
                      ? null
                      : () => setState(() => maxPerTable++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Randomize seating by default',
                        style: AppTypography.bodySm,
                      ),
                      Text(
                        'Seating generation defaults to fully random instead '
                        'of the last-used mode.',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                AppToggle(
                  value: randomize,
                  onChanged: (v) => setState(() => randomize = v),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              fullWidth: true,
              onPressed: () {
                app.updateGroupTableSettings(
                  TableSettings(
                    maxPerTable: maxPerTable,
                    randomizeByDefault: randomize,
                  ),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCardIdentity extends StatelessWidget {
  final Group group;
  const _GroupCardIdentity({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            top: -8,
            child: IgnorePointer(
              child: Icon(
                groupIconMap[group.icon] ?? Icons.casino,
                size: 72,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.name,
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${group.members.length} members',
                style: TextStyle(color: AppColors.mutedForeground, fontSize: 13),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 32,
                child: Row(
                  children: [
                    for (var i = 0; i < group.members.length && i < 4; i++)
                      Align(
                        widthFactor: 0.7,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.card,
                              width: 2,
                            ),
                          ),
                          child: AppAvatar(
                            name: group.members[i].name,
                            size: AppAvatarSize.sm,
                          ),
                        ),
                      ),
                    if (group.members.length > 4)
                      Align(
                        widthFactor: 0.7,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.borderSubtle,
                            border: Border.all(
                              color: AppColors.card,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '+${group.members.length - 4}',
                            style: TextStyle(
                              color: AppColors.foreground,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupActionChips extends StatelessWidget {
  final Group group;
  final bool isAdmin;
  final VoidCallback onInvite;
  final VoidCallback onTableSettings;

  const _GroupActionChips({
    required this.group,
    required this.isAdmin,
    required this.onInvite,
    required this.onTableSettings,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: group.joinCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Group code copied')),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primarySoftBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy, size: 14, color: AppColors.primaryText),
                  const SizedBox(width: 8),
                  Text(
                    'GROUP CODE · ${group.joinCode}',
                    style: AppTypography.eyebrow(size: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onInvite,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code, size: 14, color: AppColors.mutedForeground),
                  SizedBox(width: 8),
                  Text(
                    'Invite link / QR',
                    style: TextStyle(
                      color: AppColors.foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onTableSettings,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune, size: 14, color: AppColors.mutedForeground),
                    SizedBox(width: 8),
                    Text(
                      'Table settings',
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SecondaryChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppButton(
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.sm,
        fullWidth: true,
        onPressed: onTap,
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _PremiumGameCard extends StatelessWidget {
  final LiveGame game;
  final AppProvider app;
  final AppUser? user;
  final VoidCallback onTap;

  const _PremiumGameCard({
    required this.game,
    required this.app,
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rsvp = game.players.where((p) => p.id == user?.id).firstOrNull?.rsvp;
    final isLive = game.status.isActiveLive;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive ? AppColors.primary : AppColors.borderSubtle,
        ),
        boxShadow: isLive
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 6, color: AppColors.successText),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: AppColors.successText,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        game.status.label.toUpperCase(),
                        style: TextStyle(
                          color: AppColors.mutedForeground,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.mutedForeground,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                game.settings.name,
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _InfoChip(
                    icon: Icons.calendar_today_outlined,
                    text: game.settings.date,
                  ),
                  _InfoChip(
                    icon: Icons.access_time_outlined,
                    text: game.settings.time,
                  ),
                  _InfoChip(
                    icon: Icons.location_on_outlined,
                    text: game.settings.locationPrivate
                        ? 'Private address'
                        : game.settings.location,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Buy-in: ${game.settings.buyIn}',
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (user != null) ...[
                const SizedBox(height: 12),
                Divider(color: AppColors.borderSubtle, height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      game.settings.rsvpCutoffPassed
                          ? 'RSVPs closed'
                          : 'Your RSVP',
                      style: TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    RSVPBadge(rsvp: rsvp),
                    const Spacer(),
                    if (!game.settings.rsvpCutoffPassed)
                      Text(
                        rsvp == null ? 'Tap to respond' : 'Tap to change',
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact icon+label pair for a game card's date/time/location row — the
/// same shape as the info chips on Home's upcoming-games list.
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.mutedForeground),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          style: AppTypography.bodyXs.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}
