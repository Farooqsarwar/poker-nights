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
import '../../widgets/app_badge.dart';
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
          _GroupHeader(
            group: group,
            isAdmin: isAdmin,
            onLeaveGroup: () => _confirmLeaveGroup(context),
            onTransferOwnership: isAdmin
                ? () => _showTransferOwnershipDialog(context)
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CodeDisplay(code: group.joinCode, label: 'Group code'),
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: () => _showInviteModal(context, group),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code, size: 16),
                    SizedBox(width: AppSpacing.xs),
                    Text('Invite link / QR'),
                  ],
                ),
              ),
              if (isAdmin)
                AppButton(
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _showTableSettingsModal(context, app, group),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.table_bar_outlined, size: 16),
                      SizedBox(width: AppSpacing.xs),
                      Text('Table settings'),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Games',
                  style: AppTypography.bodyStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${upcomingGames.length} upcoming',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
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
                      color: Colors.black.withValues(alpha: 0.10),
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

class _GroupHeader extends StatelessWidget {
  final Group group;
  final bool isAdmin;
  final VoidCallback? onLeaveGroup;
  final VoidCallback? onTransferOwnership;
  const _GroupHeader({
    required this.group,
    required this.isAdmin,
    this.onLeaveGroup,
    this.onTransferOwnership,
  });

  static const double _mobileBreakpoint = 640;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _mobileBreakpoint;
        // Mobile: icon bleeds off the top-right corner (unchanged).
        // Desktop/laptop: icon anchors to the right edge, vertically
        // centered — NOT dead-center across the whole header. The header's
        // content (title on the left, action buttons on the right) is
        // asymmetric, so centering the icon across the full width landed it
        // in the empty gap between the two, reading as misplaced rather than
        // as a deliberate corner watermark. Anchoring right keeps it in the
        // same visual role as the mobile corner-bleed, just inset instead of
        // clipped, regardless of how wide the header gets.
        // minHeight MUST be large enough to contain the icon at its offset
        // or the Stack's own bounding box will be shorter than the icon and
        // hard-clip it into a broken rectangle instead of showing the full
        // glyph.
        final iconSize = isMobile ? 96.0 : 150.0;
        final iconOffset = isMobile ? -14.0 : -22.0;
        final minHeight = isMobile ? 128.0 : 170.0;

        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.name,
              style: AppTypography.display(
                size: AppFontSizes.xxxl,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  '${group.members.length} members',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  height: 32,
                  child: Row(
                    children: [
                      for (var i = 0; i < group.members.length && i < 5; i++)
                        Align(
                          widthFactor: 0.6,
                          child: AppAvatar(
                            name: group.members[i].name,
                            size: AppAvatarSize.sm,
                          ),
                        ),
                      if (group.members.length > 5)
                        Align(
                          widthFactor: 0.6,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.border,
                            child: Text(
                              '+${group.members.length - 5}',
                              style: AppTypography.monoXs,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );

        final actions = Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (isAdmin) ...[
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go(RoutePaths.presets),
                child: const Text('Presets'),
              ),
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: () =>
                    context.read<AppProvider>().togglePinGroup(group),
                child: Text(group.pinned ? 'Unpin' : 'Pin'),
              ),
              AppButton(
                size: AppButtonSize.sm,
                onPressed: () => context.go(RoutePaths.createTournament),
                child: const Text('+ New game'),
              ),
              if (isAdmin && onTransferOwnership != null)
                AppButton(
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.secondary,
                  onPressed: onTransferOwnership,
                  child: const Text('Transfer Ownership'),
                ),
            ] else if (onLeaveGroup != null) ...[
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: onLeaveGroup,
                child: const Text('Leave Group'),
              ),
            ],
          ],
        );

        final content = isMobile
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  info,
                  if (isAdmin) ...[
                    const SizedBox(height: AppSpacing.md),
                    actions,
                  ],
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: info),
                  if (isAdmin) actions,
                ],
              );

        return ClipRRect(
          // Rounded clip so the icon bleeds off the corner cleanly instead
          // of getting sliced into a hard rectangle.
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Stack(
              fit: StackFit.passthrough,
              clipBehavior: Clip.hardEdge,
              children: [
                // Mobile keeps the corner-bleed look (Positioned must be a
                // direct Stack child; IgnorePointer wraps the visual content
                // rather than the other way around). Desktop centers the
                // icon in the header instead.
                if (isMobile)
                  Positioned(
                    right: iconOffset,
                    top: iconOffset,
                    child: _GroupHeaderIcon(
                      icon: groupIconMap[group.icon] ?? Icons.casino,
                      size: iconSize,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _GroupHeaderIcon(
                        icon: groupIconMap[group.icon] ?? Icons.casino,
                        size: iconSize,
                      ),
                    ),
                  ),
                Align(alignment: Alignment.topLeft, child: content),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Decorative background icon for the group header. Uses AppColors.destructive
/// rather than a hardcoded color, and ignores pointer events so it never
/// intercepts taps meant for the content above it.
class _GroupHeaderIcon extends StatelessWidget {
  const _GroupHeaderIcon({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return IgnorePointer(
      child: Icon(
        icon,
        size: size,
        color: AppColors.primary.withValues(alpha: 0.2),
      ),
    );
  }
}

class _PremiumGameCard extends StatefulWidget {
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
  State<_PremiumGameCard> createState() => _PremiumGameCardState();
}

class _PremiumGameCardState extends State<_PremiumGameCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final rsvp = game.players
        .where((p) => p.id == widget.user?.id)
        .firstOrNull
        ?.rsvp;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppBadge(
                      label: game.status.name.toUpperCase(),
                      variant: game.status.isActiveLive
                          ? AppBadgeVariant.accent
                          : AppBadgeVariant.muted,
                      // The sheet marks a running game with a leading dot, not
                      // a glyph. Only when it is actually live — a dot on a
                      // finished game would read as "still going".
                      dotColor: game.status.isActiveLive
                          ? AppColors.primary
                          : null,
                    ),
                    Icon(Icons.chevron_right, color: AppColors.mutedForeground),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  game.settings.name,
                  style: AppTypography.display(
                    size: AppFontSizes.xl,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: AppColors.mutedForeground,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      game.settings.date,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppColors.mutedForeground,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      game.settings.time,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: AppColors.mutedForeground,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      game.settings.locationPrivate
                          ? 'Address shared at check-in'
                          : game.settings.location,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Buy-in: ${game.settings.buyIn}',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // RSVP is set on the game screen only — here it is read-only.
                if (widget.user != null)
                  Row(
                    children: [
                      Text(
                        game.settings.rsvpCutoffPassed
                            ? 'RSVPs closed'
                            : 'Your RSVP',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      RSVPBadge(rsvp: rsvp),
                      const Spacer(),
                      if (!game.settings.rsvpCutoffPassed)
                        Text(
                          rsvp == null ? 'Tap to respond' : 'Tap to change',
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.primaryText,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
