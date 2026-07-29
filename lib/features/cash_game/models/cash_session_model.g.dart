// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cash_session_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CashSessionImpl _$$CashSessionImplFromJson(Map<String, dynamic> json) =>
    _$CashSessionImpl(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      name: json['name'] as String,
      smallBlind: (json['smallBlind'] as num).toInt(),
      bigBlind: (json['bigBlind'] as num).toInt(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      players: (json['players'] as List<dynamic>)
          .map((e) => CashPlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalIssued: (json['totalIssued'] as num?)?.toInt() ?? 0,
      totalReturned: (json['totalReturned'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$CashSessionImplToJson(_$CashSessionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'groupId': instance.groupId,
      'name': instance.name,
      'smallBlind': instance.smallBlind,
      'bigBlind': instance.bigBlind,
      'status': instance.status,
      'createdAt': instance.createdAt.toIso8601String(),
      'startedAt': instance.startedAt?.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'players': instance.players,
      'totalIssued': instance.totalIssued,
      'totalReturned': instance.totalReturned,
    };

_$CashPlayerImpl _$$CashPlayerImplFromJson(Map<String, dynamic> json) =>
    _$CashPlayerImpl(
      participantId: json['participantId'] as String,
      name: json['name'] as String,
      buyIn: (json['buyIn'] as num).toInt(),
      topUps: (json['topUps'] as num).toInt(),
      cashOut: (json['cashOut'] as num).toInt(),
      status: json['status'] as String? ?? 'active',
    );

Map<String, dynamic> _$$CashPlayerImplToJson(_$CashPlayerImpl instance) =>
    <String, dynamic>{
      'participantId': instance.participantId,
      'name': instance.name,
      'buyIn': instance.buyIn,
      'topUps': instance.topUps,
      'cashOut': instance.cashOut,
      'status': instance.status,
    };
