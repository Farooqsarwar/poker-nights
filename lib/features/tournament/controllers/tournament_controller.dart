import 'dart:math';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:poker_night/features/tournament/models/tournament_model.dart';
import 'package:poker_night/features/tournament/models/blind_structure_model.dart';
import 'package:poker_night/features/tournament/models/chip_set_model.dart';
import 'package:poker_night/features/tournament/controllers/tournament_engine.dart';
import 'package:poker_night/services/storage_service.dart';
import 'package:poker_night/core/constants/app_constants.dart';
import 'package:poker_night/features/auth/controllers/auth_controller.dart';

class TournamentController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final AuthController _auth = Get.find<AuthController>();
  static const _storageKey = 'poker_tournaments';

  final tournaments = <TournamentModel>[].obs;
  final isLoading = true.obs;
  final error = ''.obs;


  Future<void> loadTournaments(String groupId) async {
    isLoading.value = true;
    error.value = '';
    final doc = await _storage.getJson(_storageKey);
    final data = doc?['data'] as List<dynamic>?;
    final all = data?.map((e) => TournamentModel.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    tournaments.value = all.where((t) => t.groupId == groupId).toList();
    isLoading.value = false;
  }

  Future<TournamentModel> createTournament({
    required String groupId,
    required String name,
    required DateTime scheduledAt,
    String? location,
    required TournamentSettings settings,
  }) async {
    final gameId = const Uuid().v4();
    final code = _generateCode();
    final now = DateTime.now();
    final currentUserId = _auth.currentUser.value?.id ?? '';
    final tournament = TournamentModel(
      id: gameId,
      groupId: groupId,
      adminUserId: currentUserId,
      name: name,
      scheduledAt: scheduledAt,
      location: location,
      status: TournamentStatus.draft.value,
      publicCode: code,
      settings: settings,
      createdAt: now,
    );

    final doc = await _storage.getJson(_storageKey);
    final data = doc?['data'] as List<dynamic>?;
    final all = data?.map((e) => TournamentModel.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    all.add(tournament);
    await _storage.set(_storageKey, {'data': all.map((e) => e.toJson()).toList()}); // fix: wrap in 'data' map like getJson does? actually the old code just did all.map... wait let me check the previous implementation
    tournaments.value = all.where((t) => t.groupId == groupId).toList();
    return tournament;
  }

  Future<void> updateStatus(String gameId, TournamentStatus status) async {
    final doc = await _storage.getJson(_storageKey);
    final data = doc?['data'] as List<dynamic>?;
    final all = data?.map((e) => TournamentModel.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    final idx = all.indexWhere((t) => t.id == gameId);
    if (idx == -1) return;
    all[idx] = all[idx].copyWith(status: status.value);
    await _storage.set(_storageKey, {'data': all.map((e) => e.toJson()).toList()}); // consistency with getJson

    final cIdx = tournaments.indexWhere((t) => t.id == gameId);
    if (cIdx != -1) {
      tournaments[cIdx] = tournaments[cIdx].copyWith(status: status.value);
    }
  }

  Future<void> saveStructure(String gameId, BlindStructure structure) async {
    await _storage.set('tournament_structure_$gameId', structure.toJson());
  }

  Future<BlindStructure?> loadStructure(String gameId) async {
    final data = await _storage.getJson('tournament_structure_$gameId');
    if (data != null) {
      try {
        return BlindStructure.fromJson(data);
      } catch (_) {}
    }
    return null;
  }

  Future<void> publishTournament(String gameId) async {
    await updateStatus(gameId, TournamentStatus.published);
  }

  Future<void> startTournament(String gameId) async {
    await updateStatus(gameId, TournamentStatus.active);
  }

  Future<void> completeTournament(String gameId) async {
    await updateStatus(gameId, TournamentStatus.completed);
  }

  BlindStructure generateStructure(TournamentSettings settings, ChipSet? chipSet) {
    return TournamentEngine.generate(settings, chipSet);
  }

  PrizeDistribution calculatePrizes(double buyIn, int playerCount) {
    return TournamentEngine.calculatePrizes(buyIn, playerCount, 0);
  }

  String _generateCode() {
    final r = Random();
    return List.generate(6, (_) => AppConstants.joinCodeChars[r.nextInt(AppConstants.joinCodeChars.length)]).join();
  }
}
