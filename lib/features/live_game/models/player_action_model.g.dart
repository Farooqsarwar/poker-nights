// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_action_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GameActionImpl _$$GameActionImplFromJson(Map<String, dynamic> json) =>
    _$GameActionImpl(
      id: json['id'] as String,
      gameId: json['gameId'] as String,
      sequence: (json['sequence'] as num).toInt(),
      actorUserId: json['actorUserId'] as String,
      type: json['type'] as String,
      payload: json['payload'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      reversedByActionId: json['reversedByActionId'] as String?,
    );

Map<String, dynamic> _$$GameActionImplToJson(_$GameActionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'gameId': instance.gameId,
      'sequence': instance.sequence,
      'actorUserId': instance.actorUserId,
      'type': instance.type,
      'payload': instance.payload,
      'createdAt': instance.createdAt.toIso8601String(),
      'reversedByActionId': instance.reversedByActionId,
    };
