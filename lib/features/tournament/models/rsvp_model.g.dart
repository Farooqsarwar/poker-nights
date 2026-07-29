// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rsvp_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RsvpGoingImpl _$$RsvpGoingImplFromJson(Map<String, dynamic> json) =>
    _$RsvpGoingImpl($type: json['runtimeType'] as String?);

Map<String, dynamic> _$$RsvpGoingImplToJson(_$RsvpGoingImpl instance) =>
    <String, dynamic>{'runtimeType': instance.$type};

_$RsvpNotGoingImpl _$$RsvpNotGoingImplFromJson(Map<String, dynamic> json) =>
    _$RsvpNotGoingImpl($type: json['runtimeType'] as String?);

Map<String, dynamic> _$$RsvpNotGoingImplToJson(_$RsvpNotGoingImpl instance) =>
    <String, dynamic>{'runtimeType': instance.$type};

_$RsvpMaybeImpl _$$RsvpMaybeImplFromJson(Map<String, dynamic> json) =>
    _$RsvpMaybeImpl($type: json['runtimeType'] as String?);

Map<String, dynamic> _$$RsvpMaybeImplToJson(_$RsvpMaybeImpl instance) =>
    <String, dynamic>{'runtimeType': instance.$type};

_$RsvpNoResponseImpl _$$RsvpNoResponseImplFromJson(Map<String, dynamic> json) =>
    _$RsvpNoResponseImpl($type: json['runtimeType'] as String?);

Map<String, dynamic> _$$RsvpNoResponseImplToJson(
  _$RsvpNoResponseImpl instance,
) => <String, dynamic>{'runtimeType': instance.$type};

_$RsvpEntryImpl _$$RsvpEntryImplFromJson(Map<String, dynamic> json) =>
    _$RsvpEntryImpl(
      id: json['id'] as String,
      gameId: json['gameId'] as String,
      participantId: json['participantId'] as String,
      participantName: json['participantName'] as String,
      status: RsvpStatus.fromJson(json['status'] as Map<String, dynamic>),
      guestCount: (json['guestCount'] as num?)?.toInt() ?? 0,
      respondedAt: json['respondedAt'] == null
          ? null
          : DateTime.parse(json['respondedAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$RsvpEntryImplToJson(_$RsvpEntryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'gameId': instance.gameId,
      'participantId': instance.participantId,
      'participantName': instance.participantName,
      'status': instance.status,
      'guestCount': instance.guestCount,
      'respondedAt': instance.respondedAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
