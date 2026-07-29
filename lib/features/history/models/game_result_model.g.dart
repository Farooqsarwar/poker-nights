// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_result_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GameResultImpl _$$GameResultImplFromJson(Map<String, dynamic> json) =>
    _$GameResultImpl(
      id: json['id'] as String,
      gameId: json['gameId'] as String,
      gameName: json['gameName'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
      playerCount: (json['playerCount'] as num).toInt(),
      positions: (json['positions'] as List<dynamic>)
          .map((e) => FinalPosition.fromJson(e as Map<String, dynamic>))
          .toList(),
      knockouts: Map<String, int>.from(json['knockouts'] as Map),
      totalPrizePool: (json['totalPrizePool'] as num).toInt(),
      organizerAmount: (json['organizerAmount'] as num?)?.toInt() ?? 0,
      payouts: (json['payouts'] as List<dynamic>)
          .map((e) => PayoutEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$GameResultImplToJson(_$GameResultImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'gameId': instance.gameId,
      'gameName': instance.gameName,
      'completedAt': instance.completedAt.toIso8601String(),
      'playerCount': instance.playerCount,
      'positions': instance.positions,
      'knockouts': instance.knockouts,
      'totalPrizePool': instance.totalPrizePool,
      'organizerAmount': instance.organizerAmount,
      'payouts': instance.payouts,
    };

_$FinalPositionImpl _$$FinalPositionImplFromJson(Map<String, dynamic> json) =>
    _$FinalPositionImpl(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      position: (json['position'] as num).toInt(),
    );

Map<String, dynamic> _$$FinalPositionImplToJson(_$FinalPositionImpl instance) =>
    <String, dynamic>{
      'playerId': instance.playerId,
      'playerName': instance.playerName,
      'position': instance.position,
    };

_$PayoutEntryImpl _$$PayoutEntryImplFromJson(Map<String, dynamic> json) =>
    _$PayoutEntryImpl(
      position: (json['position'] as num).toInt(),
      amount: (json['amount'] as num).toInt(),
    );

Map<String, dynamic> _$$PayoutEntryImplToJson(_$PayoutEntryImpl instance) =>
    <String, dynamic>{'position': instance.position, 'amount': instance.amount};
