import 'package:get/get.dart';
import 'package:poker_night/features/history/models/game_result_model.dart';
import 'package:poker_night/features/history/models/player_statistics_model.dart';
import 'package:poker_night/services/storage_service.dart';

class HistoryController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final String groupId;
  
  final RxList<GameResult> games = <GameResult>[].obs;
  final RxBool isLoading = false.obs;

  HistoryController({required this.groupId});

  @override
  void onInit() {
    super.onInit();
    loadHistory();
  }

  Future<void> loadHistory() async {
    isLoading.value = true;
    try {
      final data = await _storage.getJson('game_history_$groupId');
      final list = (data?['items'] as List<dynamic>?)
          ?.map((e) => GameResult.fromJson(e as Map<String, dynamic>))
          .toList() ?? [];
      games.assignAll(list..sort((a, b) => b.completedAt.compareTo(a.completedAt)));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addGameResult(GameResult result) async {
    final updated = [result, ...games];
    await _persist(updated);
    games.assignAll(updated);
  }

  Future<void> deleteGameResult(String gameId) async {
    final updated = games.where((r) => r.gameId != gameId).toList();
    await _persist(updated);
    games.assignAll(updated);
  }

  PlayerStatistics? getStatisticsForPlayer(String playerId) {
    if (games.isEmpty) return null;
    final results = <FinalPosition>[];
    for (final g in games) {
      for (final p in g.positions) {
        if (p.playerId == playerId) {
          results.add(p);
        }
      }
    }

    if (results.isEmpty) return null;

    final gamesPlayed = results.length;
    final wins = results.where((r) => r.position == 1).length;
    final podiumFinishes = results.where((r) => r.position <= 3).length;
    final avgFinish = gamesPlayed > 0 ? results.fold<double>(0, (sum, r) => sum + r.position) / gamesPlayed : 0.0;

    final firstResult = results.first;
    return PlayerStatistics(
      playerId: playerId,
      playerName: firstResult.playerName,
      gamesPlayed: gamesPlayed,
      wins: wins,
      podiumFinishes: podiumFinishes,
      averageFinish: avgFinish,
      knockouts: 0,
    );
  }

  List<PlayerStatistics> getLeaderboard() {
    if (games.isEmpty) return [];
    final stats = <String, _StatAccum>{};
    for (final game in games) {
      for (final pos in game.positions) {
        stats.putIfAbsent(pos.playerId, () => _StatAccum(name: pos.playerName));
        final s = stats[pos.playerId]!;
        s.gamesPlayed++;
        if (pos.position == 1) s.wins++;
        if (pos.position <= 3) s.podiumFinishes++;
        s.totalPositions += pos.position;
      }
    }
    return stats.entries.map((e) => PlayerStatistics(
      playerId: e.key,
      playerName: e.value.name,
      gamesPlayed: e.value.gamesPlayed,
      wins: e.value.wins,
      podiumFinishes: e.value.podiumFinishes,
      averageFinish: e.value.gamesPlayed > 0 ? e.value.totalPositions / e.value.gamesPlayed : 0,
      knockouts: 0,
    )).toList()
      ..sort((a, b) => b.wins.compareTo(a.wins));
  }

  Future<void> _persist(List<GameResult> results) async {
    await _storage.set('game_history_$groupId', {'items': results.map((e) => e.toJson()).toList()});
  }
}

class _StatAccum {
  final String name;
  int gamesPlayed = 0;
  int wins = 0;
  int podiumFinishes = 0;
  int totalPositions = 0;
  _StatAccum({required this.name});
}
