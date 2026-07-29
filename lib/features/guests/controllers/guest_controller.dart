import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:poker_night/features/guests/models/guest_model.dart';
import 'package:poker_night/services/storage_service.dart';

class GuestController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final String _gameId;

  final RxList<GuestModel> guests = <GuestModel>[].obs;
  final RxBool isLoading = true.obs;

  GuestController(this._gameId);

  @override
  void onInit() {
    super.onInit();
    loadGuests();
  }
  Future<void> loadGuests() async {
    isLoading.value = true;
    final data = await _storage.getJson('guests_$_gameId');
    final list = (data?['items'] as List<dynamic>?)
        ?.map((e) => GuestModel.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    guests.assignAll(list);
    isLoading.value = false;
  }

  Future<void> addGuest({
    required String name,
    required String inviterParticipantId,
    required int slotNo,
  }) async {
    final guest = GuestModel(
      id: const Uuid().v4(),
      gameId: _gameId,
      inviterParticipantId: inviterParticipantId,
      slotNo: slotNo,
      name: name,
      confirmationState: 'pending',
    );
    final updated = [...guests, guest];
    await _persist(updated);
    guests.assignAll(updated);
  }

  Future<void> approveGuest(String guestId) async {
    final idx = guests.indexWhere((g) => g.id == guestId);
    if (idx < 0) return;
    final updated = [...guests]
      ..[idx] = guests[idx].copyWith(confirmationState: 'approved');
    await _persist(updated);
    guests.assignAll(updated);
  }

  Future<void> rejectGuest(String guestId) async {
    final updated = guests.where((g) => g.id != guestId).toList();
    await _persist(updated);
    guests.assignAll(updated);
  }

  Future<void> assignSeat(String guestId, int tableNo, int seatNo) async {
    final idx = guests.indexWhere((g) => g.id == guestId);
    if (idx < 0) return;
    final updated = [...guests]
      ..[idx] = guests[idx].copyWith(tableNo: tableNo, seatNo: seatNo);
    await _persist(updated);
    guests.assignAll(updated);
  }

  List<GuestModel> pendingGuests() =>
      guests.where((g) => g.confirmationState == 'pending').toList();

  List<GuestModel> approvedGuests() =>
      guests.where((g) => g.confirmationState == 'approved').toList();

  int get guestCount => guests.length;

  Future<void> _persist(List<GuestModel> guestsList) async {
    await _storage.set('guests_$_gameId', {'items': guestsList.map((e) => e.toJson()).toList()});
  }
}
