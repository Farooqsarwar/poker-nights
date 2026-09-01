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
import '../../models/game.dart';
import '../../models/group.dart';
import '../../models/live_game.dart';
import '../../models/table_settings.dart';
import '../../models/user.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/medal_icon.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/code_display.dart';
import '../../widgets/app_tabs.dart';
/// Group hub mirroring the web `GroupPage`.
class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key, this.initialTab});

  final String? initialTab;

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  late String _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab ?? 'games';
  }

  @override
  void didUpdateWidget(GroupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != null && widget.initialTab != oldWidget.initialTab) {
      _tab = widget.initialTab!;
    }
  }

  final _chatController = TextEditingController();
  String? _chatError;
  bool _showPollModal = false;
  String? _pollError;
  final _pollQuestion = TextEditingController();
  final List<TextEditingController> _pollOptions = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _pollMulti = false;

  @override
  void dispose() {
    _chatController.dispose();
    _pollQuestion.dispose();
    for (final c in _pollOptions) {
      c.dispose();
    }
    super.dispose();
  }

  void _sendMessage(AppProvider app) {
    final body = _chatController.text.trim();
    if (body.isEmpty) {
      setState(() => _chatError = null);
      return;
    }
    final error = app.sendChatMessage(null, body);
    if (error != null) {
      setState(() => _chatError = error);
      return;
    }
    setState(() {
      _chatController.clear();
      _chatError = null;
    });
  }

  void _createPoll(AppProvider app) {
    final opts = _pollOptions
        .map((c) => c.text.trim())
        .where((o) => o.isNotEmpty)
        .toList();
    if (_pollQuestion.text.trim().isEmpty || opts.length < 2) {
      setState(() => _pollError = 'Enter a question and at least two options.');
      return;
    }
    final error = app.createPoll(
      _pollQuestion.text.trim(),
      opts,
      multi: _pollMulti,
    );
    if (error != null) {
      setState(() => _pollError = error);
      return;
    }
    setState(() {
      _pollError = null;
      _pollQuestion.clear();
      for (final c in _pollOptions) {
        c.clear();
      }
      _pollMulti = false;
      _showPollModal = false;
    });
  }

  void _confirmRemoveMember(BuildContext context, AppUser member) {
    final app = context.read<AppProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
            child: const Text(
              'Remove',
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveGroup(BuildContext context) {
    final app = context.read<AppProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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

  void _openGame(BuildContext context, AppProvider app, LiveGame game) {
    // Always set the current game first so destination screens
    // have the correct game in the provider.
    app.setCurrentGame(game);
    final isAdmin = app.isAdmin;
    if (game.status == LiveGameStatus.completed) {
      context.go(RoutePaths.resultPodium);
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
                Icon(Icons.handshake_outlined, size: 64, color: AppColors.mutedForeground),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No group selected',
                  style: AppTypography.display(size: AppFontSizes.lg, weight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Join a group or create your own to see events and members.',
                  style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  onPressed: () => context.go(RoutePaths.home),
                  child: const Text('Go to Dashboard'),
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
    final pastGames = group.pastGames;

    return AppPage(
      maxWidth: 960,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GroupHeader(
            group: group,
            isAdmin: isAdmin,
            onLeaveGroup: () => _confirmLeaveGroup(context),
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
          AppTabs(
            tabs: [
              AppTabItem(
                id: 'games',
                label: 'Games',
                count: upcomingGames.length,
              ),
              AppTabItem(
                id: 'members',
                label: 'Members',
                count: group.members.length,
              ),
              AppTabItem(
                id: 'chat',
                label: 'Chat',
                count: group.chat.where((m) => !m.deleted).length,
              ),
              AppTabItem(id: 'polls', label: 'Polls', count: group.polls.length),
              AppTabItem(
                id: 'history',
                label: 'History',
                count: pastGames.length,
              ),
            ],
            active: _tab,
            onChanged: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_tab == 'games')
            _buildGames(app, group, upcomingGames, isAdmin, user)
          else if (_tab == 'members')
            _buildMembers(app, group)
          else if (_tab == 'chat')
            _buildChat(app, group, user?.id)
          else if (_tab == 'polls')
            _buildPolls(app, group, user?.id, isAdmin)
          else
            _buildHistory(group),
          // Poll modal
          AppModal(
            open: _showPollModal,
            onClose: () => setState(() => _showPollModal = false),
            title: 'Create poll',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _pollQuestion,
                  label: 'Question',
                  placeholder: 'e.g. What buy-in for next game?',
                ),
                if (_pollError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _pollError!,
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.destructive,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Options (min. 2)',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < _pollOptions.length; i++) ...[
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _pollOptions[i],
                          placeholder: 'Option ${i + 1}',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (i >= 2)
                        IconButton(
                          onPressed: () => setState(() {
                            _pollOptions.removeAt(i).dispose();
                          }),
                          icon: Text(
                            '×',
                            style: TextStyle(
                              color: AppColors.mutedForeground,
                              fontSize: AppFontSizes.lg,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (_pollOptions.length < 10)
                  InkWell(
                    onTap: () => setState(
                      () => _pollOptions.add(TextEditingController()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Text(
                        '+ Add option',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Multi-choice', style: AppTypography.bodySm),
                          Text(
                            'Members may pick more than one option',
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppToggle(
                      value: _pollMulti,
                      onChanged: (v) => setState(() => _pollMulti = v),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  fullWidth: true,
                  disabled:
                      _pollQuestion.text.trim().isEmpty ||
                      _pollOptions
                              .where((c) => c.text.trim().isNotEmpty)
                              .length <
                          2,
                  onPressed: () => _createPoll(app),
                  child: const Text('Create poll'),
                ),
              ],
            ),
          ),
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

  Widget _buildMembers(AppProvider app, Group group) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth >= 640;
        final width = twoCol
            ? (constraints.maxWidth - AppSpacing.sm) / 2
            : constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    child: AppCard(
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
                              variant: AppBadgeVariant.accent,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ] else if (m.isCoAdmin) ...[
                            const AppBadge(
                              label: 'Co-Admin',
                              variant: AppBadgeVariant.gold,
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
                          if (app.user?.id == group.ownerId &&
                              m.id != group.ownerId)
                            PopupMenuButton<GroupRole>(
                              icon: Icon(
                                Icons.more_vert,
                                size: 18,
                                color: AppColors.mutedForeground,
                              ),
                              onSelected: (role) =>
                                  app.setGroupRole(m.id, role),
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
                                    style:
                                        TextStyle(color: AppColors.destructive),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showInviteModal(BuildContext context, Group group) {
    final link = 'https://poker-night-tools.web.app/join-group?code=${group.joinCode}';
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
              style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
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
                      style: AppTypography.bodySm.copyWith(color: AppColors.foreground),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    size: AppButtonSize.sm,
                    variant: copiedLink ? AppButtonVariant.secondary : AppButtonVariant.primary,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (!mounted) return;
                      setState(() => copiedLink = true);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Invite link copied'), duration: Duration(seconds: 2)),
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

  void _showTableSettingsModal(BuildContext context, AppProvider app, Group group) {
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
              'Default for every tournament this group runs. A host can '
              'still override it for a specific tournament.',
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
                  onPressed: maxPerTable <= 6
                      ? null
                      : () => setState(() => maxPerTable--),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$maxPerTable', style: AppTypography.bodySm),
                IconButton(
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
                      Text('Randomize seating by default', style: AppTypography.bodySm),
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
                app.updateGroupTableSettings(TableSettings(
                  maxPerTable: maxPerTable,
                  randomizeByDefault: randomize,
                ));
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

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
              'Add a registered user directly by their account email — no '
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

  Widget _buildChat(AppProvider app, Group group, String? userId) {
    // The conversation is visible while its tab is open — mark it read.
    if (userId != null && app.unreadGroupChatCount(group.id) > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          app.markChatRead('group:${group.id}');
        }
      });
    }
    final messages = group.chat.where((m) => !m.deleted).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 220, maxHeight: 400),
            child: SingleChildScrollView(
              reverse: true,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: messages.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Text(
                        'No messages yet. Start the conversation!',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final msg in messages)
                          _ChatBubble(
                            message: msg,
                            isMine: msg.authorId == userId,
                            // Audit fix E12: the admin can delete any inappropriate
                            // message — including their own (Tech §14.1).
                            canDelete: (app.isAdmin),
                            onDelete: () => app.deleteMessage(msg.id),
                            app: app,
                            userId: userId,
                          ),
                      ],
                    ),
            ),
          ),
          if (userId != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  // Client rule: hosting a game starts from a button right
                  // here in the chat, not a guessed player count — the setup
                  // screen only asks for rules, and RSVPs (posted back into
                  // this same chat) count the real attendance automatically.
                  if (app.isAdmin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.go(RoutePaths.createTournament),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Create game'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                  if (_chatError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        _chatError!,
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.destructive,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _chatController,
                          placeholder: 'Type a message…',
                          maxLines: 3,
                          maxLength: AppProvider.maxChatMessageLength,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _sendMessage(app),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppButton(
                        size: AppButtonSize.sm,
                        disabled: _chatController.text.trim().isEmpty,
                        onPressed: () => _sendMessage(app),
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Text(
                'Sign in to chat',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPolls(
    AppProvider app,
    Group group,
    String? userId,
    bool isAdmin,
  ) {
    if (group.polls.isEmpty) {
      return Column(
        children: [
          if (isAdmin)
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: () => setState(() => _showPollModal = true),
                child: const Text('+ Create poll'),
              ),
            ),
          AppEmptyState(
            icon: Icons.poll_outlined,
            title: 'No polls yet',
            description: 'Create a poll to help plan the next game.',
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isAdmin) ...[
          AppButton(
            size: AppButtonSize.sm,
            variant: AppButtonVariant.secondary,
            onPressed: () => setState(() => _showPollModal = true),
            child: const Text('+ Create poll'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        for (final poll in group.polls)
          _PollCard(
            poll: poll,
            userId: userId,
            isAdmin: isAdmin,
            onVote: (opts) => app.votePoll(poll.id, opts),
            onClose: () => app.closePoll(poll.id),
          ),
      ],
    );
  }

  Widget _buildHistory(Group group) {
    if (group.pastGames.isEmpty) {
      return const AppEmptyState(
        icon: Icons.history_outlined,
        title: 'No past games',
        description: 'Completed games will appear here.',
      );
    }
    final names = <String, String>{for (final m in group.members) m.id: m.name};
    return Column(
      children: [
        for (final game in group.pastGames)
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.settings.name,
                        style: AppTypography.bodyStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${game.settings.date} · ${game.players.where((p) => p.confirmed).length} players',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      if (game.finishOrder.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Wrap(
                            spacing: AppSpacing.sm,
                            children: [
                              // finishOrder is "first-out first", so the top 3
                              // are the last elements of the list.
                              for (
                                var i = 0;
                                i < game.finishOrder.length.clamp(0, 3);
                                i++
                              )
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    MedalIcon(i + 1, size: AppFontSizes.sm),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      names[game.finishOrder[game
                                                  .finishOrder
                                                  .length -
                                              1 -
                                              i]] ??
                                          game.finishOrder[game
                                                  .finishOrder
                                                  .length -
                                              1 -
                                              i],
                                      style: AppTypography.bodyXs.copyWith(
                                        color: AppColors.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const AppBadge(
                  label: 'Completed',
                  variant: AppBadgeVariant.muted,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.isMine,
    required this.canDelete,
    required this.onDelete,
    required this.app,
    required this.userId,
  });

  final ChatMessage message;
  final bool isMine;
  final bool canDelete;
  final VoidCallback onDelete;
  final AppProvider app;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    // Pinned system messages (published games / edits) render as an event card
    // rather than a chat bubble (§4.3) and are never deletable by members.
    if (message.pinned) {
      // The card carries the game id it announces (client rule: RSVPs count
      // automatically as people answer from the invite in chat), so it opens
      // and updates the *specific* game rather than whatever happens to be
      // "current" in the app.
      final game = message.gameId != null ? app.gameById(message.gameId!) : null;
      final myRsvp = game?.players
          .where((p) => p.id == userId)
          .firstOrNull
          ?.rsvp;
      final goingCount = game?.goingWithGuestsCount;
      final rsvpOpen = game != null &&
          !game.settings.rsvpCutoffPassed &&
          game.status == LiveGameStatus.published;

      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: InkWell(
          onTap: () {
            if (game != null) app.setCurrentGame(game);
            context.go(RoutePaths.invitation);
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.secondary.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.push_pin,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Pinned event',
                      style: AppTypography.monoXs.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (goingCount != null) ...[
                      const Spacer(),
                      Text(
                        '$goingCount going',
                        style: AppTypography.monoXs.copyWith(
                          color: AppColors.mutedForeground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message.body,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.foreground,
                  ),
                ),
                if (game != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      AppBadge(
                        label: game.settings.rebuys
                            ? (game.settings.rebuyLimit == null
                                ? 'Unlimited rebuys to L${game.settings.rebuysCloseLevel}'
                                : '${game.settings.rebuyLimit} rebuys to L${game.settings.rebuysCloseLevel}${game.settings.rebuyCost != null ? ' @ ${game.settings.rebuyCost}' : ''}')
                            : 'No rebuys',
                        variant: game.settings.rebuys
                            ? AppBadgeVariant.gold
                            : AppBadgeVariant.muted,
                      ),
                      AppBadge(
                        label: game.settings.addOn
                            ? 'Add-on to L${game.settings.addOnCloseLevel}'
                            : 'No add-on',
                        variant: game.settings.addOn
                            ? AppBadgeVariant.gold
                            : AppBadgeVariant.muted,
                      ),
                      AppBadge(
                        label: game.settings.anteEnabled
                            ? 'Ante L${game.settings.anteAfterLevel}'
                            : 'No ante',
                        variant: game.settings.anteEnabled
                            ? AppBadgeVariant.gold
                            : AppBadgeVariant.muted,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Posted by ${message.authorName} · ${Formatters.relativeTime(message.timestamp)}',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                    fontSize: 10,
                  ),
                ),
                // RSVP directly from the invite card — no need to leave chat;
                // counts update immediately for everyone (client rule).
                if (rsvpOpen && userId != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final opt in [
                          Rsvp.going,
                          Rsvp.goingPlus1,
                          Rsvp.goingPlus2,
                          Rsvp.goingPlus3,
                          Rsvp.goingPlus4,
                          Rsvp.maybe,
                          Rsvp.cant,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.xs,
                            ),
                            child: InkWell(
                              onTap: () => app.setRSVP(opt, gameId: game.id),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              child: _RsvpBtn(opt: opt, current: myRsvp),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    final avatar = AppAvatar(name: message.authorName, size: AppAvatarSize.sm);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            avatar,
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMine) ...[
                      Text(
                        Formatters.relativeTime(message.timestamp),
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(
                      isMine ? 'You' : message.authorName,
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!isMine) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        Formatters.relativeTime(message.timestamp),
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.lg).copyWith(
                      topRight: isMine ? const Radius.circular(2) : null,
                      topLeft: !isMine ? const Radius.circular(2) : null,
                    ),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    message.body,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.foreground,
                    ),
                  ),
                ),
                if (canDelete)
                  InkWell(
                    onTap: onDelete,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'delete',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: AppSpacing.sm),
            avatar,
          ],
        ],
      ),
    );
  }
}

class _PollCard extends StatefulWidget {
  const _PollCard({
    required this.poll,
    required this.userId,
    required this.isAdmin,
    required this.onVote,
    required this.onClose,
  });

  final Poll poll;
  final String? userId;
  final bool isAdmin;

  /// Commits the member's selection. For single-choice polls this is a one-
  /// element list; for multi-choice polls it carries every ticked option
  /// (Tech §14.2, audit fix B11).
  final ValueChanged<List<String>> onVote;
  final VoidCallback onClose;

  @override
  State<_PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<_PollCard> {
  // Local multi-choice selection (committed via the "Vote" button).
  final Set<String> _multiSelection = {};

  @override
  void initState() {
    super.initState();
    final mine = widget.userId != null
        ? widget.poll.votes[widget.userId!]
        : null;
    if (widget.poll.multi && mine != null) {
      _multiSelection.addAll(mine);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final isMulti = poll.multi;
    final totalVotes = poll.totalVotes;
    final counts = poll.optionCounts();
    final mySingle = !isMulti && widget.userId != null
        ? poll.votes[widget.userId!]
        : null;

    void toggleMulti(String opt) {
      setState(() {
        if (!_multiSelection.remove(opt)) _multiSelection.add(opt);
      });
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  poll.question,
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isMulti)
                const AppBadge(
                  label: 'Multi-choice',
                  variant: AppBadgeVariant.accent,
                  border: true,
                ),
              const SizedBox(width: AppSpacing.sm),
              if (poll.closed)
                const AppBadge(label: 'Closed', variant: AppBadgeVariant.muted),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final opt in poll.options)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PollOption(
                label: opt,
                count: counts[opt] ?? 0,
                total: totalVotes,
                isMyVote: isMulti
                    ? _multiSelection.contains(opt)
                    : mySingle != null && mySingle.contains(opt),
                closed: poll.closed,
                checkbox: isMulti,
                onTap: isMulti
                    ? () => toggleMulti(opt)
                    : () => widget.onVote([opt]),
              ),
            ),
          if (isMulti && !poll.closed && _multiSelection.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                size: AppButtonSize.sm,
                onPressed: () => widget.onVote(_multiSelection.toList()),
                child: const Text('Submit vote'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              Text(
                '$totalVotes vote${totalVotes != 1 ? 's' : ''}',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const Spacer(),
              if (widget.isAdmin && !poll.closed)
                AppButton(
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.ghost,
                  onPressed: widget.onClose,
                  child: const Text('Close poll'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PollOption extends StatelessWidget {
  const _PollOption({
    required this.label,
    required this.count,
    required this.total,
    required this.isMyVote,
    required this.closed,
    required this.onTap,
    this.checkbox = false,
  });

  final String label;
  final int count;
  final int total;
  final bool isMyVote;
  final bool closed;
  final bool checkbox;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total) * 100 : 0.0;
    return InkWell(
      onTap: closed ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isMyVote ? AppColors.primarySoft : AppColors.secondary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isMyVote ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  checkbox
                      ? (isMyVote
                            ? Icons.check_box
                            : Icons.check_box_outline_blank)
                      : (isMyVote
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked),
                  size: 16,
                  color: isMyVote
                      ? AppColors.primary
                      : AppColors.mutedForeground,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.bodySm.copyWith(
                      color: isMyVote
                          ? AppColors.primary
                          : AppColors.foreground,
                    ),
                  ),
                ),
                Text(
                  '$count vote${count != 1 ? 's' : ''}',
                  style: AppTypography.mono(
                    size: AppFontSizes.xs,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
            if (total > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: AppColors.muted,
                    valueColor: AlwaysStoppedAnimation(
                      isMyVote
                          ? AppColors.primary
                          : AppColors.mutedForeground.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RsvpBtn extends StatelessWidget {
  const _RsvpBtn({required this.opt, this.current});
  final Rsvp opt;
  final Rsvp? current;
  @override
  Widget build(BuildContext context) {
    // Exact match: each response (Going, Going +1 … Going +4, Maybe, Can't)
    // highlights only its own button, so the member can see precisely what
    // they picked and switch cleanly.
    final active = current == opt;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.muted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Text(
        opt.label,
        style: AppTypography.bodyXs.copyWith(
          color: active
              ? AppColors.primaryForeground
              : AppColors.mutedForeground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Group header. Responsive: stacks the title/members row above the admin
/// action buttons on narrow (mobile) widths, and lays them out side-by-side
/// on wider (tablet/laptop) widths. The decorative group icon in the
/// background is light red and scales down on mobile.
class _GroupHeader extends StatelessWidget {
  final Group group;
  final bool isAdmin;
  final VoidCallback? onLeaveGroup;
  const _GroupHeader({required this.group, required this.isAdmin, this.onLeaveGroup});

  static const double _mobileBreakpoint = 640;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _mobileBreakpoint;
        // Mobile: icon bleeds off the top-right corner (unchanged).
        // Desktop/laptop: icon is centered in the header instead.
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
                  Align(
                    alignment: Alignment.center,
                    child: _GroupHeaderIcon(
                      icon: groupIconMap[group.icon] ?? Icons.casino,
                      size: iconSize,
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
      child: Icon(icon, size: size, color: AppColors.primary.withValues(alpha: 0.2)),
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
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: 2,
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
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.mutedForeground,
                    ),
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
                    const SizedBox(width: 4),
                    Text(
                      game.settings.date,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppColors.mutedForeground,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      game.settings.time,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: AppColors.mutedForeground,
                    ),
                    const SizedBox(width: 4),
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
                if (widget.user != null)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final opt in [
                          Rsvp.going,
                          Rsvp.goingPlus1,
                          Rsvp.goingPlus2,
                          Rsvp.goingPlus3,
                          Rsvp.goingPlus4,
                          Rsvp.maybe,
                          Rsvp.cant,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.xs,
                            ),
                            child: InkWell(
                              onTap: () =>
                                  widget.app.setRSVP(opt, gameId: game.id),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              child: _RsvpBtn(opt: opt, current: rsvp),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
