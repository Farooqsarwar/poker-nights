import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:poker_night/features/chat/models/chat_message_model.dart';
import 'package:poker_night/services/storage_service.dart';

class ChatController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final String _groupId;

  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxBool isLoading = true.obs;

  ChatController(this._groupId);

  @override
  void onInit() {
    super.onInit();
    loadMessages();
  }
  Future<void> loadMessages() async {
    isLoading.value = true;
    final data = await _storage.getJson('chat_messages_$_groupId');
    final list = (data?['items'] as List<dynamic>?)
        ?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    messages.assignAll(list..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
    isLoading.value = false;
  }

  Future<void> sendMessage({
    required String authorUserId,
    required String authorName,
    required String body,
  }) async {
    final message = ChatMessage(
      id: const Uuid().v4(),
      scopeType: 'group',
      scopeId: _groupId,
      authorUserId: authorUserId,
      authorName: authorName,
      body: body,
      createdAt: DateTime.now(),
    );
    final updated = [...messages, message];
    await _persist(updated);
    messages.assignAll(updated);
  }

  Future<void> deleteMessage(String messageId) async {
    final updated = messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(deletedAt: DateTime.now());
      }
      return m;
    }).toList();
    await _persist(updated);
    messages.assignAll(updated);
  }

  Future<void> _persist(List<ChatMessage> messagesList) async {
    await _storage.set('chat_messages_$_groupId', {'items': messagesList.map((e) => e.toJson()).toList()});
  }
}
