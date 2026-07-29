import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/core/widgets/pn_avatar.dart';
import 'package:poker_night/core/widgets/pn_button.dart';
import 'package:poker_night/core/widgets/pn_card.dart';
import 'package:poker_night/core/widgets/pn_empty_state.dart';
import 'package:poker_night/features/auth/controllers/auth_controller.dart';
import 'package:poker_night/features/chat/controllers/chat_controller.dart';
import 'package:poker_night/features/chat/models/chat_message_model.dart';

class ChatView extends StatefulWidget {
  final String groupId;
  final String groupName;

  const ChatView({
    super.key,
    required this.groupId,
    this.groupName = '',
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final ChatController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(ChatController(widget.groupId), tag: widget.groupId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final authController = Get.find<AuthController>();
    final currentUser = authController.currentUser.value;
    controller.sendMessage(
      authorUserId: currentUser?.id ?? '',
      authorName: currentUser?.name ?? 'Anonymous',
      body: text,
    );

    _messageController.clear();
    _scrollToBottom();
  }

  bool _isOwnMessage(ChatMessage message) {
    final currentUser = Get.find<AuthController>().currentUser.value;
    return message.authorUserId == currentUser?.id;
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authController = Get.find<AuthController>();

    return Obx(() {
      final messages = controller.messages;
      final isLoading = controller.isLoading.value;
      final currentUser = authController.currentUser.value;

      if (currentUser == null) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.groupName.isNotEmpty ? widget.groupName : 'Chat')),
          body: const Center(child: Text('Sign in to access chat')),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: Text(widget.groupName.isNotEmpty ? widget.groupName : 'Chat'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : messages.isEmpty
                          ? PNEmptyState(
                              icon: Icons.chat_bubble_outline,
                              title: 'No messages yet',
                              subtitle: 'Send the first message to start the conversation!',
                            )
                          : RefreshIndicator(
                              onRefresh: () => controller.loadMessages(),
                              child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isOwn = _isOwnMessage(message);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (!isOwn)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: PNAvatar(name: message.authorName, size: 32),
                                    ),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        if (!isOwn)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4, bottom: 2),
                                            child: Text(message.authorName, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                                          ),
                                        PNCard(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          color: isOwn ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(message.body, style: theme.textTheme.bodyMedium?.copyWith(
                                                color: isOwn ? Colors.white : theme.colorScheme.onSurface,
                                              )),
                                              const SizedBox(height: 4),
                                              Text(_formatTime(message.createdAt), style: theme.textTheme.bodySmall?.copyWith(
                                                color: isOwn ? Colors.white.withValues(alpha: 0.7) : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                fontSize: 11,
                                              )),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isOwn)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: PNAvatar(name: message.authorName, size: 32),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 12, right: 8, top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PNButton(
                  label: '',
                  icon: Icons.send_rounded,
                  onPressed: _sendMessage,
                  width: 48,
                  height: 48,
                ),
              ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
