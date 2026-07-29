import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:poker_night/features/tournament/models/chip_set_model.dart';
import 'package:poker_night/services/storage_service.dart';

class ChipInventoryController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final String groupId;

  final chipSets = <ChipSet>[].obs;
  final isLoading = true.obs;

  ChipInventoryController(this.groupId);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    final data = await _storage.getJson('chip_inventory_$groupId');
    final list = (data?['items'] as List<dynamic>?)
        ?.map((e) => ChipSet.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    chipSets.value = list;
    isLoading.value = false;
  }

  Future<void> save(ChipSet chipSet) async {
    final idx = chipSets.indexWhere((c) => c.id == chipSet.id);
    if (idx >= 0) {
      chipSets[idx] = chipSet;
    } else {
      final saved = chipSet.copyWith(id: const Uuid().v4());
      chipSets.add(saved);
    }
    await _persist();
  }

  Future<void> deleteSet(String chipSetId) async {
    chipSets.removeWhere((c) => c.id == chipSetId);
    await _persist();
  }

  String stackComposition(int stack, ChipSet chipSet) {
    final chips = List<ChipDenomination>.from(chipSet.chips)..sort((a, b) => b.value.compareTo(a.value));
    final parts = <String>[];
    int remaining = stack;
    for (final chip in chips) {
      if (chip.value <= 0) continue;
      final needed = remaining ~/ chip.value;
      if (needed > 0) {
        parts.add('${needed}x \$${chip.value}');
        remaining -= needed * chip.value;
      }
    }
    if (remaining > 0) parts.add('$remaining leftover');
    return parts.isEmpty ? 'No chips' : parts.join(', ');
  }

  Future<void> _persist() async {
    await _storage.set('chip_inventory_$groupId', {'items': chipSets.map((e) => e.toJson()).toList()});
  }
}
