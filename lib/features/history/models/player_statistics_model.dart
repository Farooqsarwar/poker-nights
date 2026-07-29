import 'package:freezed_annotation/freezed_annotation.dart';

part 'player_statistics_model.freezed.dart';
part 'player_statistics_model.g.dart';

@freezed
class PlayerStatistics with _$PlayerStatistics {
  const factory PlayerStatistics({
    required String playerId,
    required String playerName,
    required int gamesPlayed,
    required int wins,
    required int podiumFinishes,
    required double averageFinish,
    required int knockouts,
  }) = _PlayerStatistics;

  factory PlayerStatistics.fromJson(Map<String, dynamic> json) => _$PlayerStatisticsFromJson(json);
}
