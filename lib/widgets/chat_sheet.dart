import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/game.dart';
import '../providers/app_provider.dart';
import 'app_avatar.dart';
import 'app_button.dart';
import 'app_text_field.dart';
import 'glass_styles.dart';

class ChatSheet extends StatefulWidget {
  const ChatSheet({super.key, required this.gameId});
  final String gameId;

  static void show(BuildContext context, String gameId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (context) => ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: Glass.blurHeavy,
            sigmaY: Glass.blurHeavy,
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.background.withValues(alpha: 0.65),
                  AppColors.background.withValues(alpha: 0.45),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: AppColors.border.withValues(alpha: Glass.borderOpacity),
                ),
              ),
            ),
            child: ChatSheet(gameId: gameId),
          ),
        ),
      ),
    );
  }


  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  final _chatController = TextEditingController();
  String? _chatError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  // While the sheet is open the conversation is visible, so every message
  // that arrives is immediately marked read (Tech Spec §14.1).
  void _markRead() {
    if (!mounted) return;
    context.read<AppProvider>().markChatRead('game:${widget.gameId}');
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  void _sendMessage(AppProvider app) {
    final body = _chatController.text.trim();
    if (body.isEmpty) {
      setState(() => _chatError = null);
      return;
    }
    final error = app.sendChatMessage(widget.gameId, body);
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
    final game = app.gameById(widget.gameId);
    final userId = app.user?.id;
    if (game == null) return const SizedBox();

    final messages = game.chat.where((m) => !m.deleted).toList();

    if (userId != null && app.unreadGameChatCount(widget.gameId) > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tournament Chat',
                style: AppTypography.display(size: AppFontSizes.lg),
              ),
              IconButton(
                icon: Icon(Icons.close, color: AppColors.foreground),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.border),
        Expanded(
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
                      for (final msg in messages.reversed)
                        _ChatBubble(
                          message: msg,
                          isMine: msg.authorId == userId,
                          canDelete:
                              (app.isAdmin) &&
                              msg.authorId != userId,
                          onDelete: () => app.deleteMessage(msg.id),
                        ),
                    ],
                  ),
          ),
        ),
        if (userId != null)
          Container(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.md,
              bottom: AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
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
    );
  }
}

/// Red pill with an unread-message count, shown next to chat entry buttons
/// until the conversation is opened (Tech Spec §14.1).
class ChatUnreadBadge extends StatelessWidget {
  const ChatUnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: Glass.badgeOpacity),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.destructive.withValues(alpha: Glass.borderOpacity),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.destructive.withValues(alpha: 0.30),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        '$count',
        style: AppTypography.bodyXs.copyWith(
          color: AppColors.destructiveForeground,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.isMine,
    required this.canDelete,
    required this.onDelete,
  });

  final ChatMessage message;
  final bool isMine;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            AppAvatar(name: message.authorName, size: AppAvatarSize.sm),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isMine
                        ? AppColors.primary
                        : AppColors.card.withValues(alpha: Glass.surfaceOpacity),
                    borderRadius: BorderRadius.circular(AppRadius.lg).copyWith(
                      topRight: isMine ? const Radius.circular(2) : null,
                      topLeft: !isMine ? const Radius.circular(2) : null,
                    ),
                    border: isMine
                        ? null
                        : Border.all(
                            color: AppColors.border.withValues(alpha: Glass.borderOpacity),
                          ),
                    boxShadow: isMine
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    message.body,
                    style: AppTypography.bodySm.copyWith(
                      color: isMine
                          ? AppColors.primaryForeground
                          : AppColors.foreground,
                    ),
                  ),
                ),
                if (canDelete)
                  InkWell(
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.card,
                          title: const Text('Delete message?'),
                          content: Text(
                            'This message will be removed from the chat.',
                            style: AppTypography.bodySm,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: Text('Cancel',
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.mutedForeground)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: Text('Delete',
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.destructive)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) onDelete();
                    },
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
        ],
      ),
    );
  }
}
