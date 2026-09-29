import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/game.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/min_tap_target.dart';
import '../../widgets/report_message.dart';
import '../../widgets/squircle_icon_button.dart';

/// Group chat as a full screen (single navigation layer — no hub tabs, so the
/// Chat item never appears twice).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatController = TextEditingController();
  final _fieldFocus = FocusNode();
  String? _chatError;

  @override
  void dispose() {
    _chatController.dispose();
    _fieldFocus.dispose();
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

  /// B4: "Long-press a message: Copy · **Report** · **Block {name}**".
  ///
  /// The exact rows depend on the message: your own message can be copied and
  /// deleted, someone else's can be copied, reported and blocked. Blocking is
  /// per-PERSON, not per-message, so it is offered on any message somebody else
  /// wrote — including a pinned event card, which is the only way to reach the
  /// host's row from in here (§E10 (3) allows it "on a member's row or
  /// message"; B3's member rows are not this screen's to change).
  void _showMessageActions(
    BuildContext context,
    AppProvider app,
    ChatMessage m,
  ) {
    final me = app.user?.id;
    final authorName = m.authorName.trim().isEmpty ? 'Member' : m.authorName;
    final canBlock = !m.deleted && m.authorId.isNotEmpty && m.authorId != me;
    final alreadyBlocked = app.isBlocked(m.authorId);

    showAppModal(
      context: context,
      title: authorName,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (app.canReport(m))
            _ActionRow(
              icon: Icons.flag_outlined,
              label: 'Report',
              detail: 'Offensive, spam or something else — the host is told.',
              onTap: () {
                Navigator.of(context).pop();
                confirmReportMessage(context, app, m);
              },
            ),
          if (!m.deleted && m.body.isNotEmpty)
            _ActionRow(
              icon: Icons.copy_rounded,
              label: 'Copy',
              onTap: () {
                Navigator.of(context).pop();
                Clipboard.setData(ClipboardData(text: m.body));
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(content: Text('Message copied')),
                );
              },
            ),
          if (canBlock)
            _ActionRow(
              icon: alreadyBlocked
                  ? Icons.visibility_outlined
                  : Icons.block_rounded,
              label: alreadyBlocked
                  ? 'Unblock $authorName'
                  : 'Block $authorName',
              detail: alreadyBlocked
                  ? 'Show their messages and polls again.'
                  : 'Hide their messages and polls for you only.',
              destructive: !alreadyBlocked,
              onTap: () {
                Navigator.of(context).pop();
                if (alreadyBlocked) {
                  _unblock(app, m.authorId, authorName);
                } else {
                  _confirmBlock(context, app, m.authorId, authorName);
                }
              },
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Long-press a message again to pick another action.',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  /// Asks first, because a block cannot be undone from a hidden message: the
  /// only way back is the "Blocked members" list in the header. The copy says
  /// plainly that nothing is deleted and that the other members still see the
  /// messages — a block is a filter on this one account, which is exactly what
  /// §E10 (3) specifies and exactly what it is easy to assume otherwise.
  void _confirmBlock(
    BuildContext context,
    AppProvider app,
    String authorId,
    String authorName,
  ) {
    showAppModal(
      context: context,
      title: 'Block $authorName?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Their messages and polls are hidden for you in this group and in '
            'every other group you share with them. They are not told, and '
            'nothing they wrote is deleted — everyone else still sees it.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            fullWidth: true,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            fullWidth: true,
            onPressed: () {
              Navigator.of(context).pop();
              _block(app, authorId, authorName);
            },
            child: Text('Block $authorName'),
          ),
        ],
      ),
    );
  }

  void _block(AppProvider app, String authorId, String authorName) {
    if (!app.blockUser(authorId)) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          '$authorName is blocked. Their messages and polls are hidden for you.',
        ),
        // The blocking itself changed nothing for anyone else, so an undo here
        // costs nothing and saves a trip through the blocked list.
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => app.unblockUser(authorId),
        ),
      ),
    );
  }

  void _unblock(AppProvider app, String authorId, String authorName) {
    if (!app.unblockUser(authorId)) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text('$authorName is unblocked.')));
  }

  /// §E10 (3) "until unblocked in Settings → Blocked" — the in-chat equivalent,
  /// reachable from the header. Without it a block would be one-way: the
  /// messages it hides are the only place the action is offered.
  void _showBlockedMembers(BuildContext context, AppProvider app) {
    final group = app.currentGroup;
    // Name the member from the roster so the row reads as a person; a member
    // who has since left the group falls back to their raw id.
    String nameOf(String id) {
      final match = group.members.where((m) => m.id == id).firstOrNull;
      final name = match?.name.trim() ?? '';
      return name.isEmpty ? id : name;
    }

    final ids = app.blockedUserIds.toList();
    showAppModal(
      context: context,
      title: 'Blocked members',
      child: ids.isEmpty
          ? Text(
              'Nobody is blocked.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Their messages and polls are hidden for you. Unblocking '
                  'brings the whole conversation back.',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final id in ids)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          AppAvatar(name: nameOf(id), size: AppAvatarSize.sm),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              nameOf(id),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySm.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _unblock(app, id, nameOf(id));
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryText,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Unblock'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final group = app.currentGroup;
    final user = app.user;
    final userId = user?.id;

    // The conversation is visible — mark it read so the navbar badge clears.
    if (userId != null && app.unreadGroupChatCount(group.id) > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          app.markChatRead('group:${group.id}');
        }
      });
    }

    // §E10 (3) / B4: the feed is the stored transcript minus the authors this
    // member has blocked. The filter is read-side only — the muted messages
    // stay in `…/chat` and stay on screen for everyone else — and it is applied
    // before the sort so the remaining bubbles stay oldest-first with no gap.
    final messages = app.visibleGroupChat().where((m) => !m.deleted).toList();
    final unread = app.unreadGroupChatCount(group.id);
    final canCompose = userId != null;
    final blocked = app.blockedUserIds;

    return AppPage(
      maxWidth: 960,
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar: back tile, group name and member count.
          Row(
            children: [
              Transform.translate(
                offset: const Offset(-4, 0),
                child: AppBackButton(
                  onTap: () => context.go(RoutePaths.group),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name.isEmpty ? 'Chat' : group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(
                        size: AppFontSizes.md,
                        weight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Member count only: there is no presence data, so the
                    // design's "· 3 online" is not shown.
                    Text(
                      '${group.members.length} members',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '$unread',
                    style: AppTypography.mono(
                      size: 11,
                      weight: FontWeight.w700,
                      color: AppColors.primaryForeground,
                    ),
                  ),
                ),
              // §E10 (3) "until unblocked in Settings → Blocked". A blocked
              // member's messages are hidden, so the message list cannot be
              // where you go back and unblock them — this is the undo path
              // inside the chat screen itself.
              if (blocked.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.xs),
                SquircleIconButton(
                  icon: Icons.block_rounded,
                  iconSize: 18,
                  tooltip: 'Blocked members',
                  onPressed: () => _showBlockedMembers(context, app),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Center(child: AppTag('Today')),
          const SizedBox(height: 8),
          Expanded(
            child: messages.isEmpty
                ? _EmptyChat(onStart: () => _fieldFocus.requestFocus())
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[messages.length - 1 - index];
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // B4: "Long-press a message: Copy · Report · Block
                        // {name}". The menu lives on the row rather than in
                        // the bubble so the same gesture works on every
                        // message, including one with no inline actions.
                        onLongPress: () =>
                            _showMessageActions(context, app, msg),
                        child: ChatBubble(
                          message: msg,
                          isMine: msg.authorId == userId,
                          canDelete: (app.isAdmin || msg.authorId == userId),
                          onDelete: () => app.deleteMessage(msg.id),
                          onReport: app.canReport(msg)
                              ? () => confirmReportMessage(context, app, msg)
                              : null,
                          app: app,
                          userId: userId,
                        ),
                      );
                    },
                  ),
          ),
          _Composer(
            controller: _chatController,
            focusNode: _fieldFocus,
            error: _chatError,
            canSend: canCompose && _chatController.text.trim().isNotEmpty,
            showCreateGame: canCompose && app.isAdmin,
            onChanged: (_) => setState(() {}),
            onSend: () => _sendMessage(app),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.canSend,
    required this.showCreateGame,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final bool canSend;
  final bool showCreateGame;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showCreateGame) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.push(RoutePaths.createTournament),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryText,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('+ Create game in chat'),
              ),
            ),
          ],
          if (error != null) ...[
            Text(
              error!,
              style: TextStyle(color: AppColors.destructiveText, fontSize: 12),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 1,
                    maxLength: AppProvider.maxChatMessageLength,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: onChanged,
                    onSubmitted: (_) => onSend(),
                    style: TextStyle(color: AppColors.foreground, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        color: AppColors.onSurfaceHint,
                        fontSize: 14,
                      ),
                      counterText: '',
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: canSend ? onSend : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: canSend
                        ? AppColors.primary
                        : AppColors.muted,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: canSend
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.send_rounded,
                    size: 18,
                    color: canSend ? AppColors.foreground : AppColors.onSurfaceHint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One tappable row in the long-press menu (B4's "Copy · Report · Block
/// {name}"). 44 px tall so it is a real tap target on a phone.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onTap;

  /// Red text for the one action that removes something from view.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? AppColors.destructiveText : AppColors.foreground;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: MinTapTarget(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.bodySm.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (detail != null)
                      Text(
                        detail!,
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IconTile(
                icon: Icons.chat_bubble_outline,
                size: 64,
                tone: IconTileTone.soft,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No messages yet',
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Say hi and kick off the conversation.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                size: AppButtonSize.sm,
                onPressed: onStart,
                child: const Text('Start chatting'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
