import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:poker_night/features/tournament/models/check_in_model.dart';
import 'package:poker_night/services/storage_service.dart';

class CheckInController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final String gameId;

  final checkIns = <CheckInRecord>[].obs;
  final isLoading = true.obs;

  CheckInController(this.gameId);

  @override
  void onInit() {
    super.onInit();
    loadCheckIns();
  }

  Future<void> loadCheckIns() async {
    isLoading.value = true;
    final data = await _storage.getJson('checkins_$gameId');
    final list = (data?['items'] as List<dynamic>?)
        ?.map((e) => CheckInRecord.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    checkIns.value = list;
    isLoading.value = false;
  }

  Future<void> checkInPlayer(String participantId, String participantName, {String? note}) async {
    final idx = checkIns.indexWhere((c) => c.participantId == participantId);
    final record = CheckInRecord(
      id: const Uuid().v4(),
      gameId: gameId,
      participantId: participantId,
      participantName: participantName,
      status: const CheckInStatus.checkedIn(),
      checkedInAt: DateTime.now(),
      note: note,
    );
    if (idx >= 0) {
      checkIns[idx] = record;
    } else {
      checkIns.add(record);
    }
    await _persist();
  }

  Future<void> markNoShow(String participantId) async {
    final idx = checkIns.indexWhere((c) => c.participantId == participantId);
    if (idx < 0) return;
    checkIns[idx] = checkIns[idx].copyWith(status: const CheckInStatus.noShow());
    await _persist();
  }

  Future<void> initFromParticipants(List<Map<String, dynamic>> participants) async {
    if (checkIns.isNotEmpty) return;
    final records = participants.map((p) => CheckInRecord(
      id: const Uuid().v4(),
      gameId: gameId,
      participantId: p['id'] as String,
      participantName: p['name'] as String,
      status: const CheckInStatus.pending(),
    )).toList();
    checkIns.value = records;
    await _persist();
  }

  List<CheckInRecord> checkedIn() =>
      checkIns.where((c) => c.status is CheckInCheckedIn).toList();

  List<CheckInRecord> notCheckedIn() =>
      checkIns.where((c) => c.status is CheckInPending).toList();

  int checkedInCount() => checkedIn().length;

  Future<void> _persist() async {
    await _storage.set('checkins_$gameId', {'items': checkIns.map((e) => e.toJson()).toList()});
  }
}
