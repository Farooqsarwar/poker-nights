import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_result_model.freezed.dart';
part 'game_result_model.g.dart';

@freezed
class GameResult with _$GameResult {
  const factory GameResult({
    required String id,
    required String gameId,
    required String gameName,
    required DateTime completedAt,
    required int playerCount,
    required List<FinalPosition> positions,
    required Map<String, int> knockouts,
    required int totalPrizePool,
    @Default(0) int organizerAmount,
    required List<PayoutEntry> payouts,
  }) = _GameResult;

  factory GameResult.fromJson(Map<String, dynamic> json) => _$GameResultFromJson(json);
}

@freezed
class FinalPosition with _$FinalPosition {
  const factory FinalPosition({
    required String playerId,
    required String playerName,
    required int position,
  }) = _FinalPosition;

  factory FinalPosition.fromJson(Map<String, dynamic> json) => _$FinalPositionFromJson(json);
}

@freezed
class PayoutEntry with _$PayoutEntry {
  const factory PayoutEntry({
    required int position,
    required int amount,
  }) = _PayoutEntry;

  factory PayoutEntry.fromJson(Map<String, dynamic> json) => _$PayoutEntryFromJson(json);
}
