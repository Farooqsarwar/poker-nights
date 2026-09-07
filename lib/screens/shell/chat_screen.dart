import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_page.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/group_switcher.dart';

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
          const GroupContextHeader(title: 'Chat'),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  messages.isEmpty
                      ? 'No messages yet'
                      : '${messages.length} message${messages.length != 1 ? 's' : ''}',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '$unread new',
                    style: AppTypography.monoXs.copyWith(
                      color: AppColors.primaryForeground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: messages.isEmpty
                ? _EmptyChat(onStart: () => _fieldFocus.requestFocus())
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.md,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[messages.length - 1 - index];
                      return ChatBubble(
                        message: msg,
                        isMine: msg.authorId == userId,
                        // The admin can delete any inappropriate message;
                        // authors delete their own.
                        canDelete:
                            (app.isAdmin || msg.authorId == userId),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showCreateGame) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go(RoutePaths.createTournament),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Create game'),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (error != null) ...[
            Text(
              error!,
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.destructive,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _ChatInput(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  onSend: onSend,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SendButton(enabled: canSend, onPressed: onSend),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatInput extends StatefulWidget {
  const _ChatInput({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  State<_ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<_ChatInput> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focused = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_handleFocus);
  }

  void _handleFocus() {
    if (_focused != widget.focusNode.hasFocus) {
      setState(() => _focused = widget.focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.muted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _focused
              ? AppColors.ring.withValues(alpha: 0.8)
              : AppColors.border.withValues(alpha: 0.5),
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppColors.ring.withValues(alpha: 0.12),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        minLines: 1,
        maxLines: 4,
        maxLength: AppProvider.maxChatMessageLength,
        textCapitalization: TextCapitalization.sentences,
        onChanged: widget.onChanged,
        onSubmitted: (_) => widget.onSend(),
        style: AppTypography.bodySm.copyWith(color: AppColors.foreground),
        decoration: InputDecoration(
          hintText: 'Type a message…',
          hintStyle: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceHint,
          ),
          counterText: '',
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryHover],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : AppColors.muted,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: enabled
                ? Colors.transparent
                : AppColors.border.withValues(alpha: 0.5),
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          Icons.send_rounded,
          size: 21,
          color: enabled
              ? AppColors.primaryForeground
              : AppColors.mutedForeground,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No messages yet',
              style: AppTypography.bodySm.copyWith(
                fontWeight: FontWeight.w600,
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
    );
  }
}