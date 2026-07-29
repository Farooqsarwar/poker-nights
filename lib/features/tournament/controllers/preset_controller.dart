import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:poker_night/features/tournament/models/tournament_model.dart';
import 'package:poker_night/services/storage_service.dart';

class TournamentPreset {
  final String id;
  final String groupId;
  final String name;
  final TournamentSettings settings;
  final DateTime createdAt;

  TournamentPreset({
    required this.id,
    required this.groupId,
    required this.name,
    required this.settings,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'groupId': groupId,
    'name': name,
    'settings': settings.toJson(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory TournamentPreset.fromJson(Map<String, dynamic> json) => TournamentPreset(
    id: json['id'] as String,
    groupId: json['groupId'] as String,
    name: json['name'] as String,
    settings: TournamentSettings.fromJson(json['settings'] as Map<String, dynamic>),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class PresetController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final String groupId;

  final presets = <TournamentPreset>[].obs;
  final isLoading = true.obs;

  PresetController(this.groupId);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    final data = await _storage.getJson('presets_$groupId');
    final list = (data?['items'] as List<dynamic>?)
        ?.map((e) => TournamentPreset.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    presets.value = list;
    isLoading.value = false;
  }

  Future<void> save(String name, TournamentSettings settings) async {
    final preset = TournamentPreset(
      id: const Uuid().v4(),
      groupId: groupId,
      name: name,
      settings: settings,
      createdAt: DateTime.now(),
    );
    presets.add(preset);
    await _persist();
  }

  Future<void> deletePreset(String presetId) async {
    presets.removeWhere((p) => p.id == presetId);
    await _persist();
  }

  TournamentPreset? matchPreset(List<Map<String, dynamic>> pollResults) {
    if (presets.isEmpty || pollResults.isEmpty) return null;
    int bestScore = 0;
    TournamentPreset? best;
    for (final p in presets) {
      int score = 0;
      for (final r in pollResults) {
        final key = r['key'] as String? ?? '';
        final val = r['value'];
        if (key == 'buyIn' && val is num && val == p.settings.buyIn) score += 2;
        if (key == 'players' && val is int && val == p.settings.expectedPlayers) score += 2;
        if (key == 'duration' && val is num && val == p.settings.targetDurationHours) score += 1;
      }
      if (score > bestScore) {
        bestScore = score;
        best = p;
      }
    }
    return best;
  }

  Future<void> _persist() async {
    await _storage.set('presets_$groupId', {'items': presets.map((e) => e.toJson()).toList()});
  }
}
