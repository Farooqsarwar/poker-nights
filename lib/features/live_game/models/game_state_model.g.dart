// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_state_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GameStateImpl _$$GameStateImplFromJson(Map<String, dynamic> json) =>
    _$GameStateImpl(
      gameId: json['gameId'] as String,
      currentLevel: (json['currentLevel'] as num).toInt(),
      status: json['status'] as String,
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      pausedAt: json['pausedAt'] == null
          ? null
          : DateTime.parse(json['pausedAt'] as String),
      pausedRemainingSeconds: (json['pausedRemainingSeconds'] as num).toInt(),
      resumedAt: json['resumedAt'] as String?,
      currentBlinds: BlindLevelData.fromJson(
        json['currentBlinds'] as Map<String, dynamic>,
      ),
      nextBlinds: BlindLevelData.fromJson(
        json['nextBlinds'] as Map<String, dynamic>,
      ),
      playersRemaining: (json['playersRemaining'] as num).toInt(),
      playersTotal: (json['playersTotal'] as num).toInt(),
      averageStack: (json['averageStack'] as num).toInt(),
      totalChips: (json['totalChips'] as num).toInt(),
      prizePool: (json['prizePool'] as num).toInt(),
      anteActive: json['anteActive'] as bool,
      players: (json['players'] as List<dynamic>)
          .map((e) => PlayerState.fromJson(e as Map<String, dynamic>))
          .toList(),
      tables: (json['tables'] as List<dynamic>)
          .map((e) => TableState.fromJson(e as Map<String, dynamic>))
          .toList(),
      revision: (json['revision'] as num).toInt(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );

Map<String, dynamic> _$$GameStateImplToJson(_$GameStateImpl instance) =>
    <String, dynamic>{
      'gameId': instance.gameId,
      'currentLevel': instance.currentLevel,
      'status': instance.status,
      'startedAt': instance.startedAt?.toIso8601String(),
      'pausedAt': instance.pausedAt?.toIso8601String(),
      'pausedRemainingSeconds': instance.pausedRemainingSeconds,
      'resumedAt': instance.resumedAt,
      'currentBlinds': instance.currentBlinds,
      'nextBlinds': instance.nextBlinds,
      'playersRemaining': instance.playersRemaining,
      'playersTotal': instance.playersTotal,
      'averageStack': instance.averageStack,
      'totalChips': instance.totalChips,
      'prizePool': instance.prizePool,
      'anteActive': instance.anteActive,
      'players': instance.players,
      'tables': instance.tables,
      'revision': instance.revision,
      'lastUpdated': instance.lastUpdated.toIso8601String(),
    };

_$BlindLevelDataImpl _$$BlindLevelDataImplFromJson(Map<String, dynamic> json) =>
    _$BlindLevelDataImpl(
      smallBlind: (json['smallBlind'] as num).toInt(),
      bigBlind: (json['bigBlind'] as num).toInt(),
      ante: (json['ante'] as num).toInt(),
    );

Map<String, dynamic> _$$BlindLevelDataImplToJson(
  _$BlindLevelDataImpl instance,
) => <String, dynamic>{
  'smallBlind': instance.smallBlind,
  'bigBlind': instance.bigBlind,
  'ante': instance.ante,
};

_$PlayerStateImpl _$$PlayerStateImplFromJson(Map<String, dynamic> json) =>
    _$PlayerStateImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      tableNo: (json['tableNo'] as num).toInt(),
      seatNo: (json['seatNo'] as num).toInt(),
      stack: (json['stack'] as num).toInt(),
      status: json['status'] as String,
      isGuest: json['isGuest'] as bool? ?? false,
      finishPosition: (json['finishPosition'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$PlayerStateImplToJson(_$PlayerStateImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'tableNo': instance.tableNo,
      'seatNo': instance.seatNo,
      'stack': instance.stack,
      'status': instance.status,
      'isGuest': instance.isGuest,
      'finishPosition': instance.finishPosition,
    };

_$TableStateImpl _$$TableStateImplFromJson(Map<String, dynamic> json) =>
    _$TableStateImpl(
      tableNo: (json['tableNo'] as num).toInt(),
      seats: (json['seats'] as List<dynamic>)
          .map((e) => SeatState.fromJson(e as Map<String, dynamic>))
          .toList(),
      playerCount: (json['playerCount'] as num).toInt(),
    );

Map<String, dynamic> _$$TableStateImplToJson(_$TableStateImpl instance) =>
    <String, dynamic>{
      'tableNo': instance.tableNo,
      'seats': instance.seats,
      'playerCount': instance.playerCount,
    };

_$SeatStateImpl _$$SeatStateImplFromJson(Map<String, dynamic> json) =>
    _$SeatStateImpl(
      seatNo: (json['seatNo'] as num).toInt(),
      playerId: json['playerId'] as String?,
      playerName: json['playerName'] as String?,
      isEmpty: json['isEmpty'] as bool? ?? false,
    );

Map<String, dynamic> _$$SeatStateImplToJson(_$SeatStateImpl instance) =>
    <String, dynamic>{
      'seatNo': instance.seatNo,
      'playerId': instance.playerId,
      'playerName': instance.playerName,
      'isEmpty': instance.isEmpty,
    };
