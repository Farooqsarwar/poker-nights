import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/game.dart';
import '../../models/group.dart';
import '../../models/live_game.dart';
import '../../models/user.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/medal_icon.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_tabs.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/code_display.dart';
import '../../widgets/rsvp_badge.dart';

/// Group hub mirroring the web `GroupPage`.
class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  String _tab = 'games';
  final _chatController = TextEditingController();
  String? _chatError;
  bool _showPollModal = false;
  String? _pollError;
  final _pollQuestion = TextEditingController();
  final List<TextEditingController> _pollOptions = [TextEditingController(), TextEditingController()];

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
    final opts = _pollOptions.map((c) => c.text.trim()).where((o) => o.isNotEmpty).toList();
    if (_pollQuestion.text.trim().isEmpty || opts.length < 2) {
      setState(() => _pollError = 'Enter a question and at least two options.');
      return;
    }
    final error = app.createPoll(_pollQuestion.text.trim(), opts);
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
      _showPollModal = false;
    });
  }

  void _openGame(BuildContext context, AppProvider app, LiveGame game) {
    final isAdmin = app.user?.isAdmin ?? false;
    if (isAdmin && game.status.isActiveLive) {
      context.go(RoutePaths.adminDashboard);
    } else if (game.status == LiveGameStatus.checkin && isAdmin) {
      context.go(RoutePaths.checkIn);
    } else {
      context.go(isAdmin ? RoutePaths.adminDashboard : RoutePaths.invitation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final group = app.currentGroup;
    final user = app.user;

    final upcomingGames = group.upcomingGames;
    final pastGames = group.pastGames;
    final isAdmin = user?.isAdmin ?? false;

    return AppPage(
      maxWidth: 960,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${group.members.length} members',
                      style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
              if (isAdmin) ...[
                AppButton(
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.go(RoutePaths.presets),
                  child: const Text('Presets'),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  size: AppButtonSize.sm,
                  onPressed: () => context.go(RoutePaths.createTournament),
                  child: const Text('+ New game'),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          CodeDisplay(code: group.joinCode, label: 'Group code'),
          const SizedBox(height: AppSpacing.lg),
          AppTabs(
            tabs: [
              AppTabItem(id: 'games', label: 'Games', count: upcomingGames.length),
              AppTabItem(id: 'members', label: 'Members', count: group.members.length),
              AppTabItem(id: 'chat', label: 'Chat', count: group.chat.where((m) => !m.deleted).length),
              AppTabItem(id: 'polls', label: 'Polls', count: group.polls.length),
              AppTabItem(id: 'history', label: 'History', count: pastGames.length),
            ],
            active: _tab,
            onChanged: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_tab == 'games')
            _buildGames(app, group, upcomingGames, isAdmin, user)
          else if (_tab == 'members')
            _buildMembers(group)
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
                    style: AppTypography.bodyXs.copyWith(color: AppColors.destructive),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Options (min. 2)',
                  style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
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
                          icon: const Text('×', style: TextStyle(color: AppColors.mutedForeground, fontSize: AppFontSizes.lg)),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (_pollOptions.length < 10)
                  InkWell(
                    onTap: () => setState(() => _pollOptions.add(TextEditingController())),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Text('+ Add option', style: AppTypography.bodyXs.copyWith(color: AppColors.primary)),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  fullWidth: true,
                  disabled: _pollQuestion.text.trim().isEmpty ||
                      _pollOptions.where((c) => c.text.trim().isNotEmpty).length < 2,
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

  Widget _buildGames(AppProvider app, Group group, List<LiveGame> games, bool isAdmin, AppUser? user) {
    if (games.isEmpty) {
      return AppEmptyState(
        icon: Icons.casino_outlined,
        title: 'No upcoming games',
        description: 'Create a new tournament to get started.',
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
          AppCard(
            onTap: () => _openGame(context, app, game),
            padding: const EdgeInsets.all(AppSpacing.lg),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(game.settings.name, style: AppTypography.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${game.settings.date} at ${game.settings.time} · '
                        '${game.settings.locationPrivate ? 'Address shared at check-in' : game.settings.location}',
                        style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text('Buy-in: ${game.settings.buyIn}', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                          const SizedBox(width: AppSpacing.sm),
                          Text('${game.goingCount} going', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Code: ', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                          Text(game.publicCode, style: AppTypography.mono(size: AppFontSizes.xs, color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          RSVPBadge(
                            rsvp: game.players.where((p) => p.id == app.user?.id).firstOrNull?.rsvp,
                          ),
                            if (user != null) ...[
                              const SizedBox(width: AppSpacing.md),
                              PopupMenuButton<Rsvp>(
                                initialValue: game.players.where((p) => p.id == app.user?.id).firstOrNull?.rsvp,
                                onSelected: (val) => app.setRSVP(val, gameId: game.id),
                                itemBuilder: (context) => [
                                  for (final opt in [
                                    Rsvp.going,
                                    Rsvp.goingPlus1,
                                    Rsvp.goingPlus2,
                                    Rsvp.goingPlus3,
                                    Rsvp.goingPlus4,
                                  ])
                                    PopupMenuItem(value: opt, child: Text(opt.label)),
                                ],
                                child: _RsvpBtn(
                                  opt: Rsvp.going,
                                  current: game.players.where((p) => p.id == app.user?.id).firstOrNull?.rsvp,
                                  overrideLabel: game.players.where((p) => p.id == app.user?.id).firstOrNull?.rsvp?.isGoing == true
                                      ? game.players.where((p) => p.id == app.user?.id).firstOrNull?.rsvp?.label
                                      : 'Going ▾',
                                ),
                              ),
                              for (final opt in const [Rsvp.maybe, Rsvp.cant])
                                Padding(
                                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                                  child: InkWell(
                                    onTap: () => app.setRSVP(opt, gameId: game.id),
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                    child: _RsvpBtn(opt: opt, current: game.players.where((p) => p.id == app.user?.id).firstOrNull?.rsvp),
                                  ),
                                ),
                            ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                AppButton(
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _openGame(context, app, game),
                  child: const Text('Open'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMembers(Group group) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth >= 640;
        final width = twoCol ? (constraints.maxWidth - AppSpacing.sm) / 2 : constraints.maxWidth;
        return Wrap(
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
                            Text(m.name, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500)),
                            Text(m.email, style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                          ],
                        ),
                      ),
                      if (m.isAdmin) ...[
                        const AppBadge(label: 'Admin', variant: AppBadgeVariant.accent),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Text(
                        '${m.stats.played}G · ${m.stats.wins}W',
                        style: AppTypography.mono(size: AppFontSizes.xs, color: AppColors.mutedForeground),
                      ),
                      if (context.read<AppProvider>().user?.id == group.ownerId && m.id != group.ownerId)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18, color: AppColors.mutedForeground),
                          onSelected: (val) {
                            if (val == 'toggle_admin') {
                              context.read<AppProvider>().toggleAdminRole(m.id, !m.isAdmin);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'toggle_admin',
                              child: Text(m.isAdmin ? 'Revoke Admin' : 'Make Admin'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildChat(AppProvider app, Group group, String? userId) {
    final messages = group.chat.where((m) => !m.deleted).toList();
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
                        style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                      ),
                    )
                  : Column(
                      children: [
                        for (final msg in messages.reversed)
                          _ChatBubble(
                            message: msg,
                            isMine: msg.authorId == userId,
                            canDelete: (app.user?.isAdmin ?? false) && msg.authorId != userId,
                            onDelete: () => app.deleteMessage(msg.id),
                          ),
                      ],
                    ),
            ),
          ),
          if (userId != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  if (_chatError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        _chatError!,
                        style: AppTypography.bodyXs.copyWith(color: AppColors.destructive),
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
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Text(
                'Sign in to chat',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPolls(AppProvider app, Group group, String? userId, bool isAdmin) {
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
            onVote: (opt) => app.votePoll(poll.id, opt),
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
    final names = <String, String>{
      for (final m in group.members) m.id: m.name,
    };
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
                      Text(game.settings.name, style: AppTypography.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${game.settings.date} · ${game.players.where((p) => p.confirmed).length} players',
                        style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                      ),
                      if (game.finishOrder.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Wrap(
                            spacing: AppSpacing.sm,
                            children: [
                              // finishOrder is "first-out first", so the top 3
                              // are the last elements of the list.
                              for (var i = 0;
                                  i < game.finishOrder.length.clamp(0, 3);
                                  i++)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    MedalIcon(i + 1, size: AppFontSizes.sm),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      names[game.finishOrder[game.finishOrder.length - 1 - i]] ?? game.finishOrder[game.finishOrder.length - 1 - i],
                                      style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const AppBadge(label: 'Completed', variant: AppBadgeVariant.muted),
              ],
            ),
          ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.isMine, required this.canDelete, required this.onDelete});

  final ChatMessage message;
  final bool isMine;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // Pinned system messages (published games / edits) render as an event card
    // rather than a chat bubble (§4.3) and are never deletable by members.
    if (message.pinned) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.push_pin, size: 14, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Pinned event',
                    style: AppTypography.monoXs.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message.body,
                style: AppTypography.bodySm.copyWith(color: AppColors.foreground),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Posted by ${message.authorName} · ${Formatters.relativeTime(message.timestamp)}',
                style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground, fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            AppAvatar(name: message.authorName, size: AppAvatarSize.sm),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  message.authorName,
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isMine ? AppColors.primary : AppColors.secondary,
                    borderRadius: BorderRadius.circular(AppRadius.lg).copyWith(
                      topRight: isMine ? const Radius.circular(2) : null,
                      topLeft: !isMine ? const Radius.circular(2) : null,
                    ),
                    border: isMine ? null : Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    message.body,
                    style: AppTypography.bodySm.copyWith(
                      color: isMine ? AppColors.primaryForeground : AppColors.foreground,
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
                        style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
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
  final ValueChanged<String> onVote;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final totalVotes = poll.totalVotes;
    final myVote = userId != null ? poll.votes[userId] : null;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(poll.question, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500)),
              ),
              if (poll.closed) const AppBadge(label: 'Closed', variant: AppBadgeVariant.muted),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final opt in poll.options)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PollOption(
                label: opt,
                count: poll.votes.values.where((v) => v == opt).length,
                total: totalVotes,
                isMyVote: myVote == opt,
                closed: poll.closed,
                onTap: () => onVote(opt),
              ),
            ),
          Row(
            children: [
              Text(
                '$totalVotes vote${totalVotes != 1 ? 's' : ''}',
                style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
              ),
              const Spacer(),
              if (isAdmin && !poll.closed)
                AppButton(
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.ghost,
                  onPressed: onClose,
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
  });

  final String label;
  final int count;
  final int total;
  final bool isMyVote;
  final bool closed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total) * 100 : 0.0;
    return InkWell(
      onTap: closed ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
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
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.bodySm.copyWith(
                      color: isMyVote ? AppColors.primary : AppColors.foreground,
                    ),
                  ),
                ),
                Text(
                  '$count vote${count != 1 ? 's' : ''}',
                  style: AppTypography.mono(size: AppFontSizes.xs, color: AppColors.mutedForeground),
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
                      isMyVote ? AppColors.primary : AppColors.mutedForeground.withValues(alpha: 0.4),
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
  const _RsvpBtn({required this.opt, this.current, this.overrideLabel});
  final Rsvp opt;
  final Rsvp? current;
  final String? overrideLabel;
  @override
  Widget build(BuildContext context) {
    final active = current != null && (opt == Rsvp.going ? current!.isGoing : current == opt);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.primarySoft : AppColors.muted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: active ? AppColors.primary : AppColors.border),
      ),
      child: Text(
        overrideLabel ?? opt.label,
        style: AppTypography.bodyXs.copyWith(
          color: active ? AppColors.primary : AppColors.mutedForeground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
