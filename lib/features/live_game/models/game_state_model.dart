import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_state_model.freezed.dart';
part 'game_state_model.g.dart';

@freezed
class GameState with _$GameState {
  const factory GameState({
    required String gameId,
    required int currentLevel,
    required String status,
    required DateTime? startedAt,
    required DateTime? pausedAt,
    required int pausedRemainingSeconds,
    required String? resumedAt,
    required BlindLevelData currentBlinds,
    required BlindLevelData nextBlinds,
    required int playersRemaining,
    required int playersTotal,
    required int averageStack,
    required int totalChips,
    required int prizePool,
    required bool anteActive,
    required List<PlayerState> players,
    required List<TableState> tables,
    required int revision,
    required DateTime lastUpdated,
  }) = _GameState;

  factory GameState.fromJson(Map<String, dynamic> json) => _$GameStateFromJson(json);

  static GameState initial(String gameId) => GameState(
    gameId: gameId,
    currentLevel: 1,
    status: 'pending',
    startedAt: null,
    pausedAt: null,
    pausedRemainingSeconds: 0,
    resumedAt: null,
    currentBlinds: BlindLevelData(smallBlind: 0, bigBlind: 0, ante: 0),
    nextBlinds: BlindLevelData(smallBlind: 0, bigBlind: 0, ante: 0),
    playersRemaining: 0,
    playersTotal: 0,
    averageStack: 0,
    totalChips: 0,
    prizePool: 0,
    anteActive: false,
    players: [],
    tables: [],
    revision: 0,
    lastUpdated: DateTime.now(),
  );
}

@freezed
class BlindLevelData with _$BlindLevelData {
  const factory BlindLevelData({
    required int smallBlind,
    required int bigBlind,
    required int ante,
  }) = _BlindLevelData;

  factory BlindLevelData.fromJson(Map<String, dynamic> json) => _$BlindLevelDataFromJson(json);
}

@freezed
class PlayerState with _$PlayerState {
  const factory PlayerState({
    required String id,
    required String name,
    required int tableNo,
    required int seatNo,
    required int stack,
    required String status,
    @Default(false) bool isGuest,
    int? finishPosition,
  }) = _PlayerState;

  factory PlayerState.fromJson(Map<String, dynamic> json) => _$PlayerStateFromJson(json);
}

@freezed
class TableState with _$TableState {
  const factory TableState({
    required int tableNo,
    required List<SeatState> seats,
    required int playerCount,
  }) = _TableState;

  factory TableState.fromJson(Map<String, dynamic> json) => _$TableStateFromJson(json);
}

@freezed
class SeatState with _$SeatState {
  const factory SeatState({
    required int seatNo,
    String? playerId,
    String? playerName,
    @Default(false) bool isEmpty,
  }) = _SeatState;

  factory SeatState.fromJson(Map<String, dynamic> json) => _$SeatStateFromJson(json);
}
