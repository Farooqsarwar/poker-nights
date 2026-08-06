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

class ChatSheet extends StatefulWidget {
  const ChatSheet({super.key, required this.gameId});
  final String gameId;

  static void show(BuildContext context, String gameId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        child: ChatSheet(gameId: gameId),
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tournament Chat', style: AppTypography.display(size: AppFontSizes.lg)),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.foreground),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
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
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.md,
              bottom: AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
            ),
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
