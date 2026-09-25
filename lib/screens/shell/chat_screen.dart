import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/icon_tile.dart';

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

    final messages = group.chat.where((m) => !m.deleted).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final unread = app.unreadGroupChatCount(group.id);
    final canCompose = userId != null;

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
                      return ChatBubble(
                        message: msg,
                        isMine: msg.authorId == userId,
                        canDelete: (app.isAdmin || msg.authorId == userId),
                        onDelete: () => app.deleteMessage(msg.id),
                        app: app,
                        userId: userId,
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
                onPressed: () => context.go(RoutePaths.createTournament),
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
