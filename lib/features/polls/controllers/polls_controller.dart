import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:poker_night/features/polls/models/poll_model.dart';
import 'package:poker_night/services/storage_service.dart';

class PollsController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final String _groupId;

  final RxList<Poll> polls = <Poll>[].obs;
  final RxBool isLoading = true.obs;

  PollsController(this._groupId);

  @override
  void onInit() {
    super.onInit();
    loadPolls();
  }
  Future<void> loadPolls() async {
    isLoading.value = true;
    final data = await _storage.getJson('polls_$_groupId');
    final list = (data?['items'] as List<dynamic>?)
        ?.map((e) => Poll.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    polls.assignAll(list);
    isLoading.value = false;
  }

  Future<void> createPoll({
    required String question,
    required String createdBy,
    required List<String> options,
  }) async {
    final poll = Poll(
      id: const Uuid().v4(),
      groupId: _groupId,
      question: question,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      closedAt: null,
      isActive: true,
      options: options.asMap().entries.map((e) => PollOption(
        id: const Uuid().v4(),
        pollId: '',
        text: e.value,
        voteCount: 0,
      )).toList(),
    );
    final updated = [poll, ...polls];
    await _persist(updated);
    polls.assignAll(updated);
  }

  Future<void> vote(String pollId, String optionId) async {
    final pIdx = polls.indexWhere((p) => p.id == pollId);
    if (pIdx < 0) return;
    final poll = polls[pIdx];
    final oIdx = poll.options.indexWhere((o) => o.id == optionId);
    if (oIdx < 0) return;
    final options = poll.options.map((o) {
      if (o.id == optionId) return o.copyWith(voteCount: o.voteCount + 1);
      return o;
    }).toList();
    final updated = [...polls]
      ..[pIdx] = poll.copyWith(options: options);
    await _persist(updated);
    polls.assignAll(updated);
  }

  Future<void> closePoll(String pollId) async {
    final pIdx = polls.indexWhere((p) => p.id == pollId);
    if (pIdx < 0) return;
    final updated = [...polls]
      ..[pIdx] = polls[pIdx].copyWith(isActive: false, closedAt: DateTime.now());
    await _persist(updated);
    polls.assignAll(updated);
  }

  Future<void> deletePoll(String pollId) async {
    final updated = polls.where((p) => p.id != pollId).toList();
    await _persist(updated);
    polls.assignAll(updated);
  }

  Future<void> _persist(List<Poll> pollsList) async {
    await _storage.set('polls_$_groupId', {'items': pollsList.map((e) => e.toJson()).toList()});
  }
}
