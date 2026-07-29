// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_statistics_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PlayerStatisticsImpl _$$PlayerStatisticsImplFromJson(
  Map<String, dynamic> json,
) => _$PlayerStatisticsImpl(
  playerId: json['playerId'] as String,
  playerName: json['playerName'] as String,
  gamesPlayed: (json['gamesPlayed'] as num).toInt(),
  wins: (json['wins'] as num).toInt(),
  podiumFinishes: (json['podiumFinishes'] as num).toInt(),
  averageFinish: (json['averageFinish'] as num).toDouble(),
  knockouts: (json['knockouts'] as num).toInt(),
);

Map<String, dynamic> _$$PlayerStatisticsImplToJson(
  _$PlayerStatisticsImpl instance,
) => <String, dynamic>{
  'playerId': instance.playerId,
  'playerName': instance.playerName,
  'gamesPlayed': instance.gamesPlayed,
  'wins': instance.wins,
  'podiumFinishes': instance.podiumFinishes,
  'averageFinish': instance.averageFinish,
  'knockouts': instance.knockouts,
};
