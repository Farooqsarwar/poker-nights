import 'package:get/get.dart';
import 'package:poker_night/features/tournament/models/settlement_model.dart';
import 'package:poker_night/services/storage_service.dart';

class SettlementController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final String gameId;

  final settlement = Rx<TournamentSettlement?>(null);
  final isLoading = true.obs;

  SettlementController(this.gameId);

  @override
  void onInit() {
    super.onInit();
    loadSettlement();
  }

  Future<void> loadSettlement() async {
    isLoading.value = true;
    final data = await _storage.getJson('settlement_$gameId');
    if (data != null) {
      try {
        settlement.value = TournamentSettlement.fromJson(data);
      } catch (_) {
        settlement.value = null;
      }
    }
    isLoading.value = false;
  }

  Future<void> initializeSettlement({
    required List<FinalPosition> positions,
    required int prizePool,
    required int organizerAmount,
    required List<PayoutEntry> payouts,
  }) async {
    final s = TournamentSettlement(
      gameId: gameId,
      finalPositions: positions,
      prizePool: prizePool,
      organizerAmount: organizerAmount,
      payouts: payouts,
      status: const SettlementStatus.pending(),
    );
    settlement.value = s;
    await _persist();
  }

  Future<void> confirmSettlement(String settledBy) async {
    final current = settlement.value;
    if (current == null) return;
    settlement.value = current.copyWith(
      status: const SettlementStatus.confirmed(),
      settledAt: DateTime.now(),
      settledBy: settledBy,
    );
    await _persist();
  }

  Future<void> disputeSettlement() async {
    final current = settlement.value;
    if (current == null) return;
    settlement.value = current.copyWith(status: const SettlementStatus.disputed());
    await _persist();
  }

  List<FinalPosition> sortedPositions() {
    final current = settlement.value;
    if (current == null) return [];
    return List.from(current.finalPositions)..sort((a, b) => a.position.compareTo(b.position));
  }

  Future<void> recordChop(int position, int chopAmount) async {
    final current = settlement.value;
    if (current == null) return;
    final positions = current.finalPositions.map((p) {
      if (p.position == position) {
        return p.copyWith(isChop: true, chopAmount: chopAmount);
      }
      return p;
    }).toList();
    settlement.value = current.copyWith(finalPositions: positions);
    await _persist();
  }

  Future<void> _persist() async {
    if (settlement.value != null) {
      await _storage.set('settlement_$gameId', settlement.value!.toJson());
    }
  }
}
